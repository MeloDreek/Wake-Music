# WaketagLibKit

面向 Apple 平台的音频元数据库，基于 TagLib **2.3.2**，提供 Objective-C 与 Swift 接口，读取和修改基本标签、内嵌封面及歌词。本文对应封装版本 **2.3.3**。

包、模块和 CocoaPod 名称为 `WaketagLibKit`。为保持现有调用兼容，`TaglibMetadataParser`、`MetadataTagModel`、`LyricLineModel`、`KakaImage` 等公开类型名称保持不变。

这是元数据工具，不是音频播放器、解码器或转码器。某种容器可以被识别，不代表其中所有编码、标签变体或损坏文件均可处理；下面将实际验证的能力与尚未验证的代码路径分开列出。

## 支持平台

| 平台 | 最低版本 | 图像类型 |
| --- | --- | --- |
| iOS | 15.0 | `UIImage` |
| macOS | 12.0 | `NSImage` |
| Mac Catalyst | 15.0 | `UIImage` |
| tvOS | 15.0 | `UIImage` |
| watchOS | 9.0 | `UIImage` |

需要缓存或传输封面时，可直接使用 `NSData` / Swift `Data` 接口，不必创建平台图像对象。

## 安装

### Swift Package Manager

在 Xcode 的 **Add Package Dependencies** 中输入：

```text
https://github.com/MeloDreek/WaketagLibKit.git
```

选择 `2.3.3` 或更新的兼容版本，并将 `WaketagLibKit` 产品加入应用目标。在 `Package.swift` 中也可使用：

```swift
dependencies: [
    .package(url: "https://github.com/MeloDreek/WaketagLibKit.git", from: "2.3.3")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "WaketagLibKit", package: "WaketagLibKit")
        ]
    )
]
```

需要 Swift 工具版本 5.9 或更新版本。TagLib 的 C++17 实现在内部 `WaketagLibCore` 目标中编译；应用只需 `import WaketagLibKit`，无需开启 Swift C++ interoperability。

### CocoaPods

```ruby
pod 'WaketagLibKit', :git => 'https://github.com/MeloDreek/WaketagLibKit.git', :tag => '2.3.3'
```

## 快速使用

```swift
import WaketagLibKit

let fileURL = URL(fileURLWithPath: "/path/to/song.mp3")
let metadata = TaglibMetadataParser.readMetadata(withFileURL: fileURL, read: .basic)
let image = TaglibMetadataParser.extractCoverArt(from: fileURL)
let saved = TaglibMetadataParser.setTitle("新标题", toFileURL: fileURL)

if !saved {
    // 文件不可写、格式不支持该操作或保存失败。
}
```

| 读取模式 | 基本标签与技术属性 | 封面 | 歌词 |
| --- | --- | --- | --- |
| `.basic` | 读取 | 不读取 | 不读取 |
| `.basicCover` | 读取 | 读取 | 不读取 |
| `.basicLyrics` | 读取 | 不读取 | 读取 |
| `.all` | 读取 | 读取 | 读取 |

单独读取或原样写入封面数据：

```objc
NSData *artwork = [TaglibMetadataParser extractCoverArtDataFromURL:fileURL];
if (artwork != nil) {
    BOOL saved = [TaglibMetadataParser setCoverArtData:artwork toFileURL:otherFileURL];
    // 检查 saved，读取成功不代表目标格式可以写入此图片。
}
```

接口只接受有权限访问的本地文件 URL。库在访问期间尝试获取 security-scoped 访问权，并在结束后释放；沙盒授权仍由调用方提供。无效输入或读取失败返回 `nil`，写入失败返回 `NO` / `false`，目前不提供结构化错误对象。成功读取但没有标签的文件仍可返回模型，缺失的文本为 `""`、数值为 `0`；不存在的封面和歌词为 `nil`。

## 公开字段

下面格式表中的“基本 7 项”指以下全部字段，不包含专辑艺术家、作曲家、碟号、音轨总数、完整日期或任意自定义标签。

