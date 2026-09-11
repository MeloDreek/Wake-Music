# Box 接入与验收

基于现有 UIKit / Mac Catalyst 网盘流程，不涉及 SwiftUI 重构，不增加 Box SDK 或更新已有依赖。

## 配置

- 使用 `AppGroupConstKey` 中的 `Box_ClientID`、`Box_ClientSecret`，正式授权不使用 `Box_DevelopToken`。
- `Box_RedirectURL` 为 `wakemusic-box://oauth/callback`。用户已确认在 Box 后台保存；普通版和 Pro 版均注册了 `wakemusic-box` URL Scheme。
- 后台认证类型需要 OAuth 2.0，启用 “Read all files and folders stored in Box”。授权请求只申请 `root_readonly`，不申请上传、修改或删除权限。后台权限勾选仍需人工核对。
- App 使用系统 `ASWebAuthenticationSession`，验证回调路径、一次性 state 和授权码。普通版与 Pro 版的账号令牌分别存入自己的 Keychain，不写入 App Group 文件模型、不打印令牌。
- 本次保留已有原生客户端凭据配置方式；客户端内置的 client secret 不能当作服务器端保密凭据。不要把开发者临时令牌作为正式用户授权方案。

## 实现范围

- 导入／连接入口、多个账号、根目录和子目录、完整 marker 分页、刷新、当前目录搜索、分组与排序。
- 播放、切歌、暂停／继续、预下载；每次网络使用重新获取临时内容链接，不把链接当永久地址，也不向 CDN 传递账号 OAuth 令牌。
- 按账号串行合并刷新令牌请求，保存轮换后的令牌再恢复请求；401 最多重新授权请求一次，删除账号后迟到的请求不能恢复授权或继续启动播放。
- 对新上传尚未就绪文件的 202／下载限流 429，尊重秒数形式的 Retry-After，最多重试两次；过长等待返回失败，不无限重试。
- 网盘行直接下载按钮、选择保存位置、批量加入下载队列、保留原文件名，同名本地文件递增编号、不覆盖；HTTP 失败正文不能保存为音乐文件。
- 收藏／取消收藏、恢复播放列表和删除连接，保持账号隔离；预下载缓存按账号及文件 ID 命名。显式下载后的本地音乐不受删除连接影响。
- 没有云端音乐标签页面、云端标签写入或云端文件上传／删除；本地标签编辑与现有播放引擎、会员规则保留。
- 新增四条提示覆盖现有 42 个语言／地区；空目录、搜索无结果、加载失败使用不同状态。

## 自动检查

在项目根目录运行：

```sh
bash Tests/Box/run-regressions.sh
bash Tests/PCloud/run-model-regressions.sh
bash Tests/PCloud/run-status-regressions.sh
```

Box 测试编译真实模型、Foundation 网络客户端及空列表状态逻辑，使用 URLProtocol 拦截全部网络请求。覆盖模型序列化、跨账号身份、OAuth state／回调校验、只读 scope、分页与重复 marker、并发刷新、401／403／404、临时链接校验、202／429、令牌保存失败、删除账号竞态、本地化、入口可见性及两个版本的回调注册。

这些检查不读取真实账号、音乐库或 Keychain，也不等同于真实账号／设备验收。

本轮结果：221 项 Box 检查、23 项 pCloud 模型检查、305 项 pCloud 状态与本地化检查通过；普通版／Pro 版 iOS Simulator 构建通过。Mac Catalyst 构建受现有 `IQKeyboardReturnManager` 对 `UIInputSuggestion`／`UITextFormattingViewController` 的兼容性错误阻挡，未改动该依赖，Mac 整包未验证通过。真实账号只读测试尚未执行，等待单独授权；没有访问或修改 Box 文件。

## 真实账号与设备验收

1. 普通版／Pro 版在 iPhone、iPad、Mac Catalyst 从导入及连接入口打开 Box；授权取消不新增账号，成功后显示正确邮箱及文件列表。
2. 空根目录、空子目录、两层以上目录、包含超过 1000 项的目录；刷新不重复、删除的云端文件不残留。搜索后刷新及切换分组仍保留过滤条件。
3. 中文、空格、`#`、`&` 文件名及大写音频后缀；文件夹和非音频不能加入音乐下载队列。
4. 系统引擎和全格式引擎分别测试支持的格式、拖动、后台播放、切歌和快速 A→B→A。取链接期间暂停／停止，迟到的请求不能自行恢复播放。
5. 单曲及批量下载，两个目录／账号的同名文件不可串歌或覆盖；下载后的本地文件可离线播放和编辑标签。失败任务保留可重试。
6. 收藏／取消收藏后重启，确认状态和账号正确；撤销授权后刷新提示重新登录，并要求登录原账号；重新授权取消不能切换到别的账号。
7. 令牌过期时同时触发列表、播放、下载；删除连接不能被迟到的刷新请求重新建立，不能影响其他账号或已经显式下载的本地音乐。
8. 企业账号可能有管理员应用限制、下载禁用、水印或其他内容策略；实际权限以该账号及文件权限为准，不承诺绕过限制。

## 官方接口依据

- [Box iOS OAuth 登录及自定义回调](https://github.com/box/box-ios-sdk/blob/main/docs/Authentication.md)
- [列举文件夹及 marker 分页](https://developer.box.com/reference/get-folders-id-items)
- [刷新令牌及单次使用规则](https://developer.box.com/guides/authentication/tokens/refresh)
- [获取临时下载 URL](https://developer.box.com/guides/downloads/get-url)
- [下载文件与 Range](https://developer.box.com/reference/get-files-id-content)
