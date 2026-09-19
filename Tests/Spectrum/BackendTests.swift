import Foundation

@main enum BackendTests {
    static func main() {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let analyzer = AudioSpectrumAnalyzer()
        if CommandLine.arguments.contains("--cancel") { analyzer.cancel() }
        analyzer.start(url: url, progress: { _ in
            if CommandLine.arguments.contains("--cancel-active") { analyzer.cancel() }
        }, completion: { result in
            switch result {
            case .success(let report):
                precondition(!CommandLine.arguments.contains("--fail") && !CommandLine.arguments.contains("--cancel") && !CommandLine.arguments.contains("--cancel-active"))
                precondition(report.duration > 0 && report.bytes > 0 && report.pixels.count == 768 * 256 * 4)
                if let expectation = CommandLine.arguments.first(where: { $0.hasPrefix("--expect-skipped=") }),
                   let skipped = Int(expectation.split(separator: "=").last!) {
                    precondition(report.skippedPacketCount == skipped)
                }
                if CommandLine.arguments.contains("--expect-complete-timeline") {
                    // An isolated invalid frame halfway through must not pull
                    // later audio earlier and leave an artificial gap at the end.
                    precondition((0..<report.height).contains { row in
                        report.pixels[(row * report.width + report.width - 1) * 4] > 50
                    })
                }
                print("PASS_SPECTRUM_FILE \(url.lastPathComponent) codec=\(report.codec) rate=\(report.sourceSampleRate) duration=\(report.duration) skipped=\(report.skippedPacketCount)")
                if let output = ProcessInfo.processInfo.environment["SPECTRUM_REPORT_PATH"] {
                    let values: [String: Any] = ["pixels": Data(report.pixels).base64EncodedString(), "width": report.width,
                        "height": report.height, "duration": report.duration, "sampleRate": report.sampleRate,
                        "sourceSampleRate": report.sourceSampleRate, "bytes": report.bytes, "codec": report.codec,
                        "skippedPacketCount": report.skippedPacketCount]
                    try! JSONSerialization.data(withJSONObject: values).write(to: URL(fileURLWithPath: output))
                }
            case .failure:
                precondition(CommandLine.arguments.contains("--fail") || CommandLine.arguments.contains("--cancel") || CommandLine.arguments.contains("--cancel-active"))
                print("PASS_SPECTRUM_REJECT \(url.lastPathComponent)")
            }
            exit(0)
        })
        dispatchMain()
    }
}
