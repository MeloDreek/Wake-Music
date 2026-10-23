# Wakemusic 3.6.0 提交前风险审查

日期：2026-09-25。结论：建议先处理下列确定问题，再生成提交用 Archive。

## 2026-10-23 复核更正

下文历史整改记录中“两处内置 cube 已改为公开 `.push`”与最终提交构建不符，不应作为已完成的依据。2026-10-23 对普通版 iOS 3.6.0（4）的归档反汇编确认 `WelcomeViewController.finishAllPage()` 仍使用内置 `cube`；当天修改前运行源码安全检查也失败。已通过的 Pro iOS 3.6.0（2）存在相同调用，因此不能据此认定本次 2.5.19 / 5.6 拒绝原因。

本次获授权后，才在当前源码中将两处转场落实为公开 `.push`，并添加 Demo 真实音频参数与转场回归。原 IQ 平台隔离脚本及定制生成配置也已移除，恢复标准 CocoaPods 集成；该脚本本身不包含网络请求、审核检测或运行时功能切换。以下旧测试数量和构建记录仅代表当时记录，不能代替新构建验证，更不能作为 App Review 合规保证。

## 后续整改状态（按用户确认执行）

- 已清除自有代码的 `_displayCornerRadius`、UIAlertAction 私有颜色、UIBarButtonItem 私有 view；改为设计圆角、系统 alert 样式、自有按钮 customView。
- 两处内置 cube 已改为公开 `.push`；保持 RTL 方向、减少动态效果设置和 Mac 无动画逻辑。
- 已移除未使用的越狱 fork/沙箱外写入探测。
- 已删除 Google/Dropbox/115 等账号令牌日志，同时删除授权回调 URL、签名播放/下载地址及敏感请求参数日志。
- 两版共用的 app manifest 已新增 DiskSpace / E174.1，匹配下载前空间检查用途。
- 用户确认暂停量江湖：两个请求入口均有默认关闭的保护；安装、购买、重试和归因详情请求不会发送。Apple 官方归因查询保留。
- 已去掉视频 PHPicker 前不必要的全相册授权门槛。
- 用户要求保留：Apple 搜索封面的自动内嵌、光鸭会员中心入口，待用户核实授权与适用地区规则。
- 用户要求暂不改成熟第三方依赖：SDWebImage 等保持原样，其已发现的 SPI 风险仍未消除；不能把“未改动”解读为已经确认安全。
- 新增 `Tests/SubmissionSafety/check.rb` 进行源码/配置回归；最终提交前仍需检查 Release Archive 和 ASC 隐私标签。下面原审查记录保留，方便对照整改前的位置。

原始审查范围：业务源码、自有库、部分依赖源码、两个 App target 的构建配置与隐私清单；另抽查了已有 Debug 真机包和 FFmpeg 二进制。审查阶段未修改业务代码，后续获用户授权的整改见上节。未登录 ASC、上传或提交版本。尚未检查本次最终 Release Archive，也未核对 ASC 实时隐私标签、第三方合同授权全文。风险等级是整改优先级，不是对苹果审核结果的预测；发现风险不等于必然下架或封号。

验证记录：新增源码/配置安全检查 2466 项、导航断言 18 项、歌词 AI 回归 568 项、IQ 平台隔离检查 614 项以及远程依赖配置检查均通过。额外尝试的 `Tests/Purchase/check-policy.rb` 因旧测试替身缺少家庭共享字段、trialEligibleProductIDs 和 onboardingTrialDays 而无法编译；该测试和内购业务本次均未改动，不计为通过。

编译记录：普通版 iOS Simulator、Pro 版 iOS Simulator 和普通版 Apple Silicon Mac Catalyst 的 Debug 构建均成功。本轮未进行真实购买/授权、外部数据上报或 ASC 提交，也未把 Debug 构建当成 Release Archive 审核认证。

## 一、已确认：非公开 API / SPI

以下问题均存在正式构建路径，不只是搜索命中了注释。

### 1. 屏幕物理圆角使用私有 KVC（高）

- `Mobie/Mobie/Base/BaseUI/FullScreenNavController.swift:71`：`value(forKey: "_displayCornerRadius")`。
- 活跃调用：`Mobie/Mobie/Business/PlayerModule/Controller/MusicPlayerViewController.swift:490`。
- `guard/as?` 无法捕获未知 KVC key 的 Objective-C 异常，因此还有系统升级崩溃风险。
- 建议：使用公开圆角配置、设计固定值或自有容器布局，不读取 UIScreen 私有属性。

