//
//  ConnectListViewController+Access.swift
//  Mobie
//
//  Created by 张文 on 10/24/25.
//

import KakaFoundation
import KakaUIKit
import AppGroupKit
import GoogleSignIn
import Alamofire

extension ConnectListViewController {
    // 登录已连接的服务器
    func accessLoginedServer(_ serverModel: ServerConfigModel) {
        
        // 0️⃣Navidrome
        if let navUser = serverModel.navUser {
            let navVC = NavidromeViewController(navUser: navUser)
            self.navigationController?.pushViewController(navVC, animated: true)
        }
        
        // 1️⃣WebDav
        if let webdavUser = serverModel.webdavUser {
            let folderVC = WebdavFileListController(loginModel: webdavUser, files: nil)
            self.navigationController?.pushViewController(folderVC, animated: true)
        }
                
        // 2️⃣百度网盘
        if var baiduUser = serverModel.baiduUser {
            baiduUser.path = nil
            let folderVC = BaiduDriveFileListController(loginModel: baiduUser)
            self.navigationController?.pushViewController(folderVC, animated: true)
        }
        
        // 3️⃣阿里云盘
        if var aliyunUser = serverModel.aliyunUser {
            aliyunUser.parentFolderID = nil
            let folderVC = AliyunDriveFileListController(loginModel: aliyunUser)
            self.navigationController?.pushViewController(folderVC, animated: true)
        }
        
        // 3️⃣115网盘
        if var drive115User = serverModel.drive115User {
            drive115User.cid = nil
            let folderVC = Drive115FileListController(loginModel: drive115User)
            self.navigationController?.pushViewController(folderVC, animated: true)
        }
        
        // 4️⃣谷歌网盘
        if var googleUser = serverModel.googleUser {
            googleUser.folderId = "root"
            let folderVC = GoogleDriveFileListController(loginModel: googleUser)
            self.navigationController?.pushViewController(folderVC, animated: true)
        }
        
        // 5️⃣Dropbox网盘
        if var dropboxUser = serverModel.dropboxUser {
            dropboxUser.path = nil
            let folderVC = DropboxDriveFileListController(loginModel: dropboxUser)
            self.navigationController?.pushViewController(folderVC, animated: true)
        }
        
        /// 6️⃣OneDrive网盘
        if var onedriveUser = serverModel.onedriveUser {
            onedriveUser.path = nil
            let googleVC = OneDriveFileListController(loginModel: onedriveUser)
            self.navigationController?.pushViewController(googleVC, animated: true)
        }
        
    }
}
