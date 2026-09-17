# iOS 16 最低版本检查

## 本次修改

- `Mobie` / `Mobie_Pro` 与工程级 Debug/Release 的 deployment target 统一为 16.0；Podfile 和已生成的 Pods 工程原本已是 16.0。
- 移除 App 内 58 处 iOS 16.0 及以前的冗余 availability 分支，保留 iOS 16.1/17/18/26 的必要判断。共享 LocalSDK 自身仍声明更早系统最低版本，因此不删除这些库的兼容分支，也不改变原生 macOS 最低要求。
- 两个歌词旋转图标在 iOS 16 使用 `rotate.left` / `rotate.right`，iOS 17+ 继续使用矩形旋转图标。
- SMB 编辑凭证图标更正为存在且支持 iOS 16 的 `person.badge.key`。
- SMB 连接清理的 Task 显式丢弃 `removeValue` 结果，避免将 `NWConnection` 推断为 Task 的返回值，从而依赖 iOS 17 才有的 Sendable conformance。

## 静态检查

```sh
ruby Tests/iOS16/check-compatibility.rb
ruby Tests/MusicServer/check-navigation.rb
ruby Tests/BuildConfiguration/check-xcode27.rb
```

图标检查读取本机 Apple SF Symbols 的 `name_availability.plist`，也可用 `SF_SYMBOL_METADATA` 环境变量指定路径。它检查直接调用中的错误符号名，以及源代码字符串中的已知新图标是否位于相应的 availability 真分支。它不替代动态生成符号名的运行检查，也不替代 SDK API 编译检查。

2026-09-17：496 处已知图标字面量通过，9 处晚于 iOS 16 的图标都有保护；导航源码约束 12 项、构建配置 19 项通过。

## 构建与运行验证

- Xcode 27：`Mobie`、`Mobie_Pro` Debug / arm64 / iOS Simulator，以及 `Mobie` Debug / arm64 / Mac Catalyst 均构建通过。没有给构建命令额外覆盖 deployment target。
- 普通版构建产物的 59 个 Mach-O 二进制检查：15 个不被动态引用的静态 framework 资源桩单独排除，实际引用的二进制没有要求高于 iOS 16 的最低版本。
- 音乐服务器数据 54 项、账号身份/持久化、本地化 4302 项、播放队列 7297 项、SMB 53 项回归通过。
- iOS 26.5 模拟器：两个已保存 Navidrome 账号多次交替进入/退出成功；页面加载中与加载完成后退出均可再次进入；中文/阿拉伯语退出图标分别朝左/右；重启恢复选中账号。测试后恢复默认中文。

Navidrome 切换锁原本在 CATransaction completion 中释放，而 root 初始化可能启动无限重复动画，导致 completion 无法按预期释放锁。现改为 root 替换结束时通过 defer 释放，与 cube 动画生命周期解耦。镜像后的 SF Symbol 先绘制成 template 图像，避免 UIBarButtonItem 重配 symbol 时丢失 UIImage orientation，再交由 UIKit 处理 RTL。

限制：本机只有 iOS 26.5/27 模拟器，尚未在 iOS 16 设备实际运行；未验证 Release Archive / 真机签名。仍有既存的 YandexLoginSDK PrivacyInfo.xcprivacy 构建规则警告，不影响上述构建。
