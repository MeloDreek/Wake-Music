import UIKit
import KakaFoundation

/// Shared navigation footer; independent of the default/cassette transport controls.
final class PlayerBottomBar: UIView {
    let playlistButton = UIButton(type: .custom)
    let moreButton = UIButton(type: .custom)
    let equalizerButton = UIButton(type: .custom)
    var onPlaylist: (() -> Void)?
    var onMore: (() -> Void)?
    var onEqualizer: (() -> Void)?

    /// The controller also supplies this reservation to the list pages.
    static func reservedHeight(safeBottom: CGFloat) -> CGFloat {
        64 + max(12, safeBottom)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        [playlistButton, equalizerButton, moreButton].forEach { addSubview($0) }
        equalizerButton.accessibilityLabel = "EQ.Title".localStr()
        equalizerButton.addTarget(self, action: #selector(showEqualizer), for: .touchUpInside)
        playlistButton.accessibilityLabel = "Queue.Title".localStr()
        moreButton.accessibilityLabel = "More".localStr()
        playlistButton.addTarget(self, action: #selector(showPlaylist), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(showMore), for: .touchUpInside)
        updateSelection(queue: false, more: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
        for (index, button) in [playlistButton, equalizerButton, moreButton].enumerated() {
            let position = rtl ? 2 - index : index
            button.frame = CGRect(x: bounds.width * CGFloat(position * 2 + 1) / 6 - 22,
                                  y: (bounds.height - 44) / 2, width: 44, height: 44)
            button.layer.cornerRadius = 22
        }
    }

    func updateSelection(queue: Bool, more: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 21, weight: .medium)
        playlistButton.setImage(UIImage(systemName: queue ? "list.bullet" : "list.triangle", withConfiguration: config), for: .normal)
        equalizerButton.setImage(UIImage(systemName: "slider.vertical.3", withConfiguration: config), for: .normal)
        moreButton.setImage(UIImage(systemName: "ellipsis.circle", withConfiguration: config), for: .normal)
        for (button, selected) in [(playlistButton, queue), (equalizerButton, false), (moreButton, more)] {
            button.imageView?.contentMode = .scaleAspectFit
            button.tintColor = .white
            button.backgroundColor = selected ? .white.withAlphaComponent(0.18) : .clear
            button.accessibilityTraits = selected ? [.button, .selected] : .button
        }
    }

    @objc private func showPlaylist() { onPlaylist?() }
    @objc private func showMore() { onMore?() }
    @objc private func showEqualizer() { onEqualizer?() }
}