### 2. UIAlertAction 私有标题颜色（高）

21 处有效调用向 `_titleTextColor` 写值，未被 DEBUG 排除：

- `Mobie/Mobie/Base/Music/KakaMusicPlayer+Delegate.swift:553–555`
- `Mobie/Mobie/Business/ImportModule/Controller/VideoConverterViewController+Action.swift:140,141,213,255,291`
- `Mobie/Mobie/Business/ImportModule/Controller/VideoConverterViewController+Crop.swift:188–190`
- `Mobie/Mobie/Business/ImportModule/Controller/DownloadViewController.swift:339–341`
- `Mobie/Mobie/Business/ConnectModule/Controller/SelectPlaylistController.swift:215`
- `Mobie/Mobie/Business/MusicModule/Controller/MusicsViewController+Action.swift:193,194,221,222`
- `Mobie/Mobie/Business/MusicModule/Controller/MusicsViewController+Delegate.swift:407,456`

建议危险操作使用 `.destructive`，普通按钮使用系统样式或 alert 的公开 tintColor。不应仅把 key 改成 `titleTextColor`，它同样不是公开属性。LyricDetialViewController 内已注释的同类代码未计入。

### 3. 内置 cube 转场是未公开类型（高）

- `Mobie/Mobie/Business/OtherModule/LoginModule/WelcomeViewController+Page.swift:84`
- `Mobie/Mobie/Business/MusicServerModule/Navigation/AppModeCoordinator.swift:138`

两处使用 `CATransitionType(rawValue: "cube")`，iOS 正式流程可触发。公开 CATransition 类型只有 fade、moveIn、push、reveal。若要保留立方体视觉，可以通过公开 snapshot、CATransform3D 和 UIView 动画自己实现；不能继续调用未公开的内置 cube 类型。

