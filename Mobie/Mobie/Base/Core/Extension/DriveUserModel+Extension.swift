//
//  DriveUserModel+Extension.swift
//  Mobie
//
//  Created by 张文 on 10/26/25.
//

import AppGroupKit
import GoogleSignIn
import SwiftyDropbox
import AliyunpanSDK

extension GIDGoogleUser {
    
    /// 转化成自定义的网盘用户
    func convertDriveUser() -> GoogleDriveUserModel {
        let googleUser = GoogleDriveUserModel(userID: self.userID, nickName: self.profile?.name, avatarPic: self.profile?.imageURL(withDimension: 300)?.absoluteString, email: self.profile?.email, requestTime: Date().timeIntervalSince1970, accessToken: self.accessToken.tokenString, refreshToken: self.refreshToken.tokenString, expiresTime: self.accessToken.expirationDate?.timeIntervalSince1970 ?? 0)

        return googleUser
    }
    
}

#if canImport(MSAL)
import MSAL

extension MSALResult {
    
    /// 转化为自定义模型
    func convertOneDriveUser() -> OneDriveUserModel {
        let msalID = self.account.identifier ?? ""
        let username = self.account.username ?? ""
        let homeAccountID = self.account.homeAccountId?.identifier ?? ""
        let accountClaims = self.account.accountClaims?.description ?? ""
        
        let oneAccount = OnedriveAccount(msalID: msalID, homeAccountId: homeAccountID, username: username, environment: self.account.environment, accountClaims: accountClaims)
        
        let onedriveUser = OneDriveUserModel(requestTime: Date().timeIntervalSince1970, accessToken: self.accessToken, expiresTime: self.expiresOn?.timeIntervalSince1970 ?? 0, authHeader: self.authorizationHeader, authScheme: self.authenticationScheme, account: oneAccount, path: nil)
        
        return onedriveUser
    }
    
}
#endif

extension Files.FolderMetadata {
    func convertDropboxFolder() -> DropboxDriveFileModel {
        let model = DropboxDriveFileModel(fileType: .folder, name: self.name, id: self.id, path_display: self.pathDisplay, path_lower: self.pathLower, size: nil, is_downloadable: false, client_modified: nil, server_modified: nil, dropboxUser: nil)
        
        return model
    }
}

extension Files.FileMetadata {
    func convertDropboxFile() -> DropboxDriveFileModel {
        let model = DropboxDriveFileModel(fileType: .file, name: self.name, id: self.id, path_display: self.pathDisplay, path_lower: self.pathLower, size: Int64(self.size), is_downloadable: self.isDownloadable, client_modified: self.clientModified.timeIntervalSince1970, server_modified: self.serverModified.timeIntervalSince1970, dropboxUser: nil)
        
        return model
    }
}

extension Files.Metadata {
    func convertDropboxBase() -> DropboxDriveFileModel {
        let model = DropboxDriveFileModel(fileType: .other, name: self.name, id: nil, path_display: self.pathDisplay, path_lower: self.pathLower, size: nil, is_downloadable: false, client_modified: nil, server_modified: nil, dropboxUser: nil)
        
        return model
    }
}

extension AliyunpanFile {
    /// 转换器：将 SDK 模型映射到你的自定义模型
    func convertAliyunFile(_ driveId: String) -> AliyunpanFileModel {
        var model = AliyunpanFileModel()
        model.drive_id = driveId
        model.file_id = self.file_id
        model.parent_file_id = self.parent_file_id
        model.name = self.name
        model.size = self.size
        model.file_extension = self.file_extension
        model.content_hash = self.content_hash
        model.category = self.category?.rawValue
        model.type = self.type?.rawValue
        model.thumbnail = self.thumbnail?.absoluteString
        model.url = self.url?.absoluteString
        model.created_at = self.created_at?.timeIntervalSince1970
        model.updated_at = self.updated_at?.timeIntervalSince1970
        return model
    }
}