| 字段 | 含义 | 读取 | 写入方法 |
| --- | --- | --- | --- |
| `title` | 标题 | 字符串 | `setTitle` |
| `artist` | 艺术家 | 字符串 | `setArtist` |
| `album` | 专辑 | 字符串 | `setAlbum` |
| `comment` | 评论 | 字符串 | `setComment` |
| `genre` | 流派 | 字符串 | `setGenre` |
| `year` | 年份，不是完整日期 | 非负整数 | `setYear` |
| `track` | 音轨序号，不是总数 | 非负整数 | `setTrack` |
| `bitrate` | 比特率，**bps** | 只读 | — |
| `sampleRate` | 采样率，**Hz** | 只读 | — |
| `durationSeconds` | 时长，**整数秒** | 只读 | — |
| `channel` | 声道数 | 只读 | — |
| `coverArtData` / `coverArt` | 编码图片字节 / 平台图像 | 按读取模式 | `setCoverArtData` / `setCoverArt` |
| `lyricModel` | 纯文本或带时间戳的歌词模型 | 按读取模式 | `setLyrics`；旧名称 `setLyris` 为别名 |

技术属性来自文件头和 TagLib 的解析结果，不执行完整音频解码；不可获得的值为 `0`。不足一秒的有效音频，其 `durationSeconds` 也可能为 `0`。基本字段是单值接口：读取不公开语言/多值列表，写入可能规范化被编辑字段；例如年份写入不保留该字段中的月日，音轨写入不保证保留同一字段中的总数。

基本字段的原生写入映射如下。读取还可能接受该标签体系的旧字段或兼容表示；本表不表示可以通过公开 API 直接读写任意键名。

| 字段 | ID3v2 | Vorbis Comment | APEv2 | MP4 | ASF |
| --- | --- | --- | --- | --- | --- |
| 标题 | `TIT2` | `TITLE` | `TITLE` | `©nam` | Content Description：Title |
| 艺术家 | `TPE1` | `ARTIST` | `ARTIST` | `©ART` | Content Description：Author |
| 专辑 | `TALB` | `ALBUM` | `ALBUM` | `©alb` | `WM/AlbumTitle` |
| 评论 | `COMM` | 已有 `DESCRIPTION` 或 `COMMENT` | `COMMENT` | `©cmt` | Content Description：Description |
| 流派 | `TCON` | `GENRE` | `GENRE` | `©gen` | `WM/Genre` |
| 年份 | `TDRC` | `DATE` | `YEAR` | `©day` | `WM/Year` |
| 音轨 | `TRCK` | `TRACKNUMBER` | `TRACK` | `trkn` | `WM/TrackNumber` |

ID3v1、RIFF INFO、DSDIFF DIIN 等旧标签的读取遵循上游的优先级与编码规则，不自动猜测 GBK 等本地编码。WAV 的基本字段可从 `INAM`、`IART`、`IPRD`、`ICMT`、`IGNR`、`ICRD`、`IPRT` 读取，但本库的对应写入使用 ID3v2，而不是修改这些 INFO 字段。

## 格式与标签读写能力

### 已有端到端回归覆盖的格式

`读/写` 表示既可提取已有内容，也可通过公开接口保存后重新打开读取。下列格式均已验证基本 7 项、纯文本/LRC 歌词、JPEG/PNG 封面的写入与重读；技术属性只读。验证针对具体样本，不是所有编码或文件变体的保证。

