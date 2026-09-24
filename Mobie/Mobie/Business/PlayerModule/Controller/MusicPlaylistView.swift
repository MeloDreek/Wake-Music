//
//  MusicPlaylistView.swift
//  Mobie
//
//  Created by 张文 on 1/15/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import NVActivityIndicatorView
import Combine
import DominantColors
import WaketagLibKit

class MusicPlaylistView: UIView {
    
    deinit {
        debugPrint("### MusicPlaylistView ###")
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.preSetupSubViews()
        self.layoutSubFrames()
        self.preSetupHandleBuness()
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        self.addSubview(mengControl)
        self.addSubview(contentView)
        contentView.addSubview(gradientView)
        contentView.addSubview(grayView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(segmengControl)
        contentView.addSubview(tableView)
        contentView.addSubview(lineView)
        contentView.addSubview(cancelButton)
    }
    
    private func layoutSubFrames() {
        mengControl.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        grayView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(10.ckValue())
            make.width.equalTo(40.ckValue())
            make.height.equalTo(kaka_IsiPhone() ? grayView.layer.cornerRadius * 2 : 0)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
            make.top.equalTo(grayView.snp.bottom).offset(15.ckValue())
        }
        
        segmengControl.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(15.ckValue())
            make.width.equalToSuperview().multipliedBy(0.92)
            make.centerX.equalToSuperview()
            make.height.equalTo(35.ckValue())
        }
        
        lineView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().inset(kaka_safeAreaInsets().bottom + 50.ckValue())
            make.height.equalTo(0.3.ckValue())
        }
        
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(lineView.snp.bottom).offset(10.ckValue())
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(30.ckValue())
        }
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(segmengControl.snp.bottom).offset(15.ckValue())
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(lineView.snp.top)
        }
        
    }
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
        self.overrideUserInterfaceStyle = .dark
        
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
        
        if kaka_IsiPhone() {
            self.perform(#selector(showAnimation), with: nil, afterDelay: 0.1)
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGestureEvent(_:)))
            self.contentView.addGestureRecognizer(panGesture)
        }
        
    }
    
    // 当前音乐模型变化了
    @objc func playingMusicChanged() {
        self.titleLabel.text = "Playlist".localStr() + " (\(musicArray.count))"
                        
        self.tableView.reloadData()
        if !tableView.isDragging, !tableView.isDecelerating,
           let index = musicArray.firstIndex(where: { $0 == KakaMusicPlayer.shared.playingMusic }) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: false)
        }
    }
    
    @objc func panGestureEvent(_ gestureRecognizer: UIPanGestureRecognizer) {
        let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
        let locationPoint = gestureRecognizer.location(in: gestureRecognizer.view)
        
        if locationPoint.y < self.height - self.contentHeight && gestureRecognizer.state == .began {
            return
        }
        
        if translation.y <= 0 {
            contentView.top = self.height - self.contentHeight
            return
        }
        
        contentView.top = self.height - self.contentHeight + translation.y
        
        if gestureRecognizer.state == .ended {
            self.duration = 0.1
            if translation.y > (contentView.height / 3) {
                self.dismissAction()
            }else{
                self.showAnimation()
            }
        }
    }
    
    @objc func showAnimation() {
        UIView.animate(withDuration: duration) { [weak self] () in
            guard let wSelf = self else { return }
            wSelf.contentView.top = wSelf.height - wSelf.contentHeight
            wSelf.layoutIfNeeded()
            wSelf.setNeedsLayout()
        } completion: { [weak self] finish in
            self?.duration = 0.3
        }

    }
    
    @objc func dismissAction() {
        UIView.animate(withDuration: self.duration) { [weak self] () in
            guard let wSelf = self else { return }
            wSelf.contentView.top = wSelf.height
            wSelf.layoutIfNeeded()
            wSelf.setNeedsLayout()
        } completion: { [weak self] finish in
            guard let wSelf = self else { return }
            wSelf.removeFromSuperview()
            wSelf.duration = 0.3
        }
    }
    
    // MARK:  GET && SET
    
    var cancellables = Set<AnyCancellable>()
        
    var musicArray: [MusicItemModel] = KakaMusicPlayer.shared.musicArray
        
    private var duration: TimeInterval = 0.3
    
    var contentHeight: CGFloat {
        get {
            return kaka_IsiPhone() ? self.height * 0.85 : self.height
        }
    }
    
    // MARK:  懒加载
    lazy var mengControl: UIControl = {
        let view = UIControl(frame: self.bounds)
        view.isHidden = kaka_IsMacOS()
        view.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
        return view
    }()
    
    lazy var contentView: UIImageView = {
        let view = UIImageView()
        view.frame = CGRectMake(0, kaka_IsiPhone() ? self.height : 0, self.width, contentHeight)
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.isUserInteractionEnabled = true
        if kaka_IsiPhone() {
            view.corner(byRoundingCorners: [.topLeft, .topRight], radii: 25.ckValue())
        }
        return view
    }()
    
