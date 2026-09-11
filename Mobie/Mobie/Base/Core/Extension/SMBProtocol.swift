import Foundation
#if canImport(AppGroupKit)
import AppGroupKit
#endif

enum SMBFailure: Error { case message(String) }

enum SMBPath {
    static func relative(_ path: String) throws -> String {
        let parts = path.replacingOccurrences(of: "\\", with: "/").split(separator: "/")
        guard !parts.contains(".."), !path.contains("\0") else { throw SMBFailure.message("Invalid SMB file.") }
        return parts.filter { $0 != "." }.joined(separator: "/")
    }
}

enum SMBAddress {
    static func parse(server: String, port: String, share: String) throws -> SMBDriveUserModel {
        var address = server.replacingOccurrences(of: "\\", with: "/")
        if address.hasPrefix("//") { address = "smb:" + address }
        if !address.contains("://") { address = "smb://" + address }
        guard let parts = URLComponents(string: address), parts.scheme?.lowercased() == "smb",
              let host = parts.host, !host.isEmpty, !host.contains(where: { $0.isWhitespace }),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              let number = parts.port ?? Int(port.isEmpty ? "445" : port), (1...65535).contains(number) else {
            throw SMBFailure.message("Invalid SMB server address.")
        }
        let path = parts.path.split(separator: "/").map(String.init)
        guard path.count <= 1 else { throw SMBFailure.message("Enter only the SMB shared-folder name, not a subfolder path.") }
        let folder = share.isEmpty ? (path.first ?? "") : share
        guard !folder.isEmpty, folder != ".", folder != "..", !folder.contains("/"), !folder.contains("\\"), !folder.contains("\0"),
              path.first == nil || path.first == folder else {
            throw SMBFailure.message("Enter only the SMB shared-folder name, not a subfolder path.")
        }
        var user = SMBDriveUserModel()
        user.host = host
        user.port = number
        user.share = folder
        return user
    }
}

enum SMBHTTPRange {
    /// End-exclusive range. Reject multiple/malformed ranges instead of silently downloading the full file.
    static func parse(_ value: String?, size: Int64) -> Range<Int64>? {
        guard size > 0 else { return nil }
        guard let value else { return 0..<size }
        guard value.hasPrefix("bytes=") else { return nil }
        let parts = value.dropFirst(6).split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        func number(_ text: Substring) -> Int64? {
            guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return Int64(text)
        }
        if parts[0].isEmpty {
            guard let suffix = number(parts[1]), suffix > 0 else { return nil }
            return max(0, size - min(suffix, size))..<size
        }
        guard let start = number(parts[0]), start < size else { return nil }
        if parts[1].isEmpty { return start..<size }
        guard let end = number(parts[1]), end >= start else { return nil }
        return start..<(min(end, size - 1) + 1)
    }
}