| 格式及常用扩展名 | 基本 7 项 | 歌词 | 封面 | 技术属性 | 写入的原生标签 / 封面容器 | 回归样本 |
| --- | --- | --- | --- | --- | --- | --- |
| MP3 `.mp3` | 读/写 | 读/写 | 读/写 | 读 | ID3v2 / APIC | 合成 MP3 |
| FLAC `.flac` | 读/写 | 读/写 | 读/写 | 读 | Vorbis Comment / 原生 PICTURE 块 | 合成 FLAC |
| MP4 音频 `.m4a` | 读/写 | 读/写 | 读/写 | 读 | MP4 `ilst` / `covr` | 合成 AAC-in-M4A |
| WAV `.wav` | 读/写 | 读/写 | 读/写 | 读 | ID3v2 / APIC；可读取 RIFF INFO 基本标签 | 合成 PCM WAV |
| AIFF `.aiff`、`.aif` | 读/写 | 读/写 | 读/写 | 读 | ID3v2 / APIC | 合成 PCM AIFF |
| Ogg Vorbis `.ogg` | 读/写 | 读/写 | 读/写 | 读 | Vorbis Comment / `METADATA_BLOCK_PICTURE` | 合成 Vorbis |
| Ogg Opus `.opus` | 读/写 | 读/写 | 读/写 | 读 | Vorbis Comment / `METADATA_BLOCK_PICTURE` | 合成 Opus |
| WavPack `.wv` | 读/写 | 读/写 | 读/写 | 读 | APEv2 / `COVER ART` 项 | 合成 WavPack |
| TrueAudio `.tta` | 读/写 | 读/写 | 读/写 | 读 | ID3v2 / APIC | 合成 TTA |
| ASF / WMA `.asf`、`.wma` | 读/写 | 读/写 | 读/写 | 读 | ASF 属性 / `WM/Picture` | 合成 WMA-in-ASF |
| DSF `.dsf` | 读/写 | 读/写 | 读/写 | 读 | ID3v2 / APIC | 可选上游 DSF 样本 |
| DSDIFF `.dff`、`.dsdiff` | 读/写 | 读/写 | 读/写 | 读 | ID3v2 / APIC；可读取 DIIN 标题和艺术家 | 可选上游 DFF 样本 |
| Monkey's Audio `.ape` | 读/写 | 读/写 | 读/写 | 读 | APEv2 / `COVER ART` 项 | 可选上游 APE 样本 |
| Musepack `.mpc` | 读/写 | 读/写 | 读/写 | 读 | APEv2 / `COVER ART` 项 | 可选上游 MPC 样本 |

扩展名别名共用容器解析器，不意味着每个别名都有独立测试。MP4 的当前回归样本是 AAC，不将其外推为 ALAC、受保护媒体或所有视频容器变体的验证。

### 已接入但未完成相同级别验证的格式

本表中的“代码路径”仅说明当前封装会尝试相应操作，**不等于已验证支持**。用于重要文件前，应在副本上独立验证写入结果与其他标签的保留情况。

| 格式 / 扩展名 | 基本标签 | 歌词 | 封面 | 技术属性 | 当前验证边界 |
| --- | --- | --- | --- | --- | --- |
| MPEG Layer II `.mp2` | 7 项读/写代码路径，ID3v2 | 读/写代码路径 | 读/写代码路径 | 读取代码路径 | 无封装端到端样本 |
| ADTS AAC `.aac` | 上游有识别入口 | 未纳入已验证支持声明 | 未纳入已验证支持声明 | 读取代码路径 | 不等同于已验证的 AAC-in-M4A |
| Ogg FLAC `.oga` | 7 项读/写代码路径，Vorbis Comment | 读/写代码路径 | 读/写代码路径 | 读取代码路径 | 无封装端到端样本；`.oga` 也可能是 Vorbis |
| Ogg Speex `.spx` | 7 项读/写代码路径，Vorbis Comment | 读/写代码路径 | 读/写代码路径 | 读取代码路径 | 无封装端到端样本 |
| AIFF-C `.aifc`、`.afc` | 7 项读/写代码路径，ID3v2 | 读/写代码路径 | 读/写代码路径 | 读取代码路径 | 未验证压缩 AIFF 变体 |
| 其他 MP4 变体 `.mp4`、`.m4b`、`.m4r`、`.m4p`、`.m4v`、`.3g2` | 7 项读/写代码路径，MP4 标签 | 读/写代码路径 | 读/写代码路径 | 读取代码路径 | 未逐一验证编码、保护机制或多轨文件 |
| Matroska `.mka`、`.mkv`、`.webm` | 7 项可读；写入代码路径开放但未验证 | 读取 SimpleTag 代码路径；**不可写** | 读取图片附件代码路径；**不可写** | 可读 | 仅 `.mka` 无标签样本的只读基线；未验证已有歌词/封面、多语言/多轨标签与写入保留性 |
| Tracker `.mod`、`.module`、`.nst`、`.wow`、`.it`、`.s3m`、`.xm` | 仅标题、评论可读；其余为空/0；**全部写入拒绝** | 无专用歌词字段 | 不支持 | 通道数可读；比特率、采样率、时长为 0 | 无封装端到端样本；评论含定时 LRC 时可走兼容读取 |
| Shorten `.shn` | 无基本标签；不可写 | 不支持 | 不支持 | 读取代码路径 | 无封装端到端样本 |

