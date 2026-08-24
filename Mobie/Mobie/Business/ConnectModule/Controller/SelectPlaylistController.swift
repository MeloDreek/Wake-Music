//
//  SelectPlaylistController.swift
//  Mobie
//
//  Created by 张文 on 3/6/25.
//

import KakaFoundation
import AppGroupKit
import PanModal

enum SelectPlaylistType: Int {
    case selectPlaylist = 0
    case downloadTask
    case navidromeList
    
    func titleStr() -> String {
        switch self {
        case .selectPlaylist:
            return "Select Playlist".localStr()
        case .downloadTask:
            return "Download".localStr()
        case .navidromeList:
            return MusicActionType.addPlaylist.titleStr()
        }
    }
    
    func descStr() -> String {
        switch self {
        case .selectPlaylist:
            return "Please select a playlist. For offline music, folders are playlists and playlists are folders.".localStr()
        case .downloadTask:
            return "Download music for offline listening to maximize your experience. For offline music, folders are playlists and playlists are folders.".localStr()
        case .navidromeList:
            return "Please select a playlist".localStr()
        }
    }
}

/// 选择歌单（播放列表）
class SelectPlaylistController: SuperViewController {
    
    init(selectType: SelectPlaylistType, serverModel: ServerConfigModel? = nil) {
        self.selectType = selectType
        self.curServerModel = serverModel
        super.init(nibName: nil, bundle: nil)
    }
    
    @MainActor public required init?(coder: NSCoder) {
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
        
        self.title = self.selectType.titleStr()
        self.navigationItem.largeTitleDisplayMode = .never
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonClick))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "New Playlist".localStr(), style: .plain, target: self, action: #selector(addButtonClick))
        self.refreshDataAction()
    }
    
    func refreshDataAction() {
        
        if self.selectType == .navidromeList {
            self.refreshMyPlayLists()
        }else{
            let baseURL = SandboxFileManager.shared.basePublicFileURL()
            self.localArray = baseURL.readLocalSubFiles().filter({ $0.hasDirectoryPath }).filter { subFolder in
                debugPrint("文件名称 = \(subFolder.lastPathComponent.lowercased())")
                return subFolder.lastPathComponent.lowercased() != "revenuecat"
            }
            
            self.tableView.separatorStyle = localArray.isEmpty ? .none : .singleLine
            self.tableView.reloadData()
        }
    }
    
    func refreshMyPlayLists() {
        let params: [String: Any] = ["_start": 0, "_end": 0, "_order": "ASC"]
        APIManager.shared.requestNavidrome(navUser: self.curServerModel?.navUser, endpoint: API.Navidrome.getPlaylists, method: .get, parameters: params) { data in
            let jsonArray = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [[String : Any]]
            if jsonArray == nil {
                let jsonStr = String(data: data, encoding: .utf8) ?? ""
                debugPrint("jsonStr = \(jsonStr)")
            }else{
                let tempArray = [NavidromePlaylist].deserialize(from: jsonArray) ?? []
                let navUser = self.remoteArray.first?.navUser
                
                let remoteArray = tempArray.map {
                    var newModel = $0
                    newModel.navUser = navUser
                    return newModel
                }
                
                self.remoteArray = remoteArray
                ConnectConfigManager.shared.playlists = remoteArray
                self.tableView.separatorStyle = remoteArray.isEmpty ? .none : .singleLine
                self.tableView.reloadData()
            }
        } fail: { error in
            self.view.makeToast(error.localizedDescription)
            
        }
    }
    
    // MARK:  GET && SET
    
    var selectType = SelectPlaylistType.selectPlaylist
    
    var curServerModel: ServerConfigModel?

    var onRemoteBlock: ((NavidromePlaylist)->Void)?
        
    lazy var remoteArray: [NavidromePlaylist] = {
        return ConnectConfigManager.shared.playlists
    }()
    
    lazy var localArray: [URL] = {
        return [URL]()
    }()
    
    var onLocalBlock: ((URL)->Void)?
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: contentView.bounds, style: .insetGrouped)
        view.delegate = self
        view.dataSource = self
        view.tableHeaderView = self.headView
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(EmptyDataTableCell.self, forCellReuseIdentifier: "EmptyDataTableCell")
        view.register(MusicTableViewCell.self, forCellReuseIdentifier: "MusicTableViewCell")
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        
        let descStr = self.selectType.descStr()
        let font = UIFontLight(15.ckValue())
        let descHeight = descStr.height(forWidth: self.contentView.width - 30.ckValue(), font: font)
        
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 130
        case .iPadOS: height = 150
        case .macOS: height = 150
        }
        
        let iconImage = UIImage(systemName: "music.note.list")
        let view = UITableViewHeaderFooterView(frame: CGRectMake(0, 0, self.view.width, height + descHeight + 10.ckValue()))
        view.backgroundColor = .clear
        let faceImgView = UIImageView(image: iconImage)
        faceImgView.contentMode = .scaleAspectFit
        view.contentView.addSubview(faceImgView)
        faceImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(15.ckValue())
            make.size.equalTo(height - descHeight - 10.ckValue())
        }
        
        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.text = descStr
        titleLabel.font = font
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        view.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(faceImgView.snp.bottom).offset(5.ckValue())
            make.leading.equalTo(15.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        return view
    }()
    
    @objc func addButtonClick() {
        let editAlertVC = UIAlertController(title: "New Playlist".localStr(), message: nil, preferredStyle: .alert)
        editAlertVC.addTextField { textView in
            textView.clearButtonMode = .always
        }
        
        let action1 = UIAlertAction(title: "Cancel".localStr(), style: .cancel, handler: nil)
        let action2 = UIAlertAction(title: "Done".localStr(), style: .destructive, handler: { [weak self] action in
            guard let nameField = editAlertVC.textFields?.first, let nameText = nameField.text?.standardFileName, nameText.count > 0 else {
                return
            }
                        
            SandboxFileManager.shared.addOrUpdateFolder(folderName: nameText) { result in
                switch result {
                case .success(_):
                    self?.refreshDataAction()
                case .failure(let kakaError):
                    self?.view.makeToast(kakaError.errorDescription)
                }
            }

        })
        
        action1.setValue(UIColor.systemBlue, forKey: "_titleTextColor")
        
        editAlertVC.addAction(action1)
        editAlertVC.addAction(action2)
        
        self.present(editAlertVC, animated: true)
    }
}