//    lazy var effectView: UIVisualEffectView = {
//        let blurEffect = UIBlurEffect(style: .systemMaterialDark)
//        let view = UIVisualEffectView(effect: blurEffect)
//        view.frame = self.bounds
//        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        return view
//    }()
    lazy var gradientView: KakaGradientView = {
        let newColors: [CGColor] = [UIColor.rgb(55, 55, 88).cgColor, UIColor.rgb(33, 33, 55).cgColor]
        let view = KakaGradientView(frame: self.bounds)
        view.gradientColors = newColors
        view.startPoint = CGPoint(x: 0, y: 0)
        view.endPoint = CGPoint(x: 0, y: 1) // 水平渐变
        return view
    }()
    
    lazy var grayView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemFill.withAlphaComponent(0.5)
        view.layer.masksToBounds = true
        view.layer.cornerRadius = 2.ckValue()
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
    
    lazy var cancelButton: UIButton = {
        let view = UIButton(type: .custom)
        view.setTitle("Cancel".localStr(), for: .normal)
        view.addTarget(self, action: #selector(dismissAction), for: .touchUpInside)
        view.titleLabel?.font = UIFontLight(15.ckValue())
        view.setTitleColor(.label, for: .normal)
        return view
    }()
    
    lazy var lineView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.separator.withAlphaComponent(0.5)
        return view
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: self.bounds, style: .plain)
        view.delegate = self
        view.dataSource = self
        view.overrideUserInterfaceStyle = .dark
        view.backgroundColor = .clear
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(PlaylistTableViewCell.self, forCellReuseIdentifier: "PlaylistTableViewCell")
        return view
    }()
    
    lazy var segmengControl: UISegmentedControl = {
        let orderType = MusicConfigManager.shared.orderType
        let orderTypes: [PlaybackOrderType] = [.normal, .random, .single]
        
        let view = UISegmentedControl(items: ["", "", ""])
        view.selectedSegmentIndex = orderType.rawValue
        view.setImage(orderTypes[0].iconImage(color: .label, config: nil), forSegmentAt: 0)
        view.setImage(orderTypes[1].iconImage(color: .label, config: nil), forSegmentAt: 1)
        view.setImage(orderTypes[2].iconImage(color: .label, config: nil), forSegmentAt: 2)
        view.addTarget(self, action: #selector(segmengControlClick(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func segmengControlClick(_ sender: UISegmentedControl) {
        let orderType = PlaybackOrderType(rawValue: sender.selectedSegmentIndex) ?? .random
        
        MusicConfigManager.shared.orderType = orderType
    }
    
}

extension MusicPlaylistView: UITableViewDataSource, UITableViewDelegate {
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

class PlaylistTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK:  GET && SET
    private(set) var isPlaying: Bool = false
    
    var appMainColor: UIColor {
        get {
            if ColorFontManager.shared.accentTyle == .color0 {
                return ColorFontManager.shared.defaultType.color()
            }else{
                return ColorFontManager.shared.accentTyle.color()
            }
        }
    }
    
    func update(musicModel: MusicItemModel, isPlaying: Bool, index: String) {
        
        self.isPlaying = isPlaying
        let isPause = KakaMusicPlayer.shared.playbackStatus == .paused

        self.accessoryView = (isPlaying && !isPause) ? self.loadingView : nil
        self.accessoryType = (isPlaying && !isPause) ? .none : .disclosureIndicator
                                
        let musicName = "\(index)  -  " + musicModel.showTitleName()
        let singerName = " " + musicModel.showArtistName()
        
        let attbuteStr = NSMutableAttributedString()
        let highlightColor = appMainColor
        attbuteStr.append(NSAttributedString(string: musicName, attributes: [.font: UIFontBold(13.ckValue()), .foregroundColor: isPlaying ? highlightColor : UIColor.label]))
        attbuteStr.append(NSAttributedString(string: singerName, attributes: [.font: UIFontLight(10.ckValue()), .foregroundColor: isPlaying ? highlightColor : UIColor.secondaryLabel]))
        
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.attributedText = attbuteStr
        
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
        
        self.contentConfiguration = cellConfig
    }
    
    // MARK:  懒加载
    lazy var loadingView: NVActivityIndicatorView = {
        let highlightColor = appMainColor

        let frame = CGRectMake(0, 0, 15.ckValue(), 15.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: highlightColor)
        view.startAnimating()
        return view
    }()
    
}
