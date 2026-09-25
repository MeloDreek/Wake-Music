import UIKit

@main
enum BatchHeaderProbe {
    @MainActor static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 2 else {
            fatalError("Usage: batch-header-probe OUTPUT.png [WIDTH_POINTS] [SCALE] [light|dark]")
        }
        let width = CGFloat(Double(arguments.count > 2 ? arguments[2] : "400")!)
        let scale = CGFloat(Double(arguments.count > 3 ? arguments[3] : "3")!)
        let appearance: UIUserInterfaceStyle = arguments.count > 4 && arguments[4] == "dark" ? .dark : .light
        let traits = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceStyle: appearance),
            UITraitCollection(displayScale: scale),
            UITraitCollection(preferredContentSizeCategory: .large),
            UITraitCollection(layoutDirection: .leftToRight)
        ])
        var output: Data!
        traits.performAsCurrent {
            let canvas = UIView(frame: CGRect(x: 0, y: 0, width: width, height: MusicTopBatchEditHeadView.headHeight()))
            canvas.overrideUserInterfaceStyle = appearance
            canvas.backgroundColor = .clear
            let header = MusicTopBatchEditHeadView(reuseIdentifier: "screenshot-fixture")
            header.frame = canvas.bounds
            header.overrideUserInterfaceStyle = appearance
            header.backgroundView = UIView()
            header.backgroundView?.backgroundColor = .clear
            canvas.addSubview(header)
            // This filename is presentation data only; the URL is never opened.
            let model = MusicItemModel(mediaPlayURL: URL(fileURLWithPath: "/screenshot-fixture/Lady Gaga & Bruno Mars - Die With A Smile.flac"))
            header.state = .matching
            header.updateProgress(curModel: model, completed: 4, total: 9)
            canvas.setNeedsLayout()
            canvas.layoutIfNeeded()
            header.setNeedsLayout()
            header.layoutIfNeeded()
            precondition(header.matchingView.progressView.numberLabel.text == "4/9")
            precondition(header.matchingView.progressView.percentLabel.text == "44.44%")
            precondition(!header.matchingView.isHidden && header.normalView.isHidden && header.completedView.isHidden)
            precondition(header.matchingView.bounds.width == width)
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = false
            output = UIGraphicsImageRenderer(size: canvas.bounds.size, format: format).pngData { context in
                canvas.layer.render(in: context.cgContext)
            }
            print("BATCH_HEADER_GEOMETRY canvas=\(canvas.bounds) card=\(header.matchingView.backView.frame) title=\(header.matchingView.musicLabel.frame) progress=\(header.matchingView.progressView.frame)")
        }
        try output.write(to: URL(fileURLWithPath: arguments[1]), options: .atomic)
        print("BATCH_HEADER_RENDERED \(arguments[1]) \(Int(width * scale))x\(Int(180 * scale)) simulated=4/9")
    }
}