extension SelectPlaylistController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.selectType == .navidromeList {
            return remoteArray.count > 0 ? remoteArray.count : 1
        }else{
            return localArray.count > 0 ? localArray.count : 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if self.selectType == .navidromeList {
            if remoteArray.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
                let subModel = remoteArray[indexPath.row]
                cell.coverImgView.kf.setImage(with: subModel.coverImgURL(), placeholder: UIImage(named: "music_place"))
                cell.nameLabel.text = subModel.name
                cell.descLabel.text = String(format: "%d songs".localStr(), subModel.songCount)
                cell.loadingBgView.isHidden = true
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView = nil
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                cell.selectionStyle = .none
                cell.backgroundColor = .clear
                cell.updateMessage()
                return cell
            }
        }else{
            if localArray.count > 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "MusicTableViewCell", for: indexPath) as! MusicTableViewCell
                let subURL = localArray[indexPath.row]
                cell.coverImgView.image = UIImage(named: "folder_icon")
                cell.nameLabel.text = subURL.lastPathComponent
                cell.descLabel.text = String(format: "%d songs".localStr(), subURL.readLocalSubFiles().count)
                cell.loadingBgView.isHidden = true
                cell.accessoryType = .disclosureIndicator
                cell.accessoryView = nil
                return cell
            }else{
                let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyDataTableCell", for: indexPath) as! EmptyDataTableCell
                cell.selectionStyle = .none
                cell.backgroundColor = .clear
                cell.updateMessage("Create your first folder (playlist)".localStr())
                return cell
            }
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if self.selectType == .navidromeList {
            if remoteArray.count > 0 {
                let selectModel = remoteArray[indexPath.row]
                self.onRemoteBlock?(selectModel)
                self.dismiss(animated: true)
            }
        }else{
            if localArray.count > 0 {
                let subURL = localArray[indexPath.row]
                self.onLocalBlock?(subURL)
                self.dismiss(animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if self.selectType == .navidromeList {
            return remoteArray.isEmpty ? 500.ckValue() : UITableView.automaticDimension
        }else{
            return localArray.isEmpty ? 500.ckValue() : UITableView.automaticDimension
        }
    }
}
