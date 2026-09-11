import Foundation
import ImageIO

@main struct ArtworkRegression {
    static var checks = 0
    static func check(_ value: Bool, _ label: String) {
        precondition(value, label); checks += 1
    }
    static func sync(_ size: Int) -> [UInt8] { [21, 14, 7, 0].map { UInt8((size >> $0) & 127) } }
    static func tag(_ payload: [UInt8], version: UInt8 = 4, flags: UInt8 = 0) -> Data {
        let size = payload.count
        let frameSize = version == 4 ? sync(size) : [24,16,8,0].map { UInt8((size >> $0) & 255) }
        let body = Array("APIC".utf8) + frameSize + [0,flags] + payload
        return Data(Array("ID3".utf8) + [version,0,0] + sync(body.count) + body)
    }
    static func main() async throws {
        let jpeg: [UInt8] = [255,216,255,224,1,2,3,255,217]
        let png: [UInt8] = [137,80,78,71,13,10,26,10,1,2]
        let emptyMIME: [UInt8] = [0,0,3,0] + jpeg
        check(EmbeddedArtworkReader.parseID3(tag(emptyMIME)) == Data(jpeg), "empty MIME JPEG")
        check(EmbeddedArtworkReader.parseID3(tag(emptyMIME, version: 3)) == Data(jpeg), "v2.3")
        check(EmbeddedArtworkReader.parseID3(tag([0] + Array("image/png".utf8) + [0,3,0] + png)) == Data(png), "PNG")
        check(EmbeddedArtworkReader.parseID3(tag([1,0,3,0,0] + jpeg)) == Data(jpeg), "UTF16 description")
        check(EmbeddedArtworkReader.parseID3(tag([0] + Array("-->".utf8) + [0,3,0] + jpeg)) == nil, "linked artwork rejected")
        check(EmbeddedArtworkReader.parseID3(tag([0,0,3,0,9,8,7])) == nil, "not an image")
        check(EmbeddedArtworkReader.parseID3(tag(emptyMIME, flags: 8)) == nil, "compressed frame rejected")
        check(EmbeddedArtworkReader.parseID3(tag(emptyMIME, flags: 4)) == nil, "encrypted frame rejected")
        let valid = tag(emptyMIME)
        for length in 0..<valid.count {
            check(EmbeddedArtworkReader.parseID3(valid.prefix(length)) == nil, "truncation \(length)")
        }
        var malformed = valid
        malformed[6] = 255
        check(EmbeddedArtworkReader.parseID3(malformed) == nil, "invalid synchsafe size")
        // Reader seeks over a 1 GB audio body using only chunk headers and bounded tag reads.
        let audioSize: UInt64 = 1_000_000_000
        let tagOffset = 20 + audioSize
        let end = tagOffset + 8 + UInt64(valid.count) + UInt64(valid.count & 1)
        func little(_ n: UInt64) -> Data { Data([0,8,16,24].map { UInt8((n >> $0) & 255) }) }
        var requests = [(UInt64,Int)]()
        let read: EmbeddedArtworkReader.Read = { offset, count in
            requests.append((offset,count))
            if offset == 0 { return Data("RIFF".utf8) + little(end - 8) + Data("WAVE".utf8) }
            if offset == 12 { return Data("data".utf8) + little(audioSize) }
            if offset == tagOffset { return Data("ID3 ".utf8) + little(UInt64(valid.count)) }
            if offset == tagOffset + 8 { return valid.prefix(10) }
            if offset == tagOffset + 18 { return valid.dropFirst(10) }
            preconditionFailure("unexpected read")
        }
        let image = try await EmbeddedArtworkReader.imageData(read: read)
        check(image == Data(jpeg), "RIFF range parser")
        check(requests.reduce(0) { $0 + $1.1 } < 200, "skip audio bytes")
        var dsdReads = 0
        let invalidDSD: EmbeddedArtworkReader.Read = { _, count in
            dsdReads += 1
            if count == 12 { return Data("DSD ".utf8) + Data(repeating: 0, count: 8) }
            return Data("DSD ".utf8) + Data(repeating: 0, count: 8)
                + Data(repeating: 255, count: 8) + Data([254] + Array(repeating: UInt8(255), count: 7))
        }
        let invalidImage = try await EmbeddedArtworkReader.imageData(read: invalidDSD)
        check(invalidImage == nil && dsdReads == 2, "DSF offset overflow rejected")
        // Exercise the actual URLSession reader without connecting to any service/account.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ArtworkHTTPStub.self]
        ArtworkHTTPStub.fixture = valid
        for mode in ["range", "ignored", "wrong", "oversized", "chunkedOversized", "denied"] {
            let url = URL(string: "https://artwork.invalid/\(mode)")!
            do {
                let result = try await EmbeddedArtworkReader.imageData(url: url, configuration: configuration)
                check(mode == "range" && result == Data(jpeg), "HTTP \(mode)")
            } catch { check(mode != "range", "HTTP rejection \(mode)") }
        }
        // Optional real local WAV fixtures. Read only; never embed test account material in the repo.
        for path in CommandLine.arguments.dropFirst() {
            let data = try await EmbeddedArtworkReader.imageData(url: URL(fileURLWithPath: path))
            check(data != nil, "real fixture contains artwork")
            let source = CGImageSourceCreateWithData(data! as CFData, nil)
            check(source != nil, "real artwork decodes")
            let image = CGImageSourceCreateImageAtIndex(source!, 0, nil)
            check(image != nil, "real image pixels")
            print("Fixture artwork: \(image!.width)x\(image!.height)")
        }
        print("Artwork regressions passed: \(checks)")
    }
}

final class ArtworkHTTPStub: URLProtocol, @unchecked Sendable {
    static var fixture = Data()
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "artwork.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let mode = request.url!.lastPathComponent
        let range = request.value(forHTTPHeaderField: "Range")!.dropFirst(6).split(separator: "-").map { Int($0)! }
        let start = range[0], end = min(range[1], Self.fixture.count - 1)
        var data = Self.fixture.subdata(in: start..<end + 1)
        var headers = ["Content-Range": "bytes \(start)-\(end)/\(Self.fixture.count)", "Content-Length": "\(data.count)"]
        var status = 206
        switch mode {
        case "ignored": status = 200; data = Self.fixture; headers = ["Content-Length": "\(data.count)"]
        case "wrong": headers["Content-Range"] = "bytes 999-1000/2000"
        case "oversized": headers["Content-Length"] = "100000000"
        case "chunkedOversized": headers.removeValue(forKey: "Content-Length"); data = Data(repeating: 0, count: 1024)
        case "denied": status = 403
        default: break
        }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
