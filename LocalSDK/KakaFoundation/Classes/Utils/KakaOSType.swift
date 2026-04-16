//
//  KakaOSType.swift
//  AppGroupKit
//
//  Created by Kaka Inc. on 2023/12/12.
//

import SmartCodable

public enum DeviceOSType: String, SmartCaseDefaultable {
    case iOS = "iOS"
    case iPadOS = "iPad"
    case macOS = "Mac"
    
    public func iconStr() -> String {
        switch self {
        case .iOS:
            return "📱"
        case .iPadOS:
            return "🎛️"
        case .macOS:
            return "💻"
        }
    }
}

public var appKeyWindow: KakaWindow? {
    get {
#if os(OSX)
        return NSApplication.shared.keyWindow
        #else
        if #available(iOS 15.0, *) {
            let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            let window = windowScene?.keyWindow
            window?.windowLevel = .statusBar
            return window ?? UIApplication.shared.keyWindow
        } else {
            let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            let window = windowScene?.windows.first
            window?.windowLevel = .statusBar
            return window ?? UIApplication.shared.keyWindow
        }
        #endif
    }
}

public func kaka_osType() -> DeviceOSType {
#if os(OSX) || targetEnvironment(macCatalyst)
    return .macOS
#else
    return UIDevice.current.userInterfaceIdiom == .phone ? .iOS : .iPadOS
#endif
}

public func kaka_IsiPad() -> Bool {
#if os(OSX) || targetEnvironment(macCatalyst)
    return false
#else
    return UIDevice.current.userInterfaceIdiom == .pad
#endif
}

public func kaka_IsiPhone() -> Bool {
#if os(OSX) || targetEnvironment(macCatalyst)
    return false
    #else
    return UIDevice.current.userInterfaceIdiom == .phone
    #endif
}

public func kaka_IsMacOS() -> Bool {
#if os(OSX) || targetEnvironment(macCatalyst)
    return true
#else
    return false
#endif
}
