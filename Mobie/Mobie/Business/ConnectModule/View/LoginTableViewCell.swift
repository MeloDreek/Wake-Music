//
//  LoginTableViewCell.swift
//  Mobie
//
//  Created by 张文 on 12/29/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit

protocol LoginTableViewCellDelegate: AnyObject {
    // 编辑内容的回调
    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, content: String)
    
    // 开关回调
    func loginViewCellDidEndEditing(cell: LoginTableViewCell, itemType: LoginGroupItemType, isEnable: Bool)
    
    // 通信协议
    func loginViewCellDidNetProtocol(cell: LoginTableViewCell, netProtocol: NetworkProtocol)
}

class LoginTableViewCell: UITableViewCell, UITextFieldDelegate {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func preSetupSubViews() {
        
    }
    
    func preSetupContains() {
        
    }
    
    func preSetupHandleBuness() {
        
    }
    
    // MARK:  GET && SET
    let titleFont = UIFontLight(14.ckValue())
    
    weak var delegate: LoginTableViewCellDelegate?
    
    var itemType = LoginGroupItemType.host
    
    func update(itemType: LoginGroupItemType, model: ServerConfigModel) {
        
        self.itemType = itemType
        var cellConfig = UIListContentConfiguration.cell()
        cellConfig.text = itemType.titleStr(model.serverType)
        cellConfig.textProperties.font = titleFont
        cellConfig.prefersSideBySideTextAndSecondaryText = true
        cellConfig.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15)
                
        switch itemType {
        case .title:
            self.textField.keyboardType = .default
            self.textField.text = model.customNameStr()
            self.accessoryView = self.textField
        case .httpOption:
            let index = self.networkProtocols.firstIndex { model.networkProtocol()?.rawValue.lowercased() == $0 }
            self.segmengControl.selectedSegmentIndex = index ?? 0
            self.accessoryView = self.segmengControl
        case .host:
            self.textField.keyboardType = .URL
            self.textField.text = model.hostURLStr()
            self.accessoryView = self.textField
        case .path:
            self.textField.keyboardType = .default
            self.textField.text = model.pathStr()
            self.accessoryView = self.textField
        case .port:
            self.textField.keyboardType = .numberPad
            self.textField.text = model.portStr()
            self.accessoryView = self.textField
        case .serverType:
            self.switchView.isOn = model.navUser?.isLargeServer ?? true
            self.accessoryView = self.switchView
            
        case .username:
            self.textField.textContentType = .username
            self.textField.keyboardType = .default
            self.textField.text = model.usernameStr()
            self.accessoryView = self.textField
        case .password:
            self.textField.isSecureTextEntry = !self.visbleButton.isSelected
            self.textField.rightView = self.passwordView
            self.textField.rightViewMode = .always
            self.textField.textContentType = .password
            self.textField.keyboardType = .default
            self.textField.text = model.passwordStr()
            self.accessoryView = self.textField
        case .cusButton:
            self.backgroundColor = appMainColor
            cellConfig.textProperties.color = UIColor.deAccent
            cellConfig.text = "Connect".localStr()
            cellConfig.textProperties.alignment = .center
            cellConfig.textProperties.font = UIFontBold(15.ckValue())
            self.selectionStyle = .none
        default:
            break
        }
        
        self.textField.placeholder = itemType.placeHolder(model.serverType)
        self.contentConfiguration = cellConfig
    }
    
    func maxTitleWidth() -> CGFloat {
        let titles: [LoginGroupItemType] = [.host, .httpOption, .password, .path, .port, .username, .title]
        let titleArray = titles.map { $0.titleStr(.fromWebDAV) }
        
        // 使用 map 提取每个标题的宽度
        let widths = titleArray.map { $0.width(titleFont) }
        
        // 获取最大的宽度
        let maxWidth = widths.max() ?? 0
        
        return maxWidth + 55.ckValue()
    }
    
    // MARK:  懒加载
    
    let networkProtocols = [NetworkProtocol.http.rawValue.uppercased(), NetworkProtocol.https.rawValue.uppercased()]
    
    lazy var textField: UITextField = {
        let view = UITextField(frame: CGRectMake(0, 0, self.bounds.width - self.maxTitleWidth(), 30.ckValue()))
        view.delegate = self
        view.clearButtonMode = .whileEditing
        view.textColor = .label
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.font = UIFontLight(15.ckValue())
        return view
    }()
    
    lazy var segmengControl: UISegmentedControl = {
        let titleFont = UIFontLight(14.ckValue())
        let maxWidth = networkProtocols.joined(separator: " ").width(titleFont) + 60.ckValue()
        
        let view = UISegmentedControl(items: networkProtocols)
        view.frame = CGRectMake(0, 0, maxWidth, 32.ckValue())
        view.setTitleTextAttributes([.font: titleFont], for: .normal)
        view.addTarget(self, action: #selector(segmengControlClick(_:)), for: .valueChanged)
        return view
    }()
    
    lazy var visbleButton: UIButton = {
        let seeBtn = UIButton(type: .custom)
        seeBtn.isSelected = false
        seeBtn.frame = CGRectMake(7.5.ckValue(), 2.5.ckValue(), 25.ckValue(), 25.ckValue())
        seeBtn.setImage(Reasource.systemNamed("eye.slash"), for: .normal)
        seeBtn.setImage(Reasource.systemNamed("eye"), for: .selected)
        seeBtn.addTarget(self, action: #selector(seeBtnClick(_:)), for: .touchUpInside)
        return seeBtn
    }()
    
    lazy var passwordView: UIView = {
        let view = UIView(frame: CGRectMake(0, 0, 40.ckValue(), 30.ckValue()))
        view.backgroundColor = .clear
        view.addSubview(self.visbleButton)
        return view
    }()
    
    lazy var switchView: UISwitch = {
        let view = UISwitch(frame: CGRectMake(0, 0, 40.ckValue(), 40.ckValue()))
        view.isOn = true
        view.addTarget(self, action: #selector(switchViewChanged(_:)), for: .valueChanged)
        return view
    }()
    
    @objc func seeBtnClick(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        self.textField.isSecureTextEntry = !sender.isSelected
    }
    
    @objc func segmengControlClick(_ sender: UISegmentedControl) {
        let protocolStr = self.networkProtocols[sender.selectedSegmentIndex].lowercased()
        self.delegate?.loginViewCellDidNetProtocol(cell: self, netProtocol: NetworkProtocol(rawValue: protocolStr) ?? .http)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // 处理文本框编辑结束时的回调
        let content = textField.text ?? ""
        self.delegate?.loginViewCellDidEndEditing(cell: self, itemType: self.itemType, content: content)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 如果你想实时监听文本的变化，可以在这里做处理
        let newText = (textField.text! as NSString).replacingCharacters(in: range, with: string)
        self.delegate?.loginViewCellDidEndEditing(cell: self, itemType: self.itemType, content: newText)
        return true
    }
    
    @objc func switchViewChanged(_ sender: UISwitch) {
        self.delegate?.loginViewCellDidEndEditing(cell: self, itemType: self.itemType, isEnable: sender.isOn)
    }
}