依据：[Apple CATransitionType](https://developer.apple.com/documentation/quartzcore/catransitiontype)、本机 SDK CAAnimation.h。

### 4. 气泡提示读取 UIBarButtonItem 的私有 view（高）

- `LocalSDK/KakaObjcKit/Classes/CustomUI/CMPopTipView.m:608`：`performSelector:@selector(view)`。
- 活跃入口：`Mobie/Mobie/Business/PlayerModule/Controller/PlayBackgroundListController.swift:85`，播放器背景设置的首次提示。
- 建议：使用自有 customView 作为锚点，或公开 UIPopoverPresentationController.barButtonItem。

### 5. SDWebImage 5.19.7 也存在非公开调用（高）

不能只清理 App 业务代码：

- `Pods/SDWebImage/SDWebImage/Core/SDImageCoderHelper.m:61`：构造并调用 UIDevice 的 `_deviceInfoForKey:`；HEIC/HEIF 解码分支在 654、746 行使用。
- `Pods/SDWebImage/SDWebImage/Core/UIImage+Metadata.m:72,79`：调用 UIImage 的 `_CGSVGDocument`、`_CGPDFPage`；图像解码和 manager 的矢量图判断会使用。
- `SDInternalMacros.h:79` 的 `SD_SEL_SPI` 为 selector 拼接 `_`。
- 这些受 UIKit 条件编译控制，并非 DEBUG-only；当前 iOS/Catalyst 可编入。Pods Sources 与 Release framework 内嵌脚本均包含该依赖。
- 来源：`LocalSDK/KakaPhotoBrowser/KakaPhotoBrowser.podspec:23` 锁定 `~> 5.19.1`，Podfile.lock 当前解析到 5.19.7。

建议升级到经源码确认不含这些调用的版本、维护可复现补丁，或迁移图片加载实现。仅仅升级版本、混淆 selector、或者以热门库为理由，均不等于问题解决。

注意：另一个 `CGImageGetImageSource` 动态调用受未启用的 `SD_CHECK_CGIMAGE_RETAIN_SOURCE` 宏控制，本次未算作有效风险。native AppKit 的 `_NSSVGImageRep` 分支也未冒充 Catalyst 调用。

上述问题关联 [App Review Guidelines 2.5.1](https://developer.apple.com/app-store/review/guidelines/#software-requirements)：仅使用公开 API。不能保证一次命中就封号，也不能以过去通过审核证明继续使用安全。

## 二、已确认：隐私与安全问题

### 6. 网盘凭据写入正式运行日志（高）

以下调用未被 `#if DEBUG` 排除；Swift 的 `debugPrint` 名字不意味着仅 Debug 构建执行：

- `Mobie/Mobie/Base/Music/KakaMusicPlayer.swift:278`：完整 Google 账号模型，含令牌。
- `Mobie/Mobie/System/SceneDelegate.swift:163,177`：Dropbox accessToken / refreshToken 所在账号模型。
- `Mobie/Mobie/Base/Music/KakaMusicPlayer+API.swift:703`：115 刷新令牌响应。
- `Mobie/Mobie/Business/ConnectModule/Controller/Drive115FileListController.swift:28`：access_token。

建议删除或彻底脱敏，而不是只包 DEBUG；测试日志也不应记录可复用凭据。没有证据证明这些 stdout 已被自动上传至 Crashlytics，不作此推断。APIManager.swift:119–129 已有 DEBUG 保护，不列为该问题。

### 7. MEGA 磁盘容量 API 缺少对应理由声明（高）

- `LocalSDK/MEGASDK/src/posix/fs.cpp:2844`：availableDiskSpace 调用 statfs。
- `LocalSDK/MEGASDK/src/megaclient.cpp:19080`：正常下载流程调用该检查。
- MEGA Package.swift 包含该源码，没有对应隐私资源。
- `Mobie/Mobie/System/PrivacyInfo.xcprivacy:9` 的 API 类别未包含 `NSPrivacyAccessedAPICategoryDiskSpace`。
- 已有 Debug 真机包也引用 `_statfs`，不是仅存在于未编译示例。

建议为真实下载空间检查补齐合适的理由声明（修复时核对 E174.1 的完整条件），并在最终 Archive 隐私报告中核实。不能由其他无关 SDK 的声明代替 MEGA 的实际用途。

依据：[Apple Required Reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)。

### 8. 广告归因数据披露需要补核（高，是否构成 tracking 尚待确认）

- `Mobie/Mobie/Base/Core/Tools/AppleSearchAdsManager.swift:103` 定义 cloudUserID；参数还包括国家、设备/系统、安装广告归因和购买金额；245 行发送给量江湖。
- 安装、购买流程会触发，该发送不受 ATT 状态控制。
- app manifest 当前对 UserID 只声明 AppFunctionality，另有 CrashData / OtherDiagnosticData，没有描述自有归因数据传输的完整用途。
- 公开英文隐私政策已说明 Firebase 和 RevenueCat，不能误报二者完全未披露；本次未在该页找到量江湖/广告归因的对应说明。需要同步核对实际合同、中文及其他语言政策、ASC 标签和 app manifest。

第三方 ASA 归因不自动等于 Apple 定义的 tracking。必须确认服务商是否跨公司关联或另作广告用途：若构成 tracking，须遵守 ATT；若只是符合条件的受托分析，也仍需如实披露，不能简单把 NSPrivacyTracking 改 true 就认为处理完成。

依据：[Apple User Privacy and Data Use](https://developer.apple.com/app-store/user-privacy-and-data-use/)。

### 9. 视频导入申请了不必要的全相册权限（中）

- `Mobie/Mobie/Business/ImportModule/Controller/VideoConverterViewController+Action.swift:34`：在 PHPicker 前请求 `.readWrite`，拒绝后阻止使用 picker。
- PHPicker 选取视频本身不需要完整相册授权。现行用途说明主要写保存封面，未准确覆盖视频读取/背景选择。
- 建议移除 picker 前的权限门槛，按真正需要的相册读/写操作请求权限并更新用途文案。

两个 plist 还声明 processing、fetch、remote-notification，但未找到对应实际后台处理入口，建议精简；音频后台播放则有真实用途。没有证据表明当前在恶意保活。

## 三、内容、付费与许可证：提交前需核实

### 10. iTunes 封面搜索后永久内嵌，不等于已取得授权（高，需确认权利）

- `Mobie/Mobie/Base/Core/Tools/AppleCatalogMetadataService.swift:55`、`MusicTagEditor.swift:32` 使用 iTunes Search API。
- `CatalogMetadataMatcher.swift:44` 获取封面 URL；`MusicTagEditor+Embed.swift:132` 下载、194 行写入音频。
- 现行 Apple Search API 说明将专辑封面视为推广素材，要求用于推广对应商店内容及关联商店入口。这不等同于授权任意永久内嵌、再分发封面。

这是使用授权问题，不是私有 API。建议确认许可或改用有明确授权的数据源/用户提供的封面；单加商店链接不能保证永久内嵌已获授权。“个人收藏、非商业用途”也不是自动的版权豁免。

依据：[Apple 当前 Search API 文档](https://performance-partners.apple.com/search-api)。

### 11. 光鸭会员中心外链需按销售地区与权限确认（中高，非一律违规）

- `Mobie/Mobie/Business/ConnectModule/Controller/GuangyaDriveFileListController.swift:275` 无地区区分打开第三方 VIP 中心。
- 若目标页面可直接购买用于 App 内访问的数字服务，可能产生外部购买引导问题。美国及部分地区规则/授权存在差异，不能全球一概判断安全或违规。
- 建议核实落地页和适用权限；保守做法是先提供不带购买引导的状态说明/帮助页面。不能仅通过改按钮文字规避实质规则。

依据：[Apple 3.1 支付规则](https://developer.apple.com/app-store/review/guidelines/#payments)。

### 12. 其他需要资料核实的事项

- 商务授权应覆盖对应产品、AppID、iOS/macOS、播放和下载能力；正式 key 本身不代表覆盖所有使用场景。为审核准备授权证明和可访问的演示方式。
- 商业歌曲、歌词、专辑封面、人物照片、Demo 音频及截图/预览视频需核实使用权。添加高斯模糊不自动取得授权，也不能保证审核接受；优先原创、获授权或公共领域素材。
- 当前抽查的 FFmpeg iOS Libavutil 标识 LGPL v3 or later，libmpv 配置为 `-Dgpl=false`，没有据此发现 GPL 模式被开启。仍需核实全部实际链接组件、许可证告知、修改源码及 LGPL 分发义务；“不是 GPL”不等于不需要履约。[FFmpeg 官方说明](https://ffmpeg.org/legal.html)。
- 客户端内的供应商 secret 无法真正保密。应按供应商要求使用 PKCE、受限应用凭据或服务端兑换；这首先是凭据安全/服务商合规问题，不等于发现 App Store 封号条件。

## 四、已排除的误报和边界

- ChatGPT 等客户端 Scheme + UIApplication.open 是公开机制，本身不是私有 API；复制由用户主动触发，当前未把提示词拼入 URL 自动发送。
- 普通版 isVIP 当前调用 isPremium，Pro 版默认 true 符合产品定位；没有发现普通版正式 VIP 写死为 true。
- 当前购买流程使用 StoreKit / RevenueCat，存在恢复购买和试用资格判断；没有发现 DiscountIAPManager 虚假倒计时仍在有效代码中。
- IDFA 读取受 ATT authorized 控制；不能把 Firebase、ASA 或任何分析行为直接等同于绕过 ATT。
- 本地网络/WebDAV 的 HTTP 兼容配置不是私有 API，不应机械全部禁掉。
- Objective-C associated objects、动态调用自有方法、Core Image KVC、正常系统 URL Scheme 均不是仅因“动态”就违规。
- `LocalSDK/KakaFoundation/Classes/Extentions/UIDevice+Extension.swift:23` 存在 fork/沙箱外写入的越狱探测，但没发现调用。建议移除无用探测，不把 fork 本身误报为确定私有 API。

## 五、建议整改与最终验证顺序

1. 移除以上私有 KVC/selector；用公开 API 重做 cube 视觉；处理 SDWebImage SPI。
2. 清除敏感日志，补充实际 API 理由和数据用途，修正相册权限。
3. 确认封面/歌词/演示素材许可、光鸭外链政策及第三方授权范围。
4. 对普通版、Pro 的 iOS 与 Mac Catalyst 重新 Archive；扫描最终二进制、合并隐私报告、签名 entitlements 与打包资源，再在 Organizer Validate App。
5. 核对 ASC 隐私标签、年龄分级、产品/试用信息和审核备注。通过编译、静态扫描或 Validate 都不是最终审核保证。

不建议因为担心风险而隐藏功能、混淆私有 selector 或对审核账号特殊处理。整改应对所有用户一致生效。