### 歌词的存储与解析

| 标签体系 | 首选读取来源 | `setLyrics` 写入位置 | SYLT |
| --- | --- | --- | --- |
| ID3v2（MP3、WAV、AIFF、TTA、DSF、DSDIFF） | USLT 文本 | 默认描述的 USLT | 只读，不生成或修改 SYLT |
| FLAC / Ogg Vorbis / Opus / Speex / Ogg FLAC | Vorbis Comment 歌词字段 | `LYRICS` | FLAC 旧 ID3v2 标签可作为读取回退 |
| APEv2（APE、MPC、WavPack；MP3 可兼容读取） | APE 歌词字段 | `LYRICS`；MP3 写入 ID3v2 | 不适用 |
| MP4 | `©lyr`，以及已知歌词 freeform 字段 | `©lyr` | 不适用 |
| ASF | `WM/Lyrics` 等歌词属性 | `WM/Lyrics` | 不适用 |
| Matroska | 映射为歌词的 SimpleTag | 不支持 | 不适用 |

`setLyrics` 保存传入的纯文本或 LRC 原文，不将 LRC 转换成二进制 SYLT，也不写入评论。`setLyris` 与它行为相同。

歌词读取先尝试原生字段，再尝试兼容来源；不会把多个语言版本拼接成一条歌词。ID3v2 优先选择描述为空或 `LYRICS` 的 USLT，没有可用内容时再尝试其他描述、SYLT 等来源。普通评论不会被当作歌词；仅含可识别时间戳的 LRC 评论可以作为旧文件的末级兼容来源。

兼容歌词键包括 `LYRICS`、`UNSYNCEDLYRICS`、`LYRICS_UNSYNCR`、`UNSYNCHRONIZEDLYRICS`、`SYNCEDLYRICS`、`SYNCHRONIZEDLYRICS`，匹配时忽略大小写、空格、下划线和连字符；只读取这些明确的歌词键，不扫描任意文本字段。MP4 的 `----:<命名空间>:<歌词键>` 可作回退，WAV 还可读取明确标为歌词的 RIFF INFO `ILYR`。空白或仅有无正文时间戳的候选不会遮蔽后面的可用歌词。

传入空字符串会清除主要的原生歌词字段，但不会删除 SYLT、其他描述的 USLT、其他标签容器或兼容别名。因此，“清除主歌词”不等于“删除文件内所有可能的歌词来源”；之后读取仍可能返回保留下来的备用歌词。

`parseSynchronizedLyrics` 接收字符串，不会自动寻找外部 `.lrc` 文件。支持纯文本、`[mm:ss]` / `[mm:ss.xx]` / `[mm:ss.xxx]` 时间戳、同一行多个时间戳、乱序与重复时间戳，以及 `[ar:]`、`[ti:]`、`[al:]`、`[by:]`、`[offset:]`、`[length:]` 等元信息。时间戳输出单位为毫秒；相同时间戳共享下一不同时间作为结束时间，最后一组默认持续 3 秒。`offset` 原样存储，由调用方决定如何应用。

存在定时行时，模型返回定时行集合，不混入无时间戳的正文行；没有定时行时返回纯文本行并设置 `isNoneTime = YES`。`fullLyric` 和 `realLyric` 是解析出的同一行文本，不自动识别翻译或逐字歌词。SYLT 支持毫秒时间戳；MPEG 帧时间戳仅在可取得 MPEG 音频参数时转换。SYLT 仅验证了 MP3 样本，不能将该结果外推至全部 ID3v2 容器。

### 封面的读取与替换

