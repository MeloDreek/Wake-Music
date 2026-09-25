# 维克音乐 3.6.0 · App Store 截图提案

简体中文第一版设计稿，仅供确认视觉方向，**尚未上传到 App Store Connect**。

## 交付

- `preview.png`：六张静态截图的总览。
- `final/01.png`—`final/06.png`：1242 × 2688 像素、无透明通道的 PNG，对应 Apple 的 6.5 英寸截图规格。
- `Wakemusic-3.6.0-zh-Hans-6.5-v1.zip`：仅包含上述六张单图。
- `design.html`：可编辑的排版源文件；`?page=1` 可查看单张，`?view=contact` 可查看总览。
- `raw/`：未重新绘制的应用界面素材及批量进度组件截图；这些源素材并非可直接上传的最终宣传图。

原有预览视频独立保留在 ASC。静态图顺序为：

| 文件 | 内容 | 画面来源 |
| --- | --- | --- |
| 01 | 无网，也有好音乐 | 原创音波雕塑、真实应用及连接服务图标、离线/NAS/网盘文案 |
| 02 | 好声音，自己调 | 应用真实均衡器页面，低音增强预设已启用 |
| 03 | 每一句，都有共鸣 | Yesterday Once More 的真实封面与歌词页面；使用应用高斯模糊背景，封面另有局部半透明模糊层 |
| 04 | 识别一次，永久珍藏 | 真实本地列表 + 应用实际 UIKit 批量进度组件；4/9 为明确模拟的处理进度 |
| 05 | 喜欢的格式，尽管听 | 当前应用真实 Onboarding 首屏与格式标签 |
| 06 | 让声音，看得见 | Die With A Smile 的实际本地音频频谱分析结果 |

## 素材真实性与隔离

界面在独立的 `Wakemusic App Store Studio` 模拟器中采集。原始界面为 1320 × 2868，等比置入手机外壳后排版到 1242 × 2688 的商店画布，不拉伸界面，也未通过生成模型重画 UI。

测试音乐仅从本机现有音频复制到隔离容器，原始文件未改动。批量页使用生产 `MusicTopBatchEditHeadView`、`MatchingProgressView` 等组件的独立渲染器，注入文件名和进度，未执行实际标签写入。

手机外壳、文字和局部模糊由可编辑 HTML/CSS 排版，最终使用系统 WebKit/AppKit 渲染。可识别的专辑/艺术家封面局部模糊；此处理不等于版权许可或 App Store 审核通过保证。公开投放前仍需确认所用音乐、歌词和第三方标志的展示权利。

## 再次导出

从项目根目录运行：

```sh
bash Tools/AppStoreScreenshots/render-design.sh \
  outputs/AppStore-3.6.0-zh-Hans-v1/design.html \
  outputs/AppStore-3.6.0-zh-Hans-v1/final \
  outputs/AppStore-3.6.0-zh-Hans-v1/preview.png
```

无需连接 ASC；本目录不包含凭据。后续本地化可复用真实界面素材、构图及设备外壳，并按市场调整首页展示的网盘。

## 原创装饰素材

`assets/audio-sculpture.png` 使用内置图像生成工具创建，非 CLI。只有装饰雕塑使用生成模型，应用界面没有使用生成模型伪造。

最终生成提示词：

> Use case: ads-marketing. Asset type: original abstract 3D audio sculpture for Wakemusic App Store promotional screenshot, no user interface. Create one beautiful premium abstract sound-wave sculpture: a floating continuous loop made from many thin brushed silver metallic ribs, with subtle warm amber reflected light along a few edges. It should evoke precision hi-fi equipment and musical flow, not a recognizable third-party device. On a near-black warm charcoal seamless studio backdrop with a subtle spotlight. Single wide sculptural object centered in lower-middle, spacious negative space above and below. Front three-quarter view, understated photoreal product-render quality, soft studio shadows, extremely clean restrained luxury. Portrait 2:3 composition. No text, no logos, no phone, no buttons, no screens, no extra objects, no neon, no rainbow. This will be used as an original decorative asset behind actual app screenshots, so keep the silhouette clean and high contrast.

## 现有 ASC 素材清理

本次仅清理 iOS 普通版/Pro 的 6.9 英寸截图，未上传新图、未更改预览视频、未提交审核。删除清单、可恢复 PNG 备份和完整验证报告另存于 `../asc-screenshot-cleanup-3.6.0-20260925-run2/`。

规格参考：[Apple 截图规格](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)。
