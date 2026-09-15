import UIKit
import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaPhotoBrowser
import Combine

enum LibraryDetailKind {
    case artist(String), album(String), genre(MusicGenreType)
    var title: String {
        switch self {
        case .artist(let name): return LibraryGrouping.name(name, fallback: "Unknown Artist".localStr())
        case .album(let name): return LibraryGrouping.name(name, fallback: "Unknown Album".localStr())
        case .genre(let genre): return genre.formatStr()
        }
    }
}

/// One layout and one set of actions for artist, album and genre details.
class CollectionDetailViewController: SuperViewController, UITableViewDataSource, UITableViewDelegate {
    let kind: LibraryDetailKind
    let viewModel: MusicViewModel // Keep the source alive even if its list is unloaded.
    private(set) var dataArray = [MusicItemModel]()
    private let artworkBackground = ArtworkBackgroundView()
    private var cancellables = Set<AnyCancellable>()
    private var navigationTint: UIColor?
    private var didSaveNavigationTint = false
    private let header = CollectionDetialHeadCell(style: .default, reuseIdentifier: nil)
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.backgroundColor = .clear
        table.separatorColor = UIColor.white.withAlphaComponent(0.16)
        table.separatorInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 72
        table.showsVerticalScrollIndicator = false
        table.dataSource = self
        table.delegate = self
        table.register(CollectionTrackCell.self, forCellReuseIdentifier: "track")
        return table
    }()

    init(kind: LibraryDetailKind, viewModel: MusicViewModel) {
        self.kind = kind
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func preSetupSubViews() {
        super.preSetupSubViews()
        view.insertSubview(artworkBackground, at: 0)
        contentView.backgroundColor = .clear
        contentView.addSubview(tableView)
        header.playButton.addTarget(self, action: #selector(playAll), for: .touchUpInside)
        header.shuffleButton.addTarget(self, action: #selector(shuffleAll), for: .touchUpInside)
        header.exportButton.addTarget(self, action: #selector(exportAll), for: .touchUpInside)
        header.onArtwork = { [weak self] image in
            guard let self else { return }
            self.artworkBackground.setArtwork(image) { [weak self] palette in
                self?.header.playButton.configuration?.baseForegroundColor = palette.primary
            }
        }
        header.coverImgView.isUserInteractionEnabled = true
        header.coverImgView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showArtwork)))
    }

    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        navigationItem.largeTitleDisplayMode = .never
        configureNavigation()
        NotificationCenter.default.publisher(for: Notification.Name(kLocalMusicChangedKey))
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDataAction() }.store(in: &cancellables)
        NotificationCenter.default.publisher(for: .librarySnapshotDidChange, object: viewModel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshDataAction() }.store(in: &cancellables)
        KakaMusicPlayer.shared.$playingMusic.receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.isViewLoaded else { return }
                self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
            }.store(in: &cancellables)
        refreshDataAction()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !didSaveNavigationTint {
            navigationTint = navigationController?.navigationBar.tintColor
            didSaveNavigationTint = true
        }
        navigationController?.navigationBar.tintColor = .white
        refreshDataAction()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.tintColor = navigationTint
        didSaveNavigationTint = false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    @objc override func appearanceChanged() {
        super.appearanceChanged()
        if navigationController?.topViewController === self { navigationController?.navigationBar.tintColor = .white }
    }

    private func configureNavigation() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        // Item-scoped appearance avoids tinting other pages after Back.
        navigationItem.title = ""
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        artworkBackground.frame = view.bounds
        let width = min(contentView.bounds.width, 820)
        tableView.frame = CGRect(x: (contentView.bounds.width - width) / 2, y: 0,
                                 width: width, height: contentView.bounds.height)
        tableView.contentInset.bottom = playingHeight + 24
    }

    @objc func refreshDataAction() {
        switch kind {
        case .artist:
            viewModel.refreshSingerDataAction(viewModel.allMusicArray)
            dataArray = viewModel.singerMusicArray(kind.title)
        case .album:
            viewModel.refreshAlbumDataAction(viewModel.allMusicArray)
            dataArray = viewModel.albumMusicArray(kind.title)
        case .genre(let genre):
            viewModel.refreshGenreDataAction(viewModel.allMusicArray)
            dataArray = viewModel.genreMusicArray(genre)
        }
        header.configure(kind: kind, musics: dataArray)
        tableView.reloadData()
    }

    @objc private func playAll() { play(dataArray, index: 0) }
    @objc private func shuffleAll() { play(dataArray.shuffled(), index: 0) }
    private func play(_ songs: [MusicItemModel], index: Int) {
        guard songs.indices.contains(index), checkFileExist(songs[index]) else { return }
        KakaMusicPlayer.shared.startPlayMusic(musics: songs, itemIndex: index)
    }
    @objc private func exportAll() { export(dataArray, source: header.exportButton) }

    private func handleLocalAction(_ action: MusicActionType, model: MusicItemModel) {
        switch action {
        case .musictag, .audioFinger:
            let editor = MusicTagEditorController(model)
            editor.onEditCallback = { [weak self] _ in self?.reloadLibraryAfterMutation() }
            navigationController?.pushViewController(editor, animated: true)
        case .addFavirote, .removeFavirote:
            SandboxFileManager.shared.addOrDeleteFavirote(model.mediaPlayURL)
            refreshDataAction()
        case .addPlaylist:
            let playlist = SelectPlaylistController(selectType: .selectPlaylist)
            playlist.onLocalBlock = { [weak self] folderURL in
                guard let self else { return }
                let target = folderURL.appendingPathComponent(model.filePathName() + model.addPathExtension())
                guard target.standardizedFileURL != model.mediaPlayURL.standardizedFileURL else { return }
                do {
                    try FileManager.default.moveItem(at: model.mediaPlayURL, to: target)
                    self.reloadLibraryAfterMutation()
                } catch {
                    self.view.makeToast(error.localizedDescription)
                }
            }
            present(KakaNavigationController(rootViewController: playlist), animated: true)
        case .showInFinder:
            KakaMusicPlayer.shared.showInFinderCatalyst(model.mediaPlayURL)
        case .deleteItem:
            confirmDelete(model)
        default: break
        }
    }

    /// Refresh from disk after editing/moving/deleting, not just from the old
    /// grouping snapshot. The snapshot notification updates the parent lists too.
    private func reloadLibraryAfterMutation() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.viewModel.lastMusicRefreshTime = nil
            self.viewModel.refreshMusicDataAction()
        }
    }

    private func confirmDelete(_ model: MusicItemModel) {
        #if targetEnvironment(macCatalyst)
        let choice = UIAlertController(title: "Reminder".localStr(), message: "Move to Trash or Remove Reference?".localStr(), preferredStyle: .alert)
        choice.addAction(UIAlertAction(title: "Move to Trash".localStr(), style: .destructive) { [weak self] _ in
            self?.confirmFileDeletion(model)
        })
        choice.addAction(UIAlertAction(title: "Remove Reference".localStr(), style: .default) { [weak self] _ in
            AppLocalManager.shared.removeBookmark(fileURLs: [model.mediaPlayURL]) { result in
                DispatchQueue.main.async {
                    self?.reloadLibraryAfterMutation()
                    if case .failure(let error) = result { self?.showOneAlert(message: error.localizedDescription) }
                }
            }
        })
        choice.addAction(UIAlertAction(title: "Cancel".localStr(), style: .cancel))
        present(choice, animated: true)
        #else
        confirmFileDeletion(model)
        #endif
    }

    private func confirmFileDeletion(_ model: MusicItemModel) {
        showTwoAlert(message: "Are you sure to delete it?".localStr(), confirm: "Delete".localStr(), cancle: "Cancel".localStr(), style: kaka_IsiPhone() ? .actionSheet : .alert) { [weak self] in
            SandboxFileManager.shared.deleteMusicModels(models: [model]) { result in
                switch result {
                case .success: self?.reloadLibraryAfterMutation()
                case .failure(let error): self?.showOneAlert(message: error.errorDescription)
                }
            }
        }
    }

    private func export(_ songs: [MusicItemModel], source: UIView) {
        let urls = songs.map(\.mediaPlayURL).filter { $0.isFileURL && FileManager.default.fileExists(atPath: $0.path) }
        guard !urls.isEmpty else { return }
        let activity = UIActivityViewController(activityItems: urls, applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = source
        activity.popoverPresentationController?.sourceRect = source.bounds
        present(activity, animated: true)
    }

    @objc private func showArtwork() {
        guard !kaka_IsMacOS(), let image = header.coverImgView.image else { return }
        let item = KakaPhotoItem(sourceView: header.coverImgView, image: image)
        let browser = KakaPhotoBrowser(photoItems: [item], selectedIndex: 0)
        browser.backgroundStyle = .blurPhoto
        browser.show(from: self)
    }

    private func checkFileExist(_ model: MusicItemModel) -> Bool {
        guard !FileManager.default.fileExists(atPath: model.mediaPlayURL.path) else { return true }
        let alert = UIAlertController(title: "Reminder".localStr(),
                                      message: "File not found. Would you like to delete it?".localStr(), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Delete".localStr(), style: .destructive) { [weak self] _ in
            SandboxFileManager.shared.deleteMusicModels(models: [model]) { _ in self?.refreshDataAction() }
        })
        alert.addAction(UIAlertAction(title: "Cancel".localStr(), style: .cancel))
        present(alert, animated: true)
        return false
    }

    func numberOfSections(in tableView: UITableView) -> Int { 2 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : dataArray.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 { return header }
        let model = dataArray[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "track", for: indexPath) as! CollectionTrackCell
        cell.configure(model, index: indexPath.row, showArtist: {
            if case .album = kind { return false }; return true
        }())
        cell.onLocalAction = { [weak self] action in self?.handleLocalAction(action, model: model) }
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1, dataArray.indices.contains(indexPath.row) else { return }
        if KakaMusicPlayer.shared.playingMusic == dataArray[indexPath.row] {
            KakaMusicPlayer.presentPlayController(fromVC: self)
        } else { play(dataArray, index: indexPath.row) }
    }
    // Plain-table section footers float over tracks near the mini player. The
    // count is already in the hero, so do not add a duplicate sticky footer.
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { .leastNormalMagnitude }
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { .leastNormalMagnitude }
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        navigationItem.title = scrollView.contentOffset.y > header.bounds.height - 100 ? kind.title : ""
    }
}

