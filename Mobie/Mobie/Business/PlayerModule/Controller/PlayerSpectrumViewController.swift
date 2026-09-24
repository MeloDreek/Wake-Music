import UIKit
import AppGroupKit
import KakaFoundation

final class PlayerSpectrumViewController: UIViewController {
    private let model: MusicItemModel
    private let analyzer = AudioSpectrumAnalyzer()
    private var report: AudioSpectrumAnalyzer.Report?
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let status = UILabel()
    private let progress = UIProgressView(progressViewStyle: .default)
    private let shareButton = UIButton(type: .system)
    private var reportView: SpectrumReportView?

    init(model: MusicItemModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { analyzer.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        title = "Spectrum.Title".localStr()
        view.backgroundColor = UIColor(white: 0.055, alpha: 1)
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -28),
            stack.centerXAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerXAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            scroll.contentLayoutGuide.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 840)
        ])
        let width = stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32)
        width.priority = .defaultHigh
        width.isActive = true
        let card = SpectrumReportView(title: model.showTitleName(), artist: model.showArtistName(), report: nil)
        reportView = card
        stack.addArrangedSubview(card)
        // Mac's native button ignores this card's filled appearance and height.
        shareButton.preferredBehavioralStyle = .pad
        var shareConfiguration = UIButton.Configuration.filled()
        shareConfiguration.title = "Spectrum.Share".localStr()
        shareConfiguration.image = UIImage(systemName: "square.and.arrow.up")
        shareConfiguration.imagePadding = 10
        shareConfiguration.baseBackgroundColor = SpectrumReportView.amber
        shareConfiguration.baseForegroundColor = UIColor(white: 0.08, alpha: 1)
        shareConfiguration.cornerStyle = .large
        shareConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        shareButton.configuration = shareConfiguration
        shareButton.titleLabel?.numberOfLines = 0
        shareButton.titleLabel?.textAlignment = .center
        shareButton.titleLabel?.adjustsFontForContentSizeCategory = true
        shareButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
        shareButton.addTarget(self, action: #selector(share), for: .touchUpInside)
        shareButton.isHidden = true
        stack.addArrangedSubview(shareButton)
        status.font = .preferredFont(forTextStyle: .footnote)
        status.adjustsFontForContentSizeCategory = true
        status.textColor = .secondaryLabel
        status.numberOfLines = 0
        stack.addArrangedSubview(progress)
        stack.addArrangedSubview(status)
        // Some remote providers use local HLS manifests. Source type is checked
        // too, so we never mistake a playlist/cache fragment for a local song.
        guard model.isLocalFile(), model.mediaPlayURL.isFileURL else {
            progress.isHidden = true
            status.text = "Spectrum.Remote".localStr()
            return
        }
        startAnalysis()
    }

    private func startAnalysis() {
        status.text = "Spectrum.Analyzing".localStr()
        let sandbox = SandboxFileManager.shared
        let cache = AudioSpectrumCache(directory: sandbox.spectrumPathURL(), identity:
            MusicArtworkCache.localIdentity(url: model.mediaPlayURL, documents: sandbox.basePublicFileURL()))
        analyzer.start(url: model.mediaPlayURL, cache: cache, progress: { [weak self] fraction in
            self?.progress.progress = Float(fraction)
        }, completion: { [weak self] result in
            guard let self else { return }
            self.progress.isHidden = true
            switch result {
            case .success(let report):
                self.report = report
                self.reportView?.removeFromSuperview()
                let card = SpectrumReportView(title: self.model.showTitleName(), artist: self.model.showArtistName(), report: report)
                self.reportView = card
                self.stack.insertArrangedSubview(card, at: 0)
                self.status.isHidden = true
                self.shareButton.isHidden = false
            case .failure:
                self.status.text = "Spectrum.Error".localStr()
            }
        })
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true { analyzer.cancel() }
    }
    @objc private func close() { analyzer.cancel(); dismiss(animated: true) }

    @objc private func share() {
        guard let report, presentedViewController == nil else { return }
        let poster = SpectrumReportView(title: model.showTitleName(), artist: model.showArtistName(), report: report)
        poster.overrideUserInterfaceStyle = .dark
        let width: CGFloat = 640
        let size = poster.systemLayoutSizeFitting(CGSize(width: width, height: 0),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        poster.frame = CGRect(origin: .zero, size: size)
        poster.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        let png = UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIBezierPath(roundedRect: poster.bounds, cornerRadius: poster.layer.cornerRadius).addClip()
            poster.layer.render(in: context.cgContext)
        }
        // Sharing the PNG file preserves its format and transparent rounded corners.
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Wakemusic-Spectrum-\(UUID().uuidString).png")
        do {
            try png.write(to: fileURL, options: .atomic)
            let activity = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            activity.popoverPresentationController?.sourceView = shareButton
            activity.popoverPresentationController?.sourceRect = shareButton.bounds
            activity.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: fileURL)
            }
            present(activity, animated: true)
        } catch {
            showOneAlert(message: error.localizedDescription)
        }
    }
}

