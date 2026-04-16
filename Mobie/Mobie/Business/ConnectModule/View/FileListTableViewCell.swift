//
//  FileListTableViewCell.swift
//  Mobie
//
//  Created by 张文 on 12/30/24.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import FilesProvider
import NVActivityIndicatorView

class FileListTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.preSetupSubViews()
        self.preSetupContains()
        self.hanldeBessness()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func preSetupSubViews() {
        
        contentView.addSubview(coverImgView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(descLabel)
    }
    
    private func preSetupContains() {
        
        coverImgView.snp.makeConstraints { make in
            make.top.equalTo(12.ckValue())
            make.leading.equalTo(18.ckValue())
            make.size.equalTo(44.ckValue())
            make.centerY.equalToSuperview()
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(coverImgView.snp.trailing).offset(10.ckValue())
            make.trailing.equalToSuperview().offset(-5.ckValue())
            make.height.greaterThanOrEqualTo(nameLabel.font.lineHeight)
            make.centerY.equalTo(coverImgView.snp.centerY).offset(-descLabel.font.lineHeight / 2)
        }
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalTo(nameLabel)
            make.height.greaterThanOrEqualTo(descLabel.font.lineHeight)
            make.top.equalTo(nameLabel.snp.bottom)
        }
        
    }
    
    func hanldeBessness() {
        self.accessoryType = .disclosureIndicator
        self.selectionStyle = .default
        self.tintColor = ColorFontManager.shared.defaultType.color()
    }
    
    var appMainColor: UIColor {
        get {
            if ColorFontManager.shared.accentTyle == .color0 {
                return ColorFontManager.shared.defaultType.color()
            }else{
                return ColorFontManager.shared.accentTyle.color()
            }
        }
    }
    
    /// WebDav文件
    func updateWebDav(fileModel: WebDavFileObject?, serverModel: ServerConfigModel?, isPlaying: Bool) {
        guard let webdavModel = fileModel else { return }
                
        let fileName = webdavModel.name.ocString.deletingPathExtension + ".jpg"
        let coverURL = SandboxFileManager.shared.coverPathURL().appendingPathComponent(fileName)
                
        self.accessoryType = isPlaying ? .none : .disclosureIndicator
        self.accessoryView = isPlaying ? self.loadingView : .none
        
        nameLabel.textColor = isPlaying ? appMainColor : UIColor.label
        descLabel.textColor = isPlaying ? appMainColor : UIColor.label
                
        if webdavModel.url.isSupportMusicFile(false) {
            self.coverImgView.kf.setImage(with: coverURL, placeholder: webdavModel.placeImage())
        }else{
            self.coverImgView.kf.setImage(with: fileModel?.url, placeholder: webdavModel.placeImage())
        }
        
        self.nameLabel.text = webdavModel.name
        self.descLabel.text = self.secondWebdavStr(webdavModel)
    }
    
    private func secondWebdavStr(_ fileModel: WebDavFileObject) -> String {
        let dateStr = fileModel.modifiedDate?.timeString(dateStyle: .medium, timeStyle: .short) ?? ""
        if fileModel.isDirectory {
            return dateStr
        }else{
            return URL.formatFileSize(UInt64(fileModel.size)) + "  " + dateStr
        }
    }

    lazy var coverImgView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 4.ckValue()
        return view
    }()
    
    lazy var nameLabel: UILabel = {
        let view = UILabel()
        view.lineBreakMode = .byTruncatingMiddle
        view.numberOfLines = 1
        view.font = UIFontLight(14.ckValue())
        view.textAlignment = PhoneSetManager.isArabicLanguage() ? .right : .left
        view.textColor = UIColor.label
        return view
    }()
    
    lazy var descLabel: UILabel = {
        let view = UILabel()
        view.lineBreakMode = .byTruncatingMiddle
        view.font = UIFontLight(10.ckValue())
        view.textAlignment = nameLabel.textAlignment
        view.textColor = UIColor.secondaryLabel
        return view
    }()
    
    lazy var loadingView: NVActivityIndicatorView? = {
        let frame = CGRectMake(0, 0, 15.ckValue(), 15.ckValue())
        let view = NVActivityIndicatorView(frame: frame, type: AppLocalManager.shared.playAnimation.nvType(), color: appMainColor)
        view.startAnimating()
        return view
    }()
}
