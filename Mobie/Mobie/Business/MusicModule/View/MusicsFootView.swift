//
//  MusicsFootView.swift
//  Mobie
//
//  Created by 张文 on 9/28/24.
//

import KakaFoundation
import AppGroupKit

class MusicsFootView: UITableViewHeaderFooterView {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.preSetupHandleBuness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        contentView.addSubview(usedLabel)
        contentView.addSubview(unusedButton)
    }
    
    private func preSetupContains() {
        usedLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(8.ckValue())
            make.size.greaterThanOrEqualTo(0)
        }
        
        unusedButton.snp.makeConstraints { make in
            make.top.equalTo(usedLabel.snp.bottom).offset(5.ckValue())
            make.leading.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.greaterThanOrEqualTo(0)
        }
    }
    
    
    private func preSetupHandleBuness() {
        self.backgroundColor = .clear
    }
    
    func update(_ musicURL: URL) {
        
        let isBaseURL = musicURL == SandboxFileManager.shared.basePublicFileURL()
        let cacheArray = isBaseURL ? AppLocalManager.shared.refreshCachePaths() : []
        
        let totalURLs = SandboxFileManager.shared.getAllSubFiles(musicURL) + cacheArray
        let unUsedURLs = totalURLs.filter { !$0.isSupportMusicFile(true) }
        let totalCount = totalURLs.count
        let fileSize = musicURL.totalFileSize()
        
        let useStr = String(format: "%d Files Imported".localStr(), totalCount) + "\r" + URL.formatFileSize(Int64(fileSize))
        usedLabel.text = useStr
        
        self.usedLabel.isHidden = fileSize == 0
        self.unusedButton.isHidden = unUsedURLs.count == 0
        self.unSupportURLs = unUsedURLs
        
        let message = "Unsupported Files".localStr() + "(\(unUsedURLs.count))"
        let attbuteStr = NSAttributedString(string: message, attributes: [.font: UIFontLight(14.ckValue()), .foregroundColor: appMainColor, .underlineStyle: 1])
        unusedButton.setAttributedTitle(attbuteStr, for: .normal)
    }
    
    // MARK:  GET && SET
    var onCallback: (([URL])->Void)?
    
    var unSupportURLs: [URL] = []
    
    // MARK:  懒加载
    lazy var usedLabel: UILabel = {
        let view = UILabel()
        view.numberOfLines = 0
        view.font = UIFontBold(14.ckValue())
        view.textAlignment = .center
        view.textColor = .secondaryLabel
        return view
    }()
    
    lazy var unusedButton: UIButton = {
        let view = UIButton(type: .custom)
        view.addTarget(self, action: #selector(unusedButtonClick), for: .touchUpInside)
        return view
    }()
    
    @objc func unusedButtonClick() {
        self.onCallback?(self.unSupportURLs)
    }
}
