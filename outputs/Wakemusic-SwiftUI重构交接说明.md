# Wakemusic SwiftUI 重构交接说明

日期：2026-09-12。本文是重构起步约定；最低系统版本、数据库方案和首版完整功能范围尚待确定。

## 目标与范围

以 SwiftUI 重构维克音乐，从一开始支持 iOS/iPadOS、原生 macOS、tvOS；iOS 集成 CarPlay；iOS 和 macOS 提供桌面小组件。watchOS 单独建 project，首版仅做手表本地音频的基础播放，以 AVPlayer 做轻量封装。

共用业务逻辑，各平台保留适合自己的交互。SwiftUI 不要求所有代码都脱离 UIKit/AppKit，也不要求搭配 SwiftData。

## 新建工程选项

| 选项 | 当前建议 | 原因 |
| --- | --- | --- |
| Testing System | Swift Testing with XCTest UI Tests | 新的 Swift 单元测试采用 Swift Testing，界面自动化采用 XCTest。已有 XCTest 可继续使用。 |
| Storage | None | 暂不注入模板的数据模型与容器，等旧版数据迁移和平台需求明确后再接入持久化。不是禁止保存数据。 |
| Host in CloudKit | 暂不启用 | 跨平台支持与跨设备数据同步是不同需求，需单独设计同步范围与冲突处理。 |

Storage 是工程模板选项，并非不可更改的架构决定。SwiftData、Core Data 或其他数据库都可以后续手动加入；不要为了改选项反复重建工程。最低系统版本确定后，再结合曲库规模、查询、并发扫描、迁移和扩展共享选择数据库。

## 工程组织

```text
Wakemusic.xcworkspace
├── Wakemusic.xcodeproj
│   ├── iOS / 原生 macOS / tvOS 应用
│   ├── CarPlay 集成代码（属于 iOS）
│   └── iOS / macOS Widget Extension target(s)
├── WakemusicWatch.xcodeproj
│   └── watchOS 应用
└── Packages/WakemusicCore（本地 Swift Package，两边共同依赖）
```

这是建议目录，不是已经创建的工程。主应用可以使用一个 multiplatform target；平台设置分歧较大时，也可以在同一个 project 内拆成多个 target。两种方式都符合上述两个 project 的安排。

- **macOS**：使用原生 macOS SDK 目标，可直接接入 AppKit。不要误选 Mac Catalyst 作为原生 Mac 实现。AppKit 代码放在 macOS 专属文件或条件编译范围内。
- **CarPlay**：是 iOS 应用的能力，使用 CarPlay 框架的系统模板和相应 scene 配置；不能直接把普通 SwiftUI 页面搬过去。提前核对音频类 CarPlay entitlement。
- **Widget**：添加扩展 target，仅支持 iOS/macOS。规划 App Groups，向小组件提供轻量播放状态或曲库快照；不要依赖它与主应用共享内存中的播放器，也不要把小组件当常驻播放器。
- **watchOS**：两个 project 本身不会自动建立伴随关系。先确定独立 Watch App 还是 iPhone 伴随 App；若需手机传歌，应单独配置关联、嵌入和传输流程。共享 Swift Package 只共享代码，不会自动同步文件或数据。

## 代码与数据边界

1. 核心层放歌曲、歌单、队列等模型，以及数据访问和播放控制接口；避免依赖 UIKit/AppKit。平台页面依赖核心接口，不直接操作数据库或 AVPlayer 的全部细节。
2. 播放服务的生命周期独立于页面。切换页面或窗口不能意外重建播放器。平台音频会话、后台播放、系统媒体控制各自适配。
3. Watch 只实现本地列表、播放/暂停、基础切歌及必要进度控制。即使 AVPlayer 封装很薄，也要处理音频会话、后台播放、中断、输出路由、文件缺失和错误；验收时确保音频实际在手表本地。
4. 数据库保存元数据与索引；音频文件和可重建封面缓存分开管理。普通偏好使用 UserDefaults，凭据使用 Keychain。持久化实现放在独立数据层，避免散落在页面中。
5. Mac 文件访问需要考虑沙盒授权及重启后的访问恢复。tvOS 的文件缓存应按可被系统清理设计，不承诺永久离线保存音乐；遥控器焦点导航单独验收。
6. 从旧版本升级必须保留用户曲库、歌单、设置和必要凭据。迁移前保留可恢复的旧数据，明确失败处理；不能把删除数据库作为正式迁移方案。

## 身份与签名

截图中的 Organization Identifier 为 `Kaka Inc.`，生成了 `Kaka-Inc..Wakemusic`，不建议作为正式标识。新应用应使用规范的反向域名形式；若重构是现有应用的更新，应以现有 App Store 记录对应的 Bundle ID 为准，不能仅按新产品名生成后直接发布。

当前仓库的工程配置中存在 `com.OfflineMusic.www` 和 `com.OfflineMusic.www.pro`。需按旧 target、实际在售版本和 App Store Connect 记录核对，不能随意挑一个。同步核对开发团队、App Groups、Keychain access groups、已有容器和 Watch 关联；新显示名称不意味着应换应用身份。

## 开发与验收约定

- 先确定各平台最低系统版本、旧数据兼容范围、Watch 应用类型和音频传入方式。
- 第一阶段让 iOS、原生 macOS、tvOS、watchOS 都能编译并完成最小播放流程，再逐步迁移完整功能，避免最后才补平台兼容。
- 向开发助手提供明确的平台范围与验收条件。每次改动说明涉及哪些 target，检查实际影响的平台；未执行的设备测试必须标明，不能将一次 iOS 编译成功当作全平台完成。
- 关键单元测试覆盖队列、排序、数据迁移和播放状态转换；界面测试覆盖主要播放入口。播放后台行为、耳机断连、来电中断和 Watch 本地播放安排真机验证。
- 将最终确认的目录规则、平台边界和构建命令写入新 workspace 仓库的 `AGENTS.md`。小步提交，每个阶段保留可构建版本。

## Apple 官方参考

- [Xcode 测试系统选择](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)
- [Swift Testing 与 XCTest 共存](https://developer.apple.com/xcode/swift-testing/)
- [Multiplatform target 与原生 macOS 支持](https://developer.apple.com/documentation/xcode/configuring-a-multiplatform-app-target)
- [AppKit 与 SwiftUI 集成](https://developer.apple.com/documentation/appkit)
- [CarPlay entitlement](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
- [Widget Extension](https://developer.apple.com/documentation/WidgetKit/Creating-a-Widget-Extension) 与 [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups)
- [watchOS 后台音频](https://developer.apple.com/documentation/watchkit/playing-background-audio)
- [tvOS 存储约束（归档指南）](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/index.html)
- [创建工程时的应用标识](https://developer.apple.com/documentation/xcode/creating-an-xcode-project-for-an-app)
