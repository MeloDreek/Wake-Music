//
//  LyricAnimationTableCell.swift
//  Mobie
//
//  Created by 张文 on 6/5/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import MorphingLabel

class LyricAnimationTableCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.selectionStyle = .none
        contentView.addSubview(collectionView)
        
        self.timer.startTimer(seconds: 1.5, repeats: true, callSoon: false) { vTimer in
            self.timerCount += 1
            self.collectionView.reloadData()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var animationArray: [MiniLyricAnimation] = MiniLyricAnimation.allCases {
        didSet {
            collectionView.frame = contentView.bounds

            let tapeWidth = kaka_IsiPhone() ? 100.ckValue() : 160.ckValue()
            let tapeHeight = Self.cellHeight - Self.itemSpace * 2
            
            self.flowLayout.itemSize = CGSizeMake(tapeWidth, tapeHeight)
            self.collectionView.reloadData()
        }
    }
    
    /// 间距
    static var itemSpace: CGFloat {
        get {
            switch kaka_osType() {
            case .iOS: return 10.ckValue()
            case .iPadOS: return 18.ckValue()
            case .macOS: return 10.ckValue()
            }
        }
    }
    
    static let cellHeight = kaka_IsiPhone() ? 80.ckValue() : 120.ckValue()
    
    var onClickCallBack: ((MiniLyricAnimation)->Void)?
    
    var timerCount = 0
    var animationTexts = ["Wake", "Apple"]
    
    
    lazy var collectionView: UICollectionView = {
        let view = UICollectionView(frame: self.contentView.bounds, collectionViewLayout: self.flowLayout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.alwaysBounceHorizontal = true
        view.contentInset = UIEdgeInsets(top: Self.itemSpace, left: Self.itemSpace, bottom: Self.itemSpace, right: Self.itemSpace)
        view.contentInsetAdjustmentBehavior = .automatic
        view.semanticContentAttribute = PhoneSetManager.isArabicLanguage() ? .forceRightToLeft : .forceLeftToRight
        view.register(SelectLyricAnimationCell.self, forCellWithReuseIdentifier: "SelectLyricAnimationCell")
        return view
    }()
    
    lazy var flowLayout: BaseCollectionViewFlowLayout = {
        let layout = BaseCollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = Self.itemSpace
        layout.minimumInteritemSpacing = Self.itemSpace
        return layout
    }()
    
    lazy var timer: KakaTimer = {
        return KakaTimer()
    }()
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.animationArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SelectLyricAnimationCell", for: indexPath) as! SelectLyricAnimationCell
        let animation = self.animationArray[indexPath.row]
        let text = self.timerCount % 2 == 0 ? animationTexts[0] : animationTexts[1]
        cell.update(animation: animation, text: text)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let animation = self.animationArray[indexPath.row]
        var newConfig = MusicConfigManager.shared.lyricConfig
        newConfig.miniLyricAnimation = animation
        
        MusicConfigManager.shared.lyricConfig = newConfig
        
        self.collectionView.reloadData()
    }
    
}


class SelectLyricAnimationCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupSubViews()
        self.setupAutoLayout()
        self.setupCusBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubViews() {
        contentView.addSubview(aniLyricLabel)
        contentView.addSubview(normalLabel)
        contentView.addSubview(selectIconBtn)
        contentView.addSubview(randomIconView)
    }
    
    private func setupAutoLayout() {
        
        aniLyricLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        normalLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalToSuperview().multipliedBy(0.4)
        }
        
        selectIconBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-10.ckValue())
            make.top.equalToSuperview().offset(5.ckValue())
            make.size.equalTo(selectIconBtn.size)
        }
        
        randomIconView.snp.makeConstraints { make in
            make.leading.equalTo(10.ckValue())
            make.bottom.equalToSuperview().inset(5.ckValue())
            make.size.equalTo(selectIconBtn)
        }
    }
    
    private func setupCusBuness() {
        contentView.layer.masksToBounds = true
        contentView.layer.cornerRadius = 12.ckValue()
        
        contentView.backgroundColor = UIColor.quaternarySystemFill
    }
    
    // MARK:  GET && SET
    
    func update(animation: MiniLyricAnimation, text: String) {
        if let animationType = animation.animationType() {
            self.aniLyricLabel.morphingEffect = animationType
            self.aniLyricLabel.isHidden = false
            self.normalLabel.isHidden = true
        }else{
            self.aniLyricLabel.isHidden = true
            self.normalLabel.isHidden = false
        }
        
        self.aniLyricLabel.text = text
        self.randomIconView.isHidden = animation != .random
        
        let isSelect = MusicConfigManager.shared.lyricConfig.miniLyricAnimation == animation
        self.selectIconBtn.isSelected = isSelect
    }
    
    // MARK:  懒加载
    lazy var normalLabel: UIImageView = {
        let view = UIImageView(image: Reasource.systemNamed("bolt.slash.fill", color: .label))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var aniLyricLabel: LTMorphingLabel = {
        let view = LTMorphingLabel()
        view.textAlignment = .center
        view.font = UIFontBold(16.ckValue())
        view.numberOfLines = 0
        view.textColor = UIColor.label
        return view
    }()

    lazy var selectIconBtn: UIButton = {
        let view = UIButton(type: .custom)
        view.isUserInteractionEnabled = false
        view.size = CGSizeMake(15.ckValue(), 15.ckValue())
        view.setImage(UIImage(systemName: "circle"), for: .normal)
        view.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        return view
    }()
    
    lazy var randomIconView: UIImageView = {
        let name = "shuffle.circle.fill"
        
        let config = UIImage.SymbolConfiguration(pointSize: 15.ckValue(), weight: .medium)
        let image = Reasource.systemNamed(name, color: .label, config: config).flippedImage()
        let view = UIImageView(image: image)
        view.contentMode = .scaleAspectFit
        return view
    }()
    
}
