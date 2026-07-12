//
//  WelcomePurchaseCell.swift
//  Mobie
//
//  Created by 张文 on 10/14/25.
//

import KakaFoundation
import AppGroupKit
import KakaUIKit
import RevenueCat

protocol WelcomePurchaseCellDelegate: AnyObject {
    
    // 进入限制版
    func welcomePurchaseDidLimited(cell: WelcomePurchaseCell)
    
    // 恢复购买
    func welcomePurchaseDidRestore(cell: WelcomePurchaseCell)
}

class WelcomePurchaseCell: UICollectionViewCell, UITableViewDataSource, UITableViewDelegate {
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor.rgb(195, 217, 230) //UIColor.rgb(235, 235, 235)
        self.overrideUserInterfaceStyle = .light
        
        contentView.addSubview(tableView)
        contentView.addSubview(notnowButton)
        contentView.addSubview(restoreButton)
        
        notnowButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(20.ckValue())
            make.top.equalToSuperview().offset(kaka_safeAreaInsets().top + 15.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        restoreButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().inset(18.ckValue())
            make.leading.equalToSuperview().offset(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        tableView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
            make.bottom.equalTo(restoreButton.snp.top).offset(-85.ckValue())
        }
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return benefitArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let maxSize = 32.ckValue()
        let benefits = benefitArray[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "PremiumBenefitsCell", for: indexPath)
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.text = benefits.titleStr()
        cellConfig.image = benefits.iconImage(maxSize)
        cellConfig.secondaryText = benefits.descStr()
        cellConfig.imageProperties.maximumSize = CGSizeMake(maxSize, maxSize)
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
        cellConfig.imageToTextPadding = 15
        
        cell.accessoryType = .none
        cell.contentConfiguration = cellConfig
        cell.contentView.backgroundColor = UIColor.rgb(215, 237, 250)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK:  GET && SET
    
    let lifetimeMsg = "Get lifetime access at the lowest price — unlock all feature on iOS and macOS!".localStr()

    let autosubMsg = "Upgrade to Premium".localStr()
    
    // 付款成功
    weak var delegate: WelcomePurchaseCellDelegate?
    
    lazy var benefitArray: [VIPBenefitsModel] = {
        return VIPBenefitsModel.allCases
    }()
    
    // 内购模型
    var products: [StoreProduct] = [] {
        didSet {
            
            if let firstModel = products.first, let freeTrailDays = firstModel.freeTrialDays {

                let freeTrialStr = String(format: "Free trial for %@ days, then %@/week. Cancel anytime.".localStr(), "\(freeTrailDays)", firstModel.localizedPricePerWeek ?? "??")
                
                let autoRenewAttr = NSAttributedString(
                    string: freeTrialStr,
                    attributes: [.font: UIFontNumber(15.ckValue()),.foregroundColor: UIColor.rgb(102, 99, 116)])
                
                self.headView.descLabel.text = self.autosubMsg
                self.headView.timerLabel.isHidden = true
                self.headView.priceLabel.attributedText = autoRenewAttr
            }else{
                
                let discountModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime198.rawValue }.first
                let lifetimeModel = products.filter { $0.productIdentifier == PurchaseStoreID.lifetime298.rawValue }.first
                
                let lifetimeArray = [discountModel, lifetimeModel].compactMap { $0 }.sorted { product1, product2 in
                    return product1.price < product2.price
                }
                
                let discountPrice = lifetimeArray.first?.localizedPriceString ?? "$24.99"
                let lifetimePrice = lifetimeArray.last?.localizedPriceString ?? "$39.99"
                
                // 创建可变富文本
                let combined = NSMutableAttributedString()

                // 优惠价样式
                let discountAttr = NSAttributedString(
                    string: discountPrice + " ",
                    attributes: [.font: UIFontNumber(22.ckValue()),.foregroundColor: UIColor.rgb(102, 99, 116)])
                combined.append(discountAttr)
                
                // 原价样式（带删除线）
                let lifetimeAttr = NSAttributedString(
                    string: lifetimePrice,
                    attributes: [.font: UIFontNumber(15.ckValue()), .foregroundColor: UIColor.rgb(102, 99, 116), .strikethroughStyle: NSUnderlineStyle.single.rawValue])
                combined.append(lifetimeAttr)
                
                self.headView.descLabel.text = self.lifetimeMsg
                self.headView.timerLabel.isHidden = false
                self.headView.priceLabel.attributedText = combined
                
            }
        }
    }
    
    
    
