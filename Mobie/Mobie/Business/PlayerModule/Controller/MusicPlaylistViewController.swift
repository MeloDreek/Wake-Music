//
//  MusicPlaylistViewController.swift
//  Mobie
//
//  Created by 张文 on 5/12/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import PanModal
import Combine

class MusicPlaylistViewController: SuperViewController {
    override func preSetupSubViews() {
        super.preSetupSubViews()
        contentView.addSubview(titleLabel)
        contentView.addSubview(segmengControl)
        contentView.addSubview(tableView)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
            make.top.equalToSuperview().offset(15.ckValue())
        }
        
        segmengControl.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15.ckValue())
            make.width.equalToSuperview().multipliedBy(0.92)
            make.centerX.equalToSuperview()
            make.height.equalTo(35.ckValue())
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(segmengControl.snp.bottom).offset(15.ckValue())
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    override func preSetupHandleBuness() {
        super.preSetupHandleBuness()
        self.playingMusicChanged()
        
        // 当前音乐模型
        KakaMusicPlayer.shared.$playingMusic
            .receive(on: DispatchQueue.main)
            .sink { [weak self] model in
                self?.playingMusicChanged()
            }.store(in: &cancellables)
        
        // 播放列表
        KakaMusicPlayer.shared.$queueItems
            .receive(on: DispatchQueue.main)
            .sink { [weak self] models in
                self?.musicArray = models
                self?.playingMusicChanged()
            }.store(in: &cancellables)
    }
    
    @objc func playingMusicChanged() {
        self.titleLabel.text = "Playlist".localStr() + " (\(musicArray.count))"
        self.tableView.reloadData()
        if !tableView.isDragging, !tableView.isDecelerating,
           let index = musicArray.firstIndex(where: { $0 == KakaMusicPlayer.shared.playingMusic }) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: false)
        }
    }
    
    @objc func dismissAction() {
        (self.navigationController ?? self).dismiss(animated: true)
    }
    
    // MARK:  GET && SET

    var cancellables = Set<AnyCancellable>()
    
    var musicArray: [MusicItemModel] = KakaMusicPlayer.shared.musicArray
    
    // MARK:  懒加载
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.contentView.bounds, style: .plain)
        view.delegate = self
        view.dataSource = self
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(PlaylistTableViewCell.self, forCellReuseIdentifier: "PlaylistTableViewCell")
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let count = musicArray.count
        let str1 = "Playlist".localStr()
        let str2 = "（\(self.formatNumberStr(count))）"
        let sumStr = str1 + str2
                
        let attbuteStr = NSMutableAttributedString(string: sumStr, attributes: [.font: UIFontBold(18.ckValue()), .foregroundColor: UIColor.label])
        
        let view = UILabel()
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.attributedText = attbuteStr
        return view
    }()
    
    lazy var segmengControl: UISegmentedControl = {
        let orderType = MusicConfigManager.shared.orderType
        let orderTypes: [PlaybackOrderType] = [.normal, .random, .single]
        
        let view = UISegmentedControl(items: ["", "", ""])
        view.selectedSegmentIndex = orderType.rawValue
        view.setImage(orderTypes[0].iconImage(color: appMainColor, config: nil), forSegmentAt: 0)
        view.setImage(orderTypes[1].iconImage(color: appMainColor, config: nil), forSegmentAt: 1)
        view.setImage(orderTypes[2].iconImage(color: appMainColor, config: nil), forSegmentAt: 2)
        view.addTarget(self, action: #selector(segmengControlClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func segmengControlClick(_ sender: UISegmentedControl) {
        let orderType = PlaybackOrderType(rawValue: sender.selectedSegmentIndex) ?? .random
        
        MusicConfigManager.shared.orderType = orderType
    }
    
}

extension MusicPlaylistViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return musicArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlaylistTableViewCell", for: indexPath) as! PlaylistTableViewCell
        let model = musicArray[indexPath.row]
        let isPlaying: Bool = KakaMusicPlayer.shared.playingMusic == model
        cell.update(musicModel: model, isPlaying: isPlaying, index: formatNumberStr(indexPath.row + 1))
        return cell
    }
    
    func formatNumberStr(_ index: Int) -> String {
        let rowNumber: String
        let count = musicArray.count
        if count < 100 {
            // 数据源小于 100，使用两位数格式
            rowNumber = String(format: "%02d", index)
        } else {
            // 数据源大于等于 100，使用三位数格式
            rowNumber = String(format: "%03d", index)
        }
        
        return rowNumber
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard musicArray.indices.contains(indexPath.row),
              let index = KakaMusicPlayer.shared.musicArray.firstIndex(where: { $0.uniqueID() == musicArray[indexPath.row].uniqueID() }) else { return }
        KakaMusicPlayer.shared.playAtIndex(index)
        self.dismissAction()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 55.ckValue()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    
}

//extension MusicPlaylistViewController: PanModalPresentable {
//    var panScrollable: UIScrollView? {
//        return self.tableView
//    }
//
//    var shouldRoundTopCorners: Bool {
//        return true
//    }
//    
//    var longForm: PanModalHeight {
//        return .maxHeight
//    }
//    
//    var orientation: PanModalOrientation {
//        return .vertical
//    }
//    
//    var verticalOffset: CGFloat {
//        return app_navHeight
//    }
//    
//    var horizontalOffset: CGFloat {
//        return 0
//    }
//    
//    var cornerRadius: CGFloat {
//        return 25.ckValue()
//    }
//
//    var anchorModalToLongForm: Bool {
//        return false
//    }
//    
//    var transitionAnimationOptions: UIView.AnimationOptions {
//        return [.allowUserInteraction, .beginFromCurrentState]
//    }
//    
//}