/// Shared on-screen/poster layout: etched metal chassis, recessed display and
/// restrained amber accents. No decorative/fake spectral data is generated.
final class SpectrumReportView: UIView {
    private let finish = CAGradientLayer()
    private var screws: [UIView] = []

    init(title: String, artist: String, report: AudioSpectrumAnalyzer.Report?) {
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 0.08, alpha: 1)
        finish.colors = [UIColor(white: 0.19, alpha: 1).cgColor, UIColor(white: 0.07, alpha: 1).cgColor,
                         UIColor(white: 0.12, alpha: 1).cgColor]
        finish.startPoint = .zero
        finish.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(finish, at: 0)
        layer.cornerRadius = 18
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 0.30, alpha: 1).cgColor
        for _ in 0..<4 {
            let screw = UIView()
            screw.backgroundColor = UIColor(white: 0.28, alpha: 1)
            screw.layer.cornerRadius = 3.5
            screw.layer.borderWidth = 0.5
            screw.layer.borderColor = UIColor(white: 0.52, alpha: 1).cgColor
            screw.layer.shadowColor = UIColor.black.cgColor
            screw.layer.shadowOpacity = 0.8
            screw.layer.shadowRadius = 1
            screw.layer.shadowOffset = CGSize(width: 0, height: 1)
            let slot = UIView(frame: CGRect(x: 1, y: 3, width: 5, height: 1))
            slot.backgroundColor = .black
            slot.transform = CGAffineTransform(rotationAngle: -.pi / 4)
            screw.addSubview(slot)
            addSubview(screw)
            screws.append(screw)
        }
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 28), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22)
        ])
        let caption = Self.label("Spectrum.Title".localStr(), size: 13, color: Self.amber)
        caption.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: 13, weight: .semibold))
        stack.addArrangedSubview(caption)
        let song = Self.label(title, size: 25, color: .white)
        song.font = .preferredFont(forTextStyle: .title2)
        song.adjustsFontForContentSizeCategory = true
        song.numberOfLines = 4
        stack.addArrangedSubview(song)
        if !artist.isEmpty { stack.addArrangedSubview(Self.label(artist, size: 16)) }
        let plot = SpectrumPlotView(report: report)
        plot.heightAnchor.constraint(equalTo: plot.widthAnchor, multiplier: 0.74).isActive = true
        stack.addArrangedSubview(plot)
        if let report {
            if report.skippedPacketCount > 0 {
                // Keep this on the shared card so exported posters disclose gaps too.
                stack.addArrangedSubview(Self.label("Spectrum.Partial".localStr(), size: 13, color: Self.amber))
            }
            let size = ByteCountFormatter.string(fromByteCount: report.bytes, countStyle: .file)
            let metrics = [
                ("Spectrum.Format".localStr(), report.codec), ("File Size".localStr(), size),
                ("Spectrum.AverageBitrate".localStr(), String(format: "%.0f kbps", report.averageBitrate / 1000)),
                ("Sample Rate".localStr(), report.sourceSampleRate >= 1_000_000
                    ? String(format: "%g MHz", report.sourceSampleRate / 1_000_000)
                    : String(format: "%g kHz", report.sourceSampleRate / 1000))
            ]
            for start in stride(from: 0, to: metrics.count, by: 2) {
                let row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = 14
                for item in metrics[start..<start + 2] {
                    let group = UIStackView(arrangedSubviews: [Self.label(item.0, size: 12), Self.label(item.1, size: 18, color: .white)])
                    group.axis = .vertical; group.spacing = 5
                    row.addArrangedSubview(group)
                }
                stack.addArrangedSubview(row)
            }
            if report.sampleRate != report.sourceSampleRate {
                stack.addArrangedSubview(Self.label(String(format: "Spectrum.AnalysisRate".localStr(), report.sampleRate / 1000), size: 12, color: Self.amber))
            }
            stack.addArrangedSubview(Self.label("Spectrum.Guide".localStr(), size: 12))
        }
        let brand = UIStackView()
        brand.axis = .horizontal
        brand.spacing = 10
        brand.alignment = .center
