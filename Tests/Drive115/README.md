# 115 网页授权评估与格式回归

## 2026-09-15 官方授权文档核对

通过已登录的 Chrome 阅读 [115 官方文档](https://open.115.com/developer-doc)的“接入指南 → 接入授权 → 授权码模式”：

- “请求授权”要求 `redirect_uri` 的域名先在应用管理中配置，并验证返回的 `state`。
- “用授权码换取 access_token”要求 `client_secret` / AppSecret，注意事项明确要求在服务端安全保存并使用，不在客户端代码中泄露。
- 用户要求不部署服务端，因此保留现有手机扫码 PKCE 模式。本次没有修改登录实现、密钥、回调域名或开发者后台配置。
- `redirect_uri` 作为 OAuth 概念不必然要求服务器；本次决定主要基于 115 这条授权码流程对 AppSecret 的具体要求，不能推广成所有网盘都需要服务器。

## DSF / DFF 限制

使用 `Drive115FileModel.isUnsupportedStreamingAudio` 统一识别 115 远程 DSF / DFF。音乐分组、曲目按钮和播放列表使用同一 `isMusic()` 判断；旧播放队列及下一首预加载另外设置守卫。沿用已有 `Unsupported Files` 本地化。

扩展名兼容大小写、API `ico` 字段带点/空白以及详情响应缺少 `ico`；文件名的 DSF / DFF 后缀也会校验。名称带 `.dsf` 的文件夹仍能正常浏览。本地与其他提供方的通用 DSF / DFF 格式列表未改动。底层下载接口保持原样，不扩大为所有来源的下载限制。

```sh
ruby Tests/Drive115/run-format-regressions.rb
```

脚本编译实际 `Drive115FileModel.swift` 与实际音视频格式枚举，仅为无关的 UI/持久化依赖提供替身；不读取账号、真实文件或访问网络。36 项模型断言和 5 项源码接入检查通过。接入检查是源码约束，不等同于真实 115 账号的端到端测试。
