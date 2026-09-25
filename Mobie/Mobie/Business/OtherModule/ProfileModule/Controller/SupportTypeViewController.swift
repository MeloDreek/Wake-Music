//
//  SupportTypeViewController.swift
//  Mobie
//
//  Created by 张文 on 11/4/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import KakaPhotoBrowser

extension AudioLevelType {
    func headStr() -> String {
        switch self {
        case .SACD:
            return "Super Lossless".localStr()
        case .lossless:
            return "Lossless".localStr()
        case .normal:
            return "Lossy".localStr()
        }
    }
    
    func footStr() -> String? {
        // Container extensions cannot establish sample rate, channel count,
        // master quality, or whether the source was originally lossless.
        self == .normal ? "Formats.GroupingNote".localStr() : nil
    }
    
}

class SupportTypeViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(tableView)
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = contentView.bounds
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.title = SettingCellItemType.types.titleStr()
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        
    }
    
    // MARK:  GET && SET
    let dataArray = AudioLevelType.allCases
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.view.bounds, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.rowHeight = UITableView.automaticDimension
        view.contentInsetAdjustmentBehavior = .automatic
        view.tableHeaderView = self.headView
        view.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: playingHeight, right: 0)
        view.register(TagsTableViewCell.self, forCellReuseIdentifier: "TagsTableViewCell")
        return view
    }()
    
    lazy var headView: UITableViewHeaderFooterView = {
        var height = 120.ckValue()
        switch kaka_osType() {
        case .iOS: height = 120
        case .iPadOS: height = 150
        case .macOS: height = 150
        }
        
        let view = UITableViewHeaderFooterView(frame: CGRectMake(0, 0, contentView.width, height * 1.5))
        view.backgroundColor = .clear
        let faceImgView = UIImageView(image: UIImage(systemName: "checkmark.seal.fill"))
        faceImgView.contentMode = .scaleAspectFit
        view.contentView.addSubview(faceImgView)
        faceImgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(height)
        }
        return view
    }()
    
}

extension SupportTypeViewController: UITableViewDataSource, UITableViewDelegate, KakaPhotoBrowserDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataArray[section].audioArray().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let audio = self.dataArray[indexPath.section].audioArray()[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "TagsTableViewCell", for: indexPath) as! TagsTableViewCell
        cell.update(audio: audio)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let audio = self.dataArray[indexPath.section].audioArray()[indexPath.row]
        
        if kaka_IsMacOS() { return }
        
        let coverImage = UIImage(named: "\(audio.rawValue)_icon") ?? UIImage(named: "music_place")
        let coverImgView = UIImageView(image: coverImage)
        coverImgView.frame = CGRectMake((self.view.width - 1) / 2, (self.view.height - 1) / 2, 1, 1)
        coverImgView.contentMode = .scaleAspectFit
        coverImgView.tag = 2025
        self.view.addSubview(coverImgView)
        
        let photoItem = KakaPhotoItem(sourceView: coverImgView, image: coverImage)
        let photoBrowser = KakaPhotoBrowser(photoItems: [photoItem], selectedIndex: 0)
        photoBrowser.backgroundStyle = .blurPhoto
        photoBrowser.delegate = self
        photoBrowser.show(from: self)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.dataArray[section].headStr()
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return self.dataArray[section].footStr()
    }
    
    func kaka_photoBrowserDidDismiss(_ browser: KakaPhotoBrowser) {
        self.view.viewWithTag(2025)?.removeFromSuperview()
    }
}

class TagsTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .default
        self.accessoryType = .none
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(audio: AudioExtensionType) {
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.image = UIImage(named: "\(audio.rawValue)_icon") ?? UIImage(named: "music_place")
        cellConfig.text = audio.rawValue.uppercased()
        cellConfig.secondaryText = audio.supportCodecHint
        cellConfig.imageProperties.cornerRadius = 20.ckValue()
        cellConfig.imageProperties.maximumSize = CGSizeMake(40.ckValue(), 40.ckValue())
        cellConfig.imageToTextPadding = 10.ckValue()
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15.ckValue(), leading: 15.ckValue(), bottom: 15.ckValue(), trailing: 15.ckValue())
        self.contentConfiguration = cellConfig
                
        self.accessoryView = self.selectIconView
    }
    
    lazy var selectIconView: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("checkmark.circle.fill", color: .systemGreen))
        view.contentMode = .scaleAspectFit
        view.size = CGSizeMake(22.ckValue(), 22.ckValue())
        return view
    }()
    
}