#if Target_Mobie_Pro
        let logo = UIImageView(image: UIImage(named: "app_logo_pro"))
#else
        let logo = UIImageView(image: UIImage(named: "app_logo"))
#endif
        logo.contentMode = .scaleAspectFit
        logo.layer.cornerRadius = 8
        logo.clipsToBounds = true
        logo.widthAnchor.constraint(equalToConstant: 34).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 34).isActive = true
        brand.addArrangedSubview(logo)
        brand.addArrangedSubview(Self.label("Powered by Wakemusic".localStr(), size: 13, color: .white))
        if report != nil { stack.addArrangedSubview(brand) }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        finish.frame = bounds
        for (index, screw) in screws.enumerated() {
            screw.frame = CGRect(x: index % 2 == 0 ? 9 : bounds.width - 16,
                                 y: index < 2 ? 9 : bounds.height - 16, width: 7, height: 7)
        }
    }
    static let amber = UIColor(red: 1, green: 0.73, blue: 0.36, alpha: 1)
    private static func label(_ text: String, size: CGFloat, color: UIColor = UIColor(white: 0.65, alpha: 1)) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .natural
        label.textColor = color
        label.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: .systemFont(ofSize: size))
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}

final class SpectrumPlotView: UIView {
    private let report: AudioSpectrumAnalyzer.Report?
    private let image: CGImage?
    init(report: AudioSpectrumAnalyzer.Report?) {
        self.report = report
        if let report, let provider = CGDataProvider(data: Data(report.pixels) as CFData) {
            image = CGImage(width: report.width, height: report.height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: report.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider,
                decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        } else { image = nil }
        super.init(frame: .zero)
        backgroundColor = UIColor(red: 0.02, green: 0.03, blue: 0.05, alpha: 1)
        layer.cornerRadius = 10
        layer.borderColor = UIColor(white: 0.28, alpha: 1).cgColor
        layer.borderWidth = 1
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityLabel = "Spectrum.Title".localStr()
        accessibilityValue = "Spectrum.Guide".localStr()
        // Time/frequency axes keep their physical orientation in RTL too.
        semanticContentAttribute = .forceLeftToRight
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let plot = CGRect(x: 42, y: 22, width: max(1, bounds.width - 54), height: max(1, bounds.height - 70))
        if let image { UIImage(cgImage: image).draw(in: plot) }
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 9, weight: .regular), .foregroundColor: UIColor(white: 0.75, alpha: 1)]
        func text(_ value: String, x: CGFloat, y: CGFloat) { (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attributes) }
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.13).cgColor)
        context.setLineWidth(0.5)
        for tick in 0...4 {
            let fraction = CGFloat(tick) / 4
            let y = plot.maxY - fraction * plot.height
            context.move(to: CGPoint(x: plot.minX, y: y)); context.addLine(to: CGPoint(x: plot.maxX, y: y))
            if let report { text(String(format: "%.1f", report.sampleRate / 2000 * Double(fraction)), x: 5, y: y - 5) }
            let x = plot.minX + fraction * plot.width
            context.move(to: CGPoint(x: x, y: plot.minY)); context.addLine(to: CGPoint(x: x, y: plot.maxY))
            if let report {
                let seconds = Int(report.duration * Double(fraction))
                text(String(format: "%d:%02d", seconds / 60, seconds % 60), x: min(x - 10, bounds.width - 35), y: plot.maxY + 6)
            }
        }
        context.strokePath()
        text("kHz", x: 5, y: 5)
        let colors = [UIColor(red: 0.02, green: 0.035, blue: 0.07, alpha: 1).cgColor,
                      UIColor(red: 0.13, green: 0.11, blue: 0.35, alpha: 1).cgColor,
                      UIColor(red: 0.58, green: 0.16, blue: 0.46, alpha: 1).cgColor,
                      UIColor(red: 0.93, green: 0.44, blue: 0.18, alpha: 1).cgColor,
                      UIColor(red: 1, green: 0.92, blue: 0.60, alpha: 1).cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil) {
            context.saveGState()
            context.clip(to: CGRect(x: plot.minX, y: bounds.height - 19, width: plot.width, height: 4))
            context.drawLinearGradient(gradient, start: CGPoint(x: plot.minX, y: 0), end: CGPoint(x: plot.maxX, y: 0), options: [])
            context.restoreGState()
        }
        text("−100 dBFS", x: plot.minX, y: bounds.height - 13)
        text("0 dBFS", x: plot.maxX - 35, y: bounds.height - 13)
    }
}
