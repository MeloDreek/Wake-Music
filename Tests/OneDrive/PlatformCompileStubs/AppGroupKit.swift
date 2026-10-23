// Compile-only business-model stand-ins. Never linked into an app or executed.
// UIKit, AuthenticationServices, Security, Foundation and CryptoKit remain real SDK modules.
import Foundation

public let OneDrive_ClientID = "compile-only-fixture"
public let OneDrive_RedirectUri = "msauth.example.invalid://auth"

public struct OnedriveAccount {
    public var msalID: String
    public var homeAccountId: String?
    public var graphUserID: String?
    public init(msalID: String, homeAccountId: String?, username: String?, nickName: String?, environment: String, accountClaims: String) {
        self.msalID = msalID
        self.homeAccountId = homeAccountId
    }
}
public struct OneDriveUserModel {
    public var account: OnedriveAccount?
    public var path: String?
    public init() {}
}
public enum ImportFileType { case fromOneDrive }
public struct ServerConfigModel {
    public var onedriveUser: OneDriveUserModel?
    public init(serverType: ImportFileType, isSelected: Bool, onedriveUser: OneDriveUserModel) {
        self.onedriveUser = onedriveUser
    }
}
public final class ConnectConfigManager {
    public static let shared = ConnectConfigManager()
    public var connectedModels: [ServerConfigModel] = []
    public func addOrUpdateRemoteServer(serverModel: ServerConfigModel, completion: () -> Void) { completion() }
}
