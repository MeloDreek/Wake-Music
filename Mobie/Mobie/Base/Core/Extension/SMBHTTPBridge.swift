import Foundation
import Network
#if canImport(AppGroupKit)
import AppGroupKit
#endif

/// Private loopback transport for AVPlayer/KSPlayer and the existing download queue.
/// Never binds to Wi-Fi, never puts SMB credentials/paths in HTTP URLs, and reads
/// bounded chunks only after the previous chunk has been consumed by the socket.
@MainActor
final class SMBHTTPBridge {
    static let shared = SMBHTTPBridge()
    private var listener: NWListener?
    private var starting: Task<UInt16, Error>?
    private var readyContinuation: CheckedContinuation<UInt16, Error>?
    private struct Entry {
        let file: SMBDriveFileModel
        let size: Int64
        let read: (Range<Int64>) async throws -> Data
        var lastUsed = Date()
    }
    private var entries: [String: Entry] = [:]
    private var connections: [UUID: (NWConnection, String?)] = [:]

    func register(file: SMBDriveFileModel, size: Int64, read: @escaping (Range<Int64>) async throws -> Data) async throws -> URL {
        let port = try await start()
        let active = Set(connections.values.compactMap { $0.1 })
        entries = entries.filter { active.contains($0.key) || Date().timeIntervalSince($0.value.lastUsed) < 60 }
        if entries.count >= 24, let oldest = entries.filter({ !active.contains($0.key) }).min(by: { $0.value.lastUsed < $1.value.lastUsed }) {
            entries.removeValue(forKey: oldest.key)
        }
        guard entries.count < 24 else { throw SMBFailure.message("Too many SMB streams. Please try again later.") }
        let token = UUID().uuidString
        entries[token] = Entry(file: file, size: size, read: read)
        return URL(string: "http://127.0.0.1:\(port)/\(token)/audio")!.appendingPathExtension(file.fileExtension())
    }

    func revoke(account: String) {
        let tokens = Set(entries.filter { $0.value.file.smbUser?.identity == account }.keys)
        entries = entries.filter { !tokens.contains($0.key) }
        for (_, pair) in connections where pair.1.map(tokens.contains) == true { pair.0.cancel() }
    }

    private func start() async throws -> UInt16 {
        if let listener, let port = listener.port, listener.stateIsReady { return port.rawValue }
        if let starting { return try await starting.value }
        let task = Task { @MainActor () throws -> UInt16 in
            let params = NWParameters.tcp
            params.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
            let server = try NWListener(using: params)
            self.listener = server
            server.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            return try await withCheckedThrowingContinuation { continuation in
                self.readyContinuation = continuation
                server.stateUpdateHandler = { [weak self] state in
                    Task { @MainActor in
                        guard let self, self.listener === server else { return }
                        switch state {
                        case .ready:
                            guard let port = server.port else { return }
                            self.readyContinuation?.resume(returning: port.rawValue)
                            self.readyContinuation = nil
                        case .failed(let error):
                            self.readyContinuation?.resume(throwing: error)
                            self.readyContinuation = nil
                            server.cancel()
                        case .cancelled:
                            self.readyContinuation?.resume(throwing: CancellationError())
                            self.readyContinuation = nil
                            self.listener = nil
                        default: break
                        }
                    }
                }
                server.start(queue: .main)
            }
        }
        starting = task
        defer { starting = nil }
        return try await task.value
    }

    private func accept(_ connection: NWConnection) {
        guard connections.count < 12 else { connection.cancel(); return }
        let id = UUID()
        connections[id] = (connection, nil)
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { connection.cancel() }
            if case .cancelled = state {
                Task { @MainActor in
                    // Do not return NWConnection as Task.Success: its Sendable
                    // conformance is iOS 17+, but cleanup must also work on iOS 16.
                    _ = self?.connections.removeValue(forKey: id)
                }
            }
        }
        connection.start(queue: .main)
        receiveHeaders(connection, id: id, buffer: Data())
        // Prevent idle local clients from occupying all slots indefinitely.
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            if let pair = self?.connections[id], pair.1 == nil { connection.cancel() }
        }
    }

    private func receiveHeaders(_ connection: NWConnection, id: UUID, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, done, error in
            Task { @MainActor in
                guard let self else { connection.cancel(); return }
                var buffer = buffer
                buffer.append(data ?? Data())
                guard buffer.count <= 16384, error == nil else { connection.cancel(); return }
                if let range = buffer.range(of: Data("\r\n\r\n".utf8)),
                   let header = String(data: buffer[..<range.lowerBound], encoding: .utf8) {
                    await self.respond(connection, id: id, header: header)
                } else if done { connection.cancel() }
                else { self.receiveHeaders(connection, id: id, buffer: buffer) }
            }
        }
    }

    private func respond(_ connection: NWConnection, id: UUID, header: String) async {
        defer { connection.cancel() }
        let lines = header.components(separatedBy: "\r\n")
        let request = (lines.first ?? "").split(separator: " ")
        guard request.count == 3, request[0] == "GET" || request[0] == "HEAD" else {
            try? await send(Data("HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8), to: connection); return
        }
        let path = request[1].split(separator: "/")
        guard path.count == 2, let entry = entries[String(path[0])] else {
            try? await send(Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8), to: connection); return
        }
        let token = String(path[0])
        connections[id] = (connection, token)
        entries[token]?.lastUsed = Date()
        let ranges = lines.dropFirst().filter { $0.lowercased().hasPrefix("range:") }
        let rawRange = ranges.first.map { String($0.dropFirst(6)).trimmingCharacters(in: .whitespaces) }
        guard ranges.count <= 1, let range = SMBHTTPRange.parse(rawRange, size: entry.size) else {
            try? await send(Data("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Range: bytes */\(entry.size)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8), to: connection); return
        }
        let partial = rawRange != nil
        let contentRange = partial ? "Content-Range: bytes \(range.lowerBound)-\(range.upperBound - 1)/\(entry.size)\r\n" : ""
        let response = "HTTP/1.1 \(partial ? "206 Partial Content" : "200 OK")\r\nAccept-Ranges: bytes\r\nContent-Type: application/octet-stream\r\nContent-Length: \(range.count)\r\n\(contentRange)Cache-Control: no-store\r\nConnection: close\r\n\r\n"
        do {
            try await send(Data(response.utf8), to: connection)
            guard request[0] != "HEAD" else { return }
            var offset = range.lowerBound
            while offset < range.upperBound {
                guard connections[id] != nil, entries[token] != nil else { return }
                let end = min(offset + 256 * 1024, range.upperBound)
                let data = try await entry.read(offset..<end)
                guard !data.isEmpty else { return } // Truncated transfer is not a successful download.
                try await send(data, to: connection)
                offset += Int64(data.count)
                entries[token]?.lastUsed = Date()
            }
        } catch { /* Closing the socket propagates read/network errors to the player. */ }
    }

    private func send(_ data: Data, to connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            })
        }
    }
}

private extension NWListener {
    var stateIsReady: Bool { if case .ready = state { return true }; return false }
}
