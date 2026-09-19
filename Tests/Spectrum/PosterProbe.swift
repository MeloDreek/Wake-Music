import UIKit

@main enum PosterProbe {
    @MainActor static func main() throws {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String: Any]
        let report = AudioSpectrumAnalyzer.Report(pixels: [UInt8](Data(base64Encoded: json["pixels"] as! String)!),
            width: json["width"] as! Int, height: json["height"] as! Int, duration: json["duration"] as! Double,
            sampleRate: json["sampleRate"] as! Double, sourceSampleRate: json["sourceSampleRate"] as! Double,
            bytes: (json["bytes"] as! NSNumber).int64Value, codec: json["codec"] as! String)
        for locale in ["zh-Hans", "en", "ar"] {
            SpectrumCopy.locale = locale
            let poster = SpectrumReportView(title: "你看到的我", artist: "黄勇 / 任浩铭", report: report)
            poster.overrideUserInterfaceStyle = .dark
            poster.semanticContentAttribute = locale == "ar" ? .forceRightToLeft : .forceLeftToRight
            let size = poster.systemLayoutSizeFitting(CGSize(width: 640, height: 0),
                withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            precondition(size.width == 640 && size.height > 600 && size.height < 1800)
            poster.frame = CGRect(origin: .zero, size: size)
            poster.layoutIfNeeded()
            func check(_ view: UIView) {
                precondition(!view.hasAmbiguousLayout, "Ambiguous poster layout")
                for child in view.subviews { check(child) }
            }
            check(poster)
            let format = UIGraphicsImageRendererFormat(); format.scale = 2; format.opaque = true
            let image = UIGraphicsImageRenderer(size: size, format: format).image { poster.layer.render(in: $0.cgContext) }
            let output = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("spectrum-\(locale).png")
            try image.pngData()!.write(to: output)
            print("PASS_SPECTRUM_POSTER \(locale) \(size) \(output.path)")
        }
    }
}
