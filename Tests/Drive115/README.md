# 115 网页授权评估与格式回归

## 2026-09-15 官方授权文档核对

通过已登录的 Chrome 阅读 [115 官方文档](https://open.115.com/developer-doc)的“接入指南 → 接入授权 → 授权码模式”：

- “请求授权”要求 `redirect_uri` 的域名先在应用管理中配置，并验证返回的 `state`。
- “用授权码换取 access_token”要求 `client_secret` / AppSecret，注意事项明确要求在服务端安全保存并使用，不在客户端代码中泄露。
- 初次评估时保留手机扫码 PKCE；之后用户明确接受客户端包含应用密钥的风险，并要求默认网页登录，下述实现取代初次决定。未修改开发者后台配置。
- `redirect_uri` 作为 OAuth 概念不必然要求服务器；本次决定主要基于 115 这条授权码流程对 AppSecret 的具体要求，不能推广成所有网盘都需要服务器。

## 默认网页登录（2026-09-16）

- 默认打开 115 官方授权网页；右上角保留二维码入口，可切回网页登录。复用既有本地化。
- 用户确认控制 `passlockapp.com`，回调使用 `https://passlockapp.com/oauth/115/callback`。WKNavigationDelegate 在导航请求发出前拦截并验证 HTTPS、域名、端口、路径和一次性 state，再直接向官方接口换取令牌。不需要在网站部署回调接口；这不是系统浏览器 Universal Link 方案。
- 应用密钥在 AppGroupConstKey 中由客户端使用，可以被提取，不符合官方推荐的服务端保密方案。不得把这一方案描述为能保守客户端密钥秘密。授权码、密钥和令牌不写入调试日志；令牌请求不跟随重定向。
- 切换登录方式、取消及关闭页面时取消请求和轮询，通过每次授权独立的标识拒绝过期回调。授权成功沿用现有连接保存与 Import → Connect 路由。
- 使用非持久 WKWebView 网站数据，不读取网页密码。

```sh
ruby Tests/Drive115/run-web-authorization-regressions.rb
```

31 项纯 URL 校验和请求/取消/日志源码接入检查覆盖回调伪造、重复参数、state 不匹配、授权码重复消费等情况。测试不访问真实账号；真实登录与令牌兑换仍须在模拟器中完成。

### 40140133 凭据配置修正

2026-09-16 根据官方接入流程及授权错误码核对：AppID、AppKey、AppSecret 是不同字段；`40140133` 表示 `client_secret` 验证失败，而非回调域名错误。原实现将 AppKey 误用于 `client_secret`。

- 用户已在 AppGroupConstKey 中分别填写 `Drive115_ClientID`、`Drive115_AppKey`、`Drive115_AppSecret`，并将令牌兑换调用改为 `Drive115_AppSecret`；保留用户的凭据值。
- 网页授权和扫码设备码请求均使用 `Drive115_ClientID`。授权码兑换的 POST body 使用 `Drive115_AppSecret`；当前两种登录流程不需要 AppKey，不能把它替代 AppSecret。
- 后台“应用域名”填写 `passlockapp.com`，不是完整 URL。代码仍使用完整的 `https://passlockapp.com/oauth/115/callback`，授权请求与令牌兑换必须一致。
- 增加 5 项源码接入检查，约束密钥字段选择、旧字段移除、回调一致和二维码 ClientID。检查不读取或输出真实凭据；编译通过不代表真实令牌兑换已经成功。
- 本轮验证：31 项 URL 校验、5 项凭据接入检查、36 项格式校验与 5 项格式策略接入检查通过；Xcode 27 下普通版及 Pro 的 arm64 模拟器 Debug 构建通过。普通版已安装到当前 iPhone 17 Pro Max（iOS 26.5），真实网页登录结果等待用户确认。

## DSF / DFF 限制

使用 `Drive115FileModel.isUnsupportedStreamingAudio` 统一识别 115 远程 DSF / DFF，但 `isMusic()` 仍返回 true：列表保留音乐分组及音频格式占位图。点击播放先显示本地化下载提示，取消不改变播放状态，下载直接加入现有下载队列（默认本地目录）。在线播放队列排除 DSF / DFF，旧播放队列使用同一提示，下一首预加载保留守卫。

扩展名兼容大小写、API `ico` 字段带点/空白以及详情响应缺少 `ico`；文件名的 DSF / DFF 后缀也会校验。名称带 `.dsf` 的文件夹仍能正常浏览。本地与其他提供方的通用 DSF / DFF 格式列表未改动。底层下载接口保持原样，不扩大为所有来源的下载限制。

```sh
ruby Tests/Drive115/run-format-regressions.rb
```

脚本编译实际 `Drive115FileModel.swift` 与实际音视频格式枚举，仅为无关的 UI/持久化依赖提供替身；不读取账号、真实文件或访问网络。包含 39 项模型断言、格式策略/弹窗/队列/封面源码接入检查，以及 41 种语言翻译检查。接入检查是源码约束，不等同于真实 115 账号的端到端测试。
