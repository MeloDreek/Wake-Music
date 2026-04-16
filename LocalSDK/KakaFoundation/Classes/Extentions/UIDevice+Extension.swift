//
//  UIDevice+Extension.swift
//  Pods
//
//  Created by 张文 on 4/13/25.
//

import Foundation

extension UIDevice {
    // 设备是否越狱
    public func isJailBreak() -> Bool {
#if targetEnvironment(simulator)
        return false
#else
        return self.isJailBreak1() || self.isJailBreak2() || self.isJailBreak3() || self.isJailBreak4()
#endif
    }
    
    /// 随意调用系统 API
    private func isJailBreak1() -> Bool {
        let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
        let forkPtr = dlsym(RTLD_DEFAULT, "fork")
        typealias ForkType = @convention(c) () -> Int32
        let fork = unsafeBitCast(forkPtr, to: ForkType.self)
        let forkIndex = fork()
        return forkIndex != -1
    }
    
    // 越狱之后所有 App 都被授予 root 权限，并且可以修改沙箱之外的文件
    private func isJailBreak2() -> Bool {
        let string = "test29108"
        
        do {
            try string.write(to: URL(fileURLWithPath: "/private/test29108.txt"), atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }
    
    // 检查手机上是否安装了 Cydia
    private func isJailBreak3() -> Bool {
        return UIApplication.shared.canOpenURL(URL(string: "cydia://")!)
    }
    
    // 如果越狱的话，设备会创建许多文件，可以使用 FileManager 来检测这些文件是否存在
    private func isJailBreak4() -> Bool {
        let files = [
                "/private/var/lib/apt",
                "/Applications/Cydia.app",
                "/Applications/RockApp.app",
                "/Applications/Icy.app",
                "/Applications/WinterBoard.app",
                "/Applications/SBSetttings.app",
                "/Applications/blackra1n.app",
                "/Applications/IntelliScreen.app",
                "/Applications/Snoop-itConfig.app",
                "/bin/sh",
                "/usr/libexec/sftp-server",
                "/usr/libexec/ssh-keysign /Library/MobileSubstrate/MobileSubstrate.dylib",
                "/bin/bash",
                "/usr/sbin/sshd",
                "/etc/apt /System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
                "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
                "/Library/MobileSubstrate/DynamicLibraries/LiveClock.plist",
                "/Library/MobileSubstrate/DynamicLibraries/Veency.plist"
            ]
        return files.contains(where: { return FileManager.default.fileExists(atPath: $0) })
    }

}
