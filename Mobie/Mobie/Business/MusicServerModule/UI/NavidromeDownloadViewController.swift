import UIKit
import AppGroupKit
import KakaFoundation
import KakaUIKit
import Combine

/// Navidrome owns its presentation; the classic download sheet and shared queue stay independent.
final class NavidromeDownloadViewController: SuperViewController {
    private let onExit: () -> Void
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let refreshControl = UIRefreshControl()
    private var tasks: [MusicItemModel] = []
    private var subscriptions = Set<AnyCancellable>()
    private var lastViewportSize = CGSize.zero

    init(onExit: @escaping () -> Void) {
        self.onExit = onExit
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Download".localStr()
        navigationItem.largeTitleDisplayMode = .automatic
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.register(MusicTableViewCell.self, forCellReuseIdentifier: "download")
        tableView.register(NavidromeDownloadEmptyCell.self, forCellReuseIdentifier: "empty")
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: contentView.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
#if !targetEnvironment(macCatalyst)
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
#endif
        DownloadManager.shared.activateDownloads()
        DownloadManager.shared.$taskArray.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.refresh()
        }.store(in: &subscriptions)
        DownloadManager.shared.downloadUpdates
            .throttle(for: .milliseconds(250), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] in self?.refresh() }.store(in: &subscriptions)
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = tableView.bounds.inset(by: tableView.adjustedContentInset).size
        if size != lastViewportSize {
            lastViewportSize = size
            if tasks.isEmpty { tableView.reloadData() }
        }
    }

    @objc private func refresh() {
        tasks = DownloadManager.shared.taskArray
        let running = DownloadManager.shared.downloadsRunning
        navigationItem.rightBarButtonItem = running
            ? UIBarButtonItem(image: UIImage(systemName: "stop.circle.fill"), style: .plain, target: self, action: #selector(pause))
            : UIBarButtonItem(title: "Download".localStr(), style: .plain, target: self, action: #selector(resume))
        navigationItem.rightBarButtonItem?.accessibilityLabel = running ? "MusicServer.Downloads.Pause".localStr() : "Download".localStr()
        navigationItem.rightBarButtonItem?.isEnabled = !tasks.isEmpty
        refreshControl.endRefreshing()
        tableView.reloadData()
    }

    @objc private func pause() { DownloadManager.shared.pauseDownloads(); refresh() }
    @objc private func resume() {
        guard !tasks.isEmpty, requireRemoteConnectionAccess() else { return }
        DownloadManager.shared.resumeDownloads()
        refresh()
    }

    private func retry(_ model: MusicItemModel) {
        guard requireRemoteConnectionAccess(),
              DownloadManager.shared.taskArray.contains(where: { $0.preDownloadIdentity() == model.preDownloadIdentity() }) else { return }
        if let error = DownloadManager.shared.downloadError(for: model) {
            showTwoAlert(message: error, confirm: "Retry".localStr()) {
                // It may have completed while the alert was open; do not re-enqueue a finished song.
                guard DownloadManager.shared.taskArray.contains(where: { $0.preDownloadIdentity() == model.preDownloadIdentity() }) else { return }
                DownloadManager.shared.prioritizeDownload(model)
            }
        } else { DownloadManager.shared.prioritizeDownload(model) }
    }
}

extension NavidromeDownloadViewController: UITableViewDataSource, UITableViewDelegate, MusicTableViewCellDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { max(1, tasks.count) }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !tasks.isEmpty else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty", for: indexPath) as! NavidromeDownloadEmptyCell
            cell.contentView.backgroundColor = .clear
            cell.onExit = onExit
            cell.minimumHeight = max(0, tableView.bounds.height - tableView.adjustedContentInset.top - tableView.adjustedContentInset.bottom - 40)
            return cell
        }
        let model = tasks[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "download", for: indexPath) as! MusicTableViewCell
        cell.delegate = self
        cell.update(musicModel: model, cellType: .download)
        if let progress = DownloadManager.shared.downloadProgress(for: model) {
            let indicator = CircleProgressView(frame: CGRect(x: 0, y: 0, width: 30.ckValue(), height: 30.ckValue()))
            indicator.progress = progress
            cell.accessoryView = indicator
        } else if let error = DownloadManager.shared.downloadError(for: model) {
            let indicator = UIImageView(image: UIImage(systemName: "exclamationmark.circle"))
            indicator.tintColor = .systemOrange
            indicator.accessibilityLabel = error
            cell.accessoryView = indicator
        }
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard !tasks.isEmpty else { return nil }
        return String(format: "%d songs".localStr(), tasks.count) + " " + URL.formatFileSize(tasks.map { $0.fileSize() }.reduce(0, +))
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard tasks.indices.contains(indexPath.row) else { return }
        retry(tasks[indexPath.row])
    }

    func musicTableCell(cell: MusicTableViewCell, model: MusicItemModel, action: MusicActionType) {
        if action == .download { retry(model) }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard tasks.indices.contains(indexPath.row) else { return nil }
        let model = tasks[indexPath.row]
        let action = UIContextualAction(style: .destructive, title: "Delete".localStr()) { [weak self] _, _, finish in
            guard let self, presentedViewController == nil else { finish(false); return }
            let alert = UIAlertController(title: "Reminder".localStr(), message: "Are you sure to delete it?".localStr(), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Delete".localStr(), style: .destructive) { [weak self] _ in
                _ = DownloadManager.shared.removeFromDownloads(model)
                self?.refresh()
                finish(true)
            })
            alert.addAction(UIAlertAction(title: "Delete All".localStr(), style: .destructive) { [weak self] _ in
                DownloadManager.shared.pauseDownloads()
                DownloadManager.shared.taskArray = []
                self?.refresh()
                finish(true)
            })
            alert.addAction(UIAlertAction(title: "Cancel".localStr(), style: .cancel) { _ in finish(false) })
            present(alert, animated: true)
        }
        action.image = UIImage(systemName: "trash")
        let configuration = UISwipeActionsConfiguration(actions: [action])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}

