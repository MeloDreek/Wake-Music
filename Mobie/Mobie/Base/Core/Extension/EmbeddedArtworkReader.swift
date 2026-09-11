import Foundation

extension Notification.Name {
    static let playbackArtworkCached = Notification.Name("Wakemusic.PlaybackArtworkCached")
}

/// Read ID3 artwork independently of its MIME field. Never repairs or writes the source file.
/// The same bounded reader works with local caches and HTTP Range responses.
enum EmbeddedArtworkReader {
    static let maximumTagSize = 8 * 1024 * 1024
    enum ReadError: Error { case invalidRange, tooLarge, unsupportedResponse }
    typealias Read = (UInt64, Int) async throws -> Data

    static func imageData(url: URL, headers: [String: String] = [:], configuration: URLSessionConfiguration = .ephemeral) async throws -> Data? {
        try await imageData { offset, count in
            try Task.checkCancellation()
            guard count > 0, count <= maximumTagSize else { throw ReadError.tooLarge }
            guard offset <= UInt64.max - UInt64(count) else { throw ReadError.invalidRange }
            if url.isFileURL {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                try handle.seek(toOffset: offset)
                return try handle.read(upToCount: count) ?? Data()
            }
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                throw ReadError.unsupportedResponse
            }
            let transfer = ArtworkRangeRequest(url: url, headers: headers, offset: offset, count: count, configuration: configuration)
            return try await withTaskCancellationHandler(operation: {
                try await transfer.read()
            }, onCancel: { transfer.cancel() })
        }
    }

    static func imageData(read: Read) async throws -> Data? {
        let header = [UInt8](try await read(0, 12))
        guard header.count == 12 else { return nil }
        if String(bytes: header[0..<3], encoding: .ascii) == "ID3" {
            return try await readTag(at: 0, limit: nil, read: read)
        }
        // WAV/AIFF ID3 chunks can follow the entire audio payload: seek past data, don't download it.
        let kind = String(bytes: header[0..<4], encoding: .ascii)
        let wave = kind == "RIFF" && String(bytes: header[8..<12], encoding: .ascii) == "WAVE"
        let aiff = kind == "FORM" && ["AIFF", "AIFC"].contains(String(bytes: header[8..<12], encoding: .ascii) ?? "")
        if wave || aiff {
            let end = integer(header[4..<8], littleEndian: wave) + 8
            var offset: UInt64 = 12
            for _ in 0..<64 {
                guard offset + 8 <= end else { return nil }
                let chunk = [UInt8](try await read(offset, 8))
                guard chunk.count == 8 else { return nil }
                let size = integer(chunk[4..<8], littleEndian: wave)
                guard size <= end - offset - 8 else { return nil }
                if String(bytes: chunk[0..<4], encoding: .ascii)?.uppercased() == "ID3 " {
                    return try await readTag(at: offset + 8, limit: size, read: read)
                }
                offset += 8 + size + (size & 1)
            }
        } else if kind == "DSD " {
            let dsd = [UInt8](try await read(0, 28))
            guard dsd.count == 28 else { return nil }
            let offset = integer(dsd[20..<28], littleEndian: true)
            let size = integer(dsd[12..<20], littleEndian: true)
            if offset >= 28, size >= 10, offset <= size - 10 {
                return try await readTag(at: offset, limit: size - offset, read: read)
            }
        }
        return nil
    }

    private static func readTag(at offset: UInt64, limit: UInt64?, read: Read) async throws -> Data? {
        guard offset <= UInt64.max - UInt64(maximumTagSize), limit == nil || limit! >= 10 else { return nil }
        let header = [UInt8](try await read(offset, 10))
        guard header.count == 10, String(bytes: header[0..<3], encoding: .ascii) == "ID3",
              let size = syncSafe(header[6..<10]), size <= maximumTagSize - 10,
              limit == nil || UInt64(size + 10) <= limit! else { return nil }
        let body = try await read(offset + 10, size)
        guard body.count == size else { return nil }
        return parseID3(Data(header) + body)
    }

    /// Accept a JPEG/PNG payload even when older writers omitted APIC's MIME type.
    static func parseID3(_ data: Data) -> Data? {
        let bytes = [UInt8](data)
        guard bytes.count >= 10, String(bytes: bytes[0..<3], encoding: .ascii) == "ID3",
              (2...4).contains(bytes[3]), let size = syncSafe(bytes[6..<10]),
              size <= maximumTagSize - 10, size <= bytes.count - 10 else { return nil }
        let version = bytes[3], flags = bytes[5]
        if version == 2 && flags & 0x40 != 0 { return nil }
        var body = Array(bytes[10..<10 + size])
        if version < 4 && flags & 0x80 != 0 { body = deunsync(body) }
        var offset = 0
        if version >= 3 && flags & 0x40 != 0 {
            guard body.count >= 4 else { return nil }
            if version == 4 {
                guard let length = syncSafe(body[0..<4]), length >= 6 else { return nil }
                offset = length
            } else { offset = Int(integer(body[0..<4])) + 4 }
        }
        var fallback: Data?
        let headerSize = version == 2 ? 6 : 10
        while offset <= body.count - headerSize {
            let idSize = version == 2 ? 3 : 4
            let id = String(bytes: body[offset..<offset + idSize], encoding: .ascii) ?? ""
            if id.utf8.allSatisfy({ $0 == 0 }) { break }
            let frameSize: Int
            if version == 4 {
                guard let length = syncSafe(body[offset + 4..<offset + 8]) else { break }
                frameSize = length
            } else { frameSize = Int(integer(body[offset + idSize..<offset + headerSize - (version == 2 ? 0 : 2)])) }
            guard frameSize > 0, frameSize <= body.count - offset - headerSize else { break }
            let frameFlags = version == 2 ? UInt8(0) : body[offset + 9]
            var payload = Array(body[offset + headerSize..<offset + headerSize + frameSize])
            offset += headerSize + frameSize
            guard id == "APIC" || id == "PIC" else { continue }
            if version == 3 && frameFlags & 0xE0 != 0 { continue }
            if version == 4 {
                if frameFlags & 0x0C != 0 { continue } // compressed/encrypted
                if frameFlags & 0x02 != 0 || flags & 0x80 != 0 { payload = deunsync(payload) }
                if frameFlags & 0x40 != 0 { guard !payload.isEmpty else { continue }; payload.removeFirst() }
                if frameFlags & 0x01 != 0 { guard payload.count >= 4 else { continue }; payload.removeFirst(4) }
            }
            guard payload.count >= 4, payload[0] <= 3 else { continue }
            var cursor = 1
            if id == "PIC" { cursor += 3 }
            else {
                guard let end = payload[cursor...].firstIndex(of: 0) else { continue }
                if String(bytes: payload[cursor..<end], encoding: .ascii) == "-->" { continue }
                cursor = end + 1
            }
            guard cursor < payload.count else { continue }
            let pictureType = payload[cursor]
            cursor += 1
            let wide = payload[0] == 1 || payload[0] == 2
            var terminated = false
            while cursor < payload.count {
                if wide {
                    guard cursor + 1 < payload.count else { break }
                    if payload[cursor] == 0 && payload[cursor + 1] == 0 { cursor += 2; terminated = true; break }
                    cursor += 2
                } else {
                    if payload[cursor] == 0 { cursor += 1; terminated = true; break }
                    cursor += 1
                }
            }
            guard terminated, cursor < payload.count else { continue }
            let image = Data(payload[cursor...])
            let jpeg = image.starts(with: [0xFF, 0xD8, 0xFF])
            let png = image.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
            guard jpeg || png else { continue }
            if pictureType == 3 { return image }
            if fallback == nil { fallback = image }
        }
        return fallback
    }

    private static func integer(_ bytes: ArraySlice<UInt8>, littleEndian: Bool = false) -> UInt64 {
        (littleEndian ? Array(bytes.reversed()) : Array(bytes)).reduce(0) { ($0 << 8) | UInt64($1) }
    }
    private static func syncSafe(_ bytes: ArraySlice<UInt8>) -> Int? {
        guard bytes.allSatisfy({ $0 < 128 }) else { return nil }
        return bytes.reduce(0) { ($0 << 7) | Int($1) }
    }
    private static func deunsync(_ bytes: [UInt8]) -> [UInt8] {
        var result = [UInt8](), index = 0
        while index < bytes.count {
            let byte = bytes[index]; result.append(byte); index += 1
            if byte == 0xFF, index < bytes.count, bytes[index] == 0 { index += 1 }
        }
        return result
    }
}