- 有图片角色的格式优先读取有效的正面封面，没有时取第一张有效图片。不会把 GEOB 等无关二进制字段当作封面。
- `coverArtData` 和 `extractCoverArtDataFromURL:` 保留编码后的原始字节；`coverArt` 和图像读取接口生成最长边不超过 2048 像素的缩略图。
- Data 写入支持 JPEG、PNG、GIF、BMP，不重新编码；平台图像写入编码为 PNG。读取还可接受系统 ImageIO 能识别的其他图片类型，实际解码能力取决于系统版本。自动回归的图片字节往返覆盖 JPEG、PNG，不代表所有图片类型均已逐一验证。
- 写入有角色的图片集合时替换正面封面、保留其他角色；MP4 的 `covr` 没有角色，替换第一张并保留其余图片。接口不提供枚举全部图片或删除全部图片的操作。
- FLAC 写入原生 PICTURE 块；读取可回退到旧 Vorbis Comment 图片和 ID3v2 APIC。MP3 写入 ID3v2 APIC，并可兼容读取 APE 封面；不会为同步封面而覆写另一套标签。

## 写入边界与数据保护

- 所有写入方法都必须检查返回值。无效、空、非本地、只读文件及负数年份/音轨会失败；Tracker 写入、Matroska 歌词/封面写入明确返回失败。
- 基本标签与歌词使用格式的原生标签；只有旧 ID3v1 的 APE、MPC、WavPack、TTA 等文件会在需要时创建原生标签，而不是将 Unicode 内容写进受限的 ID3v1。
- MPEG 写入仅保存 ID3v2，不向 ID3v1/APE 自动复制字段。其他格式若存在会被上游保存截断的 ID3v1.0 长评论（29～30 字符且无音轨），会拒绝保存；不以丢失旧评论尾部换取“成功”。
- 单张封面最多 32 MiB、1 亿像素；平台图像写入的宽高各不超过 10,000 像素。FLAC 元数据块还受格式自身 24 位长度上限约束，不能将 32 MiB 的通用限制理解为可写入同样大小的 FLAC 图片。
- 歌词 UTF-8 文本最多 4 MiB，解析最多 20,000 个行事件；分词也有上限。这些是封装接口的限制，不是底层文件解析器的严格总内存上限。
- 同一路径在进程内串行读写；这不协调其他进程、文件硬链接或外部编辑器。TagLib 原地保存，不提供事务、崩溃回滚或断电恢复。写入重要文件前请保留备份，特别是未验证的格式或复杂混合标签文件。
- 回归验证了多种混合标签、非目标封面及解码后音频内容的保留，但不承诺整个文件逐字节不变，也不承诺任意未知标签在所有容器中无损往返。

## 构建与回归验证

安装完整 Xcode 后，在仓库根目录运行：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build
pod ipc spec WaketagLibKit.podspec
bash scripts/run-regression-tests.sh
bash scripts/check-apple-platforms.sh
```

回归脚本需要 `ffmpeg`，默认启用 AddressSanitizer 和 UndefinedBehaviorSanitizer。可通过 `FFMPEG`、`JOBS`、`DEVELOPER_DIR` 指定工具和并行度。它只生成临时音频并在副本上验证，不扫描或修改现有音乐库。缺少编码器或解码器会明确报告跳过；不能将跳过记为通过。

默认生成表中的 10 种常见格式。可选上游样本额外覆盖 DSF、DSDIFF、APE、Musepack 的写入与重读、Matroska 的只读基线及历史损坏文件：

```sh
TAGLIB_TEST_DATA=/path/to/taglib-2.3.2/tests/data \
  bash scripts/run-regression-tests.sh
```

详细用例、样本校验、混合标签检查和解码后 PCM 哈希验证见 [Tests/README.md](Tests/README.md)。这些测试并不穷尽所有第三方编码器和标签变体。

平台脚本使用临时 Xcode workspace 编译 macOS、iOS、Mac Catalyst、tvOS、watchOS 的完整 SwiftPM 产品，关闭代码签名，并打印构建日志位置。SDK 编译通过和真实设备运行验证是不同层面的保证。

## 许可证

Objective-C 封装沿用根目录 [LICENSE](LICENSE) 中的 MIT 许可及原有版权声明。TagLib 使用其上游 LGPL 2.1 或 MPL 1.1 双许可；UTF8-CPP 使用其上游许可。分发时请保留仓库中的上游版权和许可证文件。
