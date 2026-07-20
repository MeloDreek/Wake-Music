//
//  ArtistDetialViewController.swift
//  Wake Music
//
//  Created by Melo on 9/11/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaPhotoBrowser

class ArtistDetialViewController: SuperViewController {
    init(singer: String, viewModel: MusicViewModel) {
        super.init(nibName: nil, bundle: nil)
        self.singer = singer
        self.viewModel = viewModel
    }
    
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func preSetupSubViews() {
        super.preSetupSubViews()
        
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
        
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        
        self.title = "Artist".localStr()
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItem = self.moreBarItem
        
        let barAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        barAppearance.configureWithTransparentBackground()
        self.navigationController?.navigationBar.scrollEdgeAppearance = barAppearance
                        
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true

        self.refreshDataAction()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        let barAppearance = UINavigationBarAppearance(idiom: UIDevice.current.userInterfaceIdiom)
        barAppearance.configureWithDefaultBackground()
        self.navigationController?.navigationBar.scrollEdgeAppearance = barAppearance
    }
    
    @objc func refreshDataAction() {
        self.viewModel.refreshSingerDataAction(self.viewModel.allMusicArray)
        
        self.dataArray = viewModel.singerMusicArray(singer)
        self.tableView.reloadData()
    }
    
    // MARK:  GET && SET
    var singer: String!
    
    var editModel: MusicItemModel?
        
    weak var viewModel: MusicViewModel!
        
    lazy var dataArray: [MusicItemModel] = {
        return [MusicItemModel]()
    }()
        
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.contentInsetAdjustmentBehavior = .automatic
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
        view.register(CollectionDetialHeadCell.self, forCellReuseIdentifier: "CollectionDetialHeadCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        return view
    }()
    
    lazy var moreBarItem: UIBarButtonItem = {
        let view = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareAction))
        return view
    }()
    
    @objc func shareAction() {
        self.shareMusicModel(self.dataArray)
    }
    
}

extension ArtistDetialViewController: UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : dataArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "CollectionDetialHeadCell", for: indexPath) as! CollectionDetialHeadCell
            cell.setArtist(artist: self.singer, musics: self.dataArray)
            return cell
        }else{
            let model = dataArray[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
            cell.update(musicModel: model, cellType: .local)
            cell.accessoryType = .disclosureIndicator
            cell.accessoryView = nil
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            if kaka_IsMacOS() { return }
            guard let coverCell = tableView.cellForRow(at: indexPath) as? CollectionDetialHeadCell else { return }
            let photoItem = KakaPhotoItem(sourceView: coverCell.coverImgView, image: coverCell.coverImgView.image)
            let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
            photoBrowser.backgroundStyle = .blurPhoto
            photoBrowser.show(from: self)
            return
        }
        
        let model = dataArray[indexPath.row]
        
        if !self.checkFileExist(model) {
            return
        }
        
        let isPlaying: Bool = KakaMusicPlayer.shared.playingMusic == model
        
        if isPlaying {
            KakaMusicPlayer.presentPlayController(fromVC: self)
        }else{
            KakaMusicPlayer.shared.startPlayMusic(musics: dataArray, itemIndex: indexPath.row)
        }
                
        tableView.reloadData()
    }
    
    func checkFileExist(_ model: MusicItemModel) -> Bool {
        if FileManager.default.fileExists(atPath: model.mediaPlayURL.path) {
            return true
        }
        
        let alertController: UIAlertController = UIAlertController(title: "Reminder".localStr(), message: "File doesn't exist, do you delete it?".localStr(), preferredStyle: kaka_IsiPhone() ? .actionSheet : .alert)
        let action1 = UIAlertAction(title: "Delete".localStr(), style: .destructive) { (sender) in
            SandboxFileManager.shared.deleteMusicModels(models: [model]) { [weak self] models in
                self?.refreshDataAction()
            } fail: { [weak self] errorMsg in
                self?.refreshDataAction()
            }

        }
        let action2 = UIAlertAction(title: "Cancel".localStr(), style: .cancel)
        
        alertController.addAction(action1)
        alertController.addAction(action2)
        
        action1.setValue(UIColor.systemRed, forKey: "_titleTextColor")
        action2.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        self.present(alertController, animated: true, completion: nil)
        return false
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return nil
        }else{
            let secondStr = String(format: "%d songs".localStr(), self.dataArray.count)
            return secondStr
        }
    }
    
    // 4️⃣ 分享歌曲
    func shareMusicModel(_ models: [MusicItemModel]?) {
        
        var tempArray = [URL]()
        for subModel in (models ?? []) {
            let subURL = subModel.mediaPlayURL
            tempArray.append(subURL)
        }
                
        let shareVC = UIActivityViewController(activityItems: tempArray, applicationActivities: nil)
        shareVC.completionWithItemsHandler = { [weak self] (activityType, completed, returnedItems, activityError) in
            if completed {
                if let activityType = activityType {
                    debugPrint("Share Type = \(activityType.rawValue)")
                    let musicStr = self?.dataArray.compactMap { $0.showTitleName() }.joined(separator: " & ") ?? ""
                    AnalyticsManager.shared.logEvent("share_singer", parameters: ["shareType": activityType.rawValue, "musics": musicStr])
                }
            } else {
                AnalyticsManager.shared.logEvent("singer_cancel_share")
            }
                        
        }
        if !kaka_IsiPhone() {
            shareVC.popoverPresentationController?.sourceView = self.navigationController?.navigationBar
        }
        self.present(shareVC, animated: true, completion: nil)
    }
    
}