final class NavidromeDownloadEmptyCell: UITableViewCell {
    var onExit: (() -> Void)?
    private static let messageKey = "MusicServer.Downloads.OfflineMessage"
    private let stack = UIStackView()
    private var minimumHeightConstraint: NSLayoutConstraint!
    var minimumHeight: CGFloat = 0 {
        didSet { minimumHeightConstraint.constant = minimumHeight }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        let image = UIImage(named: "empty_music")
        let icon = UIImageView(image: image)
        icon.contentMode = .scaleAspectFit
        icon.isAccessibilityElement = false
        let message = UILabel()
        message.text = Self.messageKey.localStr()
        message.font = .preferredFont(forTextStyle: .body)
        message.adjustsFontForContentSizeCategory = true
        message.textColor = .secondaryLabel
        message.numberOfLines = 0
        message.textAlignment = .center
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = "Back to Classic Mode".localStr()
        config.baseBackgroundColor = appMainColor
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        config.titleLineBreakMode = .byWordWrapping
        button.configuration = config
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.textAlignment = .center
        button.addTarget(self, action: #selector(exitTapped), for: .touchUpInside)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 28
        [icon, message, button].forEach { stack.addArrangedSubview($0) }
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        // Auto Layout may grow past the viewport for large text; the whole message/button scrolls.
        minimumHeightConstraint = contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        minimumHeightConstraint.priority = UILayoutPriority(999)
        minimumHeightConstraint.isActive = true
        let width = stack.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -40)
        width.priority = UILayoutPriority(999)
        let ratio = image.map { $0.size.height / max(1, $0.size.width) } ?? 0.6
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 440),
            stack.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, constant: -40), width,
            icon.widthAnchor.constraint(equalTo: stack.widthAnchor),
            icon.heightAnchor.constraint(equalTo: icon.widthAnchor, multiplier: ratio),
            message.widthAnchor.constraint(equalTo: stack.widthAnchor),
            button.widthAnchor.constraint(equalTo: stack.widthAnchor),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func prepareForReuse() { super.prepareForReuse(); onExit = nil; minimumHeight = 0 }
    @objc private func exitTapped() { onExit?() }
}
