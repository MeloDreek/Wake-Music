# Xcode 27 构建配置回归

## 已定位的问题

1. `Mobie` / `Mobie_Pro` 都生成 `Wakemusic.app`。Xcode 27 的构建依赖图将两个 target 互相识别为隐式依赖，同时生成相同的可执行文件和内嵌 framework，报 `Multiple commands produce`。
2. Pods targets 显式启用了 `ENABLE_MODULE_VERIFIER`。独立模块验证拒绝 CocoaPods umbrella header 和部分依赖公开头文件中的双引号 import，例如 GoogleUtilities / KakaTaglibKit。
3. 工程启用了 `STRING_CATALOG_GENERATE_SYMBOLS`，`Localizable.xcstrings` 中的 `Protocol` 文案键导致生成 Swift 符号时触发保留字错误。

## 修复范围

- Pro 的构建产物改为 `WakemusicPro.app`，同步 Products 引用和 scheme 的 Build/Run/Profile 引用；普通版仍为 `Wakemusic.app`。
- Pro 显式保留 `PRODUCT_MODULE_NAME = Wakemusic`，避免影响 Swift 类名、Storyboard/Core Data 中的类型引用。两个版本 Bundle ID、显示名称和版本号均未修改。
- 仅在 Pods 工程及 targets 关闭独立框架模块验证，正常编译、模块导入与链接检查保持启用。`Podfile` post_install 同步保存此设置，避免重新生成 Pods 工程后复发。没有升级依赖或手改第三方源码。
- 关闭未被项目使用的本地化 Swift 符号生成；现有 `localStr()` 和 String Catalog 的资源编译保持不变，不重命名文案键、不删除翻译。

模块验证的含义见 [Apple 文档](https://developer.apple.com/documentation/xcode/identifying-and-addressing-framework-module-issues)。后续升级 CocoaPods/依赖后可重新评估开启；该设置不是 Swift 显式模块开关。

## 静态回归

```sh
ruby Tests/BuildConfiguration/check-xcode27.rb
```

检查两个版本的 Debug/Release 产物名、Bundle ID、Swift 模块名、scheme 引用及 Pods 配置，不能代替实际编译与运行验证。

2026-09-16 验证结果（Xcode 27.0 / 27A266a）：

- `Mobie`、`Mobie_Pro`，Debug / iOS Simulator / arm64 均 `BUILD SUCCEEDED`。
- 两版安装到 iPhone 18 Pro Max / iOS 27.0 模拟器并通过 `simctl launch` 启动；随后 `launchctl list` 确认两个应用进程仍存活。未进行界面交互或完整业务回归。
- 静态配置回归 19 项通过，`Podfile` Ruby 语法、两个 pbxproj 格式及 `git diff --check` 通过。
- 没有验证真机签名、Release Archive 或 Mac Catalyst 构建。
- 本轮仍有 YandexLoginSDK 的 `PrivacyInfo.xcprivacy` 处理规则警告，未阻断构建；未在本次兼容修复中扩大修改范围。

## 本机命令行注意事项

检查时 `xcode-select -p` 仍指向 `/Library/Developer/CommandLineTools`，直接运行 `xcodebuild` 会报错。构建验证使用进程级 `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`，未更改系统全局设置。也可在 Xcode Settings → Locations → Command Line Tools 中选择 Xcode 27。