/// Reject ignored/mismatched ranges before buffering a response, and cap chunked bodies too.
private final class ArtworkRangeRequest: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    let url: URL, headers: [String: String], offset: UInt64, count: Int
    let configuration: URLSessionConfiguration
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var cancelled = false
    private var continuation: CheckedContinuation<Data, Error>?
    private var body = Data()
    private var failure: Error?
    init(url: URL, headers: [String: String], offset: UInt64, count: Int, configuration: URLSessionConfiguration) {
        self.url = url; self.headers = headers; self.offset = offset; self.count = count
        self.configuration = configuration
    }
    func cancel() { lock.lock(); cancelled = true; task?.cancel(); lock.unlock() }
    func read() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.allHTTPHeaderFields = headers
            request.setValue("bytes=\(offset)-\(offset + UInt64(count) - 1)", forHTTPHeaderField: "Range")
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            let config = configuration.copy() as! URLSessionConfiguration
            config.urlCache = nil; config.httpCookieStorage = nil
            config.timeoutIntervalForResource = 20
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            lock.lock()
            let task = session.dataTask(with: request)
            self.task = task
            task.resume()
            if cancelled { task.cancel() }
            lock.unlock()
        }
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse,
              response.expectedContentLength <= Int64(count),
              (response.statusCode == 206 && response.value(forHTTPHeaderField: "Content-Range")?.hasPrefix("bytes \(offset)-") == true)
                || (response.statusCode == 200 && offset == 0 && response.expectedContentLength >= 0 && response.expectedContentLength <= Int64(count)) else {
            failure = EmbeddedArtworkReader.ReadError.unsupportedResponse
            completionHandler(.cancel); return
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard body.count + data.count <= count else {
            failure = EmbeddedArtworkReader.ReadError.tooLarge; dataTask.cancel(); return
        }
        body.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = failure ?? error { continuation?.resume(throwing: error) }
        else { continuation?.resume(returning: body) }
        continuation = nil
        session.finishTasksAndInvalidate()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard request.url?.scheme == "https" || (url.scheme == "http" && request.url?.scheme == "http") else {
            completionHandler(nil); return
        }
        var redirected = request
        if request.url?.host != url.host { redirected.setValue(nil, forHTTPHeaderField: "Authorization") }
        completionHandler(redirected)
    }
}