    // MARK:  懒加载
    lazy var headView: WelcomePurchaseHeadView = {
        let view = WelcomePurchaseHeadView(frame: CGRectMake(0, 0, contentView.width, 320.ckValue()))
        return view
    }()
    
    lazy var tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .insetGrouped)
        view.dataSource = self
        view.delegate = self
        view.backgroundColor = .clear
        view.rowHeight = UITableView.automaticDimension
        view.contentInset = UIEdgeInsets(top: kStatusBarHeight, left: 0, bottom: 60.ckValue(), right: 0)
        view.contentInsetAdjustmentBehavior = .automatic
        view.register(UITableViewCell.self, forCellReuseIdentifier: "PremiumBenefitsCell")
        view.tableHeaderView = self.headView
        return view
    }()
    
    lazy var restoreButton: UIButton = {
        let attbuteStr = NSAttributedString(string: "Restore Purchase".localStr(), attributes: [.font: UIFontLight(13.ckValue()), .foregroundColor: UIColor.gray])
                        
        let view = UIButton()
        view.setAttributedTitle(attbuteStr, for: .normal)
        view.addTarget(self, action: #selector(restoreButtonClick), for: .touchUpInside)
        return view
    }()
    
    @objc func restoreButtonClick() {
        self.delegate?.welcomePurchaseDidRestore(cell: self)
    }
    
    lazy var notnowButton: UIButton = {
        let attbuteStr = NSAttributedString(string: "Not Now".localStr(), attributes: [.font: UIFontLight(12.ckValue()), .foregroundColor: UIColor.gray, .underlineStyle: 1])
        
        let view = UIButton(type: .custom)
        view.setAttributedTitle(attbuteStr, for: .normal)
        view.addTarget(self, action: #selector(notnowButtonClick), for: .touchUpInside)
        return view
    }()
    
    @objc func notnowButtonClick() {
        self.delegate?.welcomePurchaseDidLimited(cell: self)
    }
    
    
    
}

class WelcomePurchaseHeadView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.setupSubViews()
        self.setupContains()
        self.handleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupSubViews() {
        contentView.addSubview(starImgView)
        contentView.addSubview(priceLabel)
        contentView.addSubview(descLabel)
        contentView.addSubview(timerLabel)
    }
    
    func setupContains() {
        starImgView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(155.ckValue())
        }
        
        priceLabel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(starImgView.snp.bottom).offset(30.ckValue())
            make.leading.equalToSuperview().offset(25.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
        
        timerLabel.snp.makeConstraints { make in
            make.bottom.equalTo(priceLabel.snp.top).offset(-5.ckValue())
            make.centerX.equalTo(priceLabel.snp.trailing)
            make.size.greaterThanOrEqualTo(timerLabel.size)
        }
        
        descLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(priceLabel.snp.bottom).offset(30.ckValue())
            make.leading.equalTo(20.ckValue())
            make.height.greaterThanOrEqualTo(0)
        }
    }
    
    func handleBuness() {
        self.backgroundColor = .clear
    }
    
    // MARK: GET && SET
    
    // MARK: 懒加载
    lazy var starImgView: UIImageView = {
        let view = UIImageView(image: Reasource.named("gift_box"))
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    lazy var priceLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.textAlignment = .center
        view.textColor = UIColor.white
        view.font = UIFontBold(22.ckValue())
        return view
    }()
    
    lazy var timerLabel: UILabel = {
        let font = UIFontBold(16.ckValue())
        let fontHeight = font.lineHeight + 10.ckValue()
        let testText = "⏰ 02:59:59"
        let width = testText.width(font) + 20.ckValue()
        
        let view = UILabel(frame: CGRectMake(0, 0, width, fontHeight))
        view.textAlignment = .center
        view.textColor = UIColor.systemRed
        view.font = font
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFontBold(20.ckValue())
        view.textColor = UIColor.rgb(102, 99, 116)
        view.textAlignment = .center
        return view
    }()
    
}