private final class CollectionTrackCell: UITableViewCell {
    private let numberLabel = UILabel()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
    var onLocalAction: ((MusicActionType) -> Void)?
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        let selected = UIView(); selected.backgroundColor = .white.withAlphaComponent(0.12); selectedBackgroundView = selected
        numberLabel.font = .preferredFont(forTextStyle: .subheadline)
        numberLabel.textColor = .white.withAlphaComponent(0.72)
        nameLabel.font = .preferredFont(forTextStyle: .body)
        nameLabel.textColor = .white; nameLabel.numberOfLines = 0
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .white.withAlphaComponent(0.75); subtitleLabel.numberOfLines = 0
        for label in [numberLabel, nameLabel, subtitleLabel] { label.adjustsFontForContentSizeCategory = true }
        let text = UIStackView(arrangedSubviews: [nameLabel, subtitleLabel]); text.axis = .vertical; text.spacing = 4
        let row = UIStackView(arrangedSubviews: [numberLabel, text]); row.spacing = 12; row.alignment = .center
        contentView.addSubview(row); row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 15),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -15),
            numberLabel.widthAnchor.constraint(equalToConstant: 30),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ model: MusicItemModel, index: Int, showArtist: Bool) {
        let playing = KakaMusicPlayer.shared.playingMusic == model
        numberLabel.text = playing ? "♫" : String(index + 1)
        nameLabel.text = model.showTitleName()
        nameLabel.font = .preferredFont(forTextStyle: playing ? .headline : .body)
        subtitleLabel.text = LibraryGrouping.name(model.showArtistName(), fallback: "Unknown Artist".localStr())
        subtitleLabel.isHidden = !showArtist
        let button = LocalMusicAccessory.button(model: model) { [weak self] action in self?.onLocalAction?(action) }
        button.frame.size = CGSize(width: 44, height: 44)
        button.setImage(button.image(for: .normal)?.withRenderingMode(.alwaysTemplate), for: .normal)
        button.tintColor = .white
        accessoryView = button
        accessoryType = .none
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onLocalAction = nil
        accessoryView = nil
    }
}
