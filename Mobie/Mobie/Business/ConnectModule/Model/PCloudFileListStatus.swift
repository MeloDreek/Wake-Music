import Foundation

/// Presentation only: never infer an authorization failure from an empty folder.
enum PCloudFileListEmptyState: Equatable {
    case appFolder
    case folder
    case search
    case failure(String)

    enum Action { case refresh, clearSearch }

    // This is the app folder configured in pCloud, not a localized display name.
    static let appFolderPath = "Applications/Wake Music"
    static let appFolderMessage = "Connected to pCloud. Wake Music currently has read-only access to this folder:\n%@\n\nIn pCloud, copy or upload music to this folder, then tap Refresh. Music in other folders will not appear here, even if it is listed under Audio."
    static let folderMessage = "This folder is empty. Add music to this folder in pCloud, then tap Refresh."
    static let searchMessage = "No matching files in this folder. Try a different search."

    static func empty(folderID: UInt64, query: String) -> Self {
        if !query.isEmpty { return .search }
        return folderID == 0 ? .appFolder : .folder
    }

    var action: Action { self == .search ? .clearSearch : .refresh }

    func message(localize: (String) -> String) -> String {
        switch self {
        case .appFolder:
            // Revisit this guidance when pCloud approves broader access for our app.
            return String(format: localize(Self.appFolderMessage), Self.appFolderPath)
        case .folder: return localize(Self.folderMessage)
        case .search: return localize(Self.searchMessage)
        case .failure(let message): return message
        }
    }
}

#if canImport(UIKit)
import UIKit
import KakaFoundation
import KakaUIKit

/// Scoped to pCloud; other providers retain their existing empty/error UI.
/// Scrolls on compact screens and with large text, instead of clipping the guidance.
final class PCloudFileListStatusView: UIScrollView {
    var actionHandler: ((PCloudFileListEmptyState.Action) -> Void)?
    private var state = PCloudFileListEmptyState.appFolder
    private let iconView = UIImageView()
    private let headingLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentInsetAdjustmentBehavior = .never
        keyboardDismissMode = .interactive

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        let stack = UIStackView(arrangedSubviews: [iconView, headingLabel, messageLabel, actionButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        container.addSubview(stack)

        let width = stack.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -48)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
            container.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            container.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            container.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            // Required top/bottom equality gives the scroll view an unambiguous
            // content height, including when Dynamic Type makes the text very tall.
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -48),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            iconView.heightAnchor.constraint(equalToConstant: 56),
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48),
            width
        ])
        iconView.contentMode = .scaleAspectFit
        iconView.isAccessibilityElement = false
        headingLabel.font = .preferredFont(forTextStyle: .headline)
        headingLabel.adjustsFontForContentSizeCategory = true
        headingLabel.textAlignment = .center
        headingLabel.numberOfLines = 0
        headingLabel.accessibilityTraits = .header
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textAlignment = .natural
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .secondaryLabel
        messageLabel.accessibilityIdentifier = "pcloud.folderStatus.message"
        actionButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        actionButton.titleLabel?.numberOfLines = 0
        actionButton.titleLabel?.textAlignment = .center
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        actionButton.backgroundColor = appMainColor
        actionButton.setTitleColor(UIColor(named: "DeAccentColor"), for: .normal)
        actionButton.layer.cornerRadius = 8
        actionButton.accessibilityIdentifier = "pcloud.folderStatus.action"
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ state: PCloudFileListEmptyState) {
        self.state = state
        let symbol: String
        switch state {
        case .appFolder: symbol = "folder.badge.questionmark"
        case .folder: symbol = "folder"
        case .search: symbol = "magnifyingglass"
        case .failure: symbol = "exclamationmark.triangle"
        }
        iconView.image = UIImage(systemName: symbol)
        if case .failure = state { iconView.tintColor = .systemOrange }
        else { iconView.tintColor = .secondaryLabel }
        headingLabel.text = state == .search ? "Search".localStr() : "pCloud"
        messageLabel.text = state.message { $0.localStr() }
        let buttonTitle: String
        if case .failure = state { buttonTitle = "Retry".localStr() }
        else { buttonTitle = state.action == .clearSearch ? "Cancel".localStr() : "Refresh".localStr() }
        actionButton.setTitle(buttonTitle, for: .normal)
        setContentOffset(.zero, animated: false)
    }

    @objc private func actionTapped() { actionHandler?(state.action) }
}
#endif
