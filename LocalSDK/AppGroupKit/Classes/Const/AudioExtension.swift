//
//  AudioExtension.swift
//  AppGroupKit
//
//  Created by 张文 on 10/17/24.
//

import Foundation
import UniformTypeIdentifiers

/// Display groups, not an audio-quality detector. Containers can hold several
/// codecs, and tracker modules have no lossy/lossless quality tier.
public enum AudioLevelType: Int, CaseIterable {
    case SACD = 0
    case lossless = 1
    case normal = 2
    
    public func audioArray() -> [AudioExtensionType] {
        switch self {
        case .SACD:
            return [.dsf, .dff, .dsdiff]
        case .lossless:
            return [.flac, .wav, .aif, .aiff, .ape, .wv, .tta, .shn,
                    .m4a, .m4b, .m4r, .aifc, .afc, .wma, .asf, .mka, .oga]
        case .normal:
            return [.mp3, .mp2, .aac, .ogg, .opus, .spx, .mpc, .m4p,
                    .mod, .module, .nst, .wow, .it, .xm, .s3m]
        }
    }
    
    public func videoArray() -> [VideoExtensionType] {
        return VideoExtensionType.allCases
    }
    
}

/// Audio-oriented extensions registered by WaketagLibKit 2.3.3 / TagLib 2.3.2.
/// This is metadata parser coverage, not a promise of every tag's read/write
/// capability or every codec's playback support. Video-oriented containers are
/// kept separate in AudioExtension.taglibVideoContainerSuffixs.
public enum AudioExtensionType: String, CaseIterable {
    // DSD containers
    case dsf = "dsf" // DSD Stream File
    case dff = "dff" // DSD Interchange File Format
    case dsdiff = "dsdiff"

    // MPEG / Ogg / Musepack
    case mp3 = "mp3"
    case mp2 = "mp2"
    case aac = "aac"
    case ogg = "ogg"
    case oga = "oga"
    case opus = "opus"
    case spx = "spx"
    case mpc = "mpc"

    // Tracker formats: readable metadata; tag writing is not supported.
    case mod = "mod"
    case module = "module"
    case nst = "nst"
    case wow = "wow"
    case it = "it"
    case xm = "xm"
    case s3m = "s3m"

    // Audio containers (quality depends on the enclosed codec)
    case m4a = "m4a"
    case m4b = "m4b"
    case m4p = "m4p"
    case m4r = "m4r"
    case mka = "mka"
    case wav = "wav"
    case asf = "asf"
    case aif = "aif"
    case afc = "afc"
    case aifc = "aifc"
    case aiff = "aiff"
    case wma = "wma" // 包括有和无损
    case wv = "wv"

    // Lossless codecs
    case flac = "flac"
    case ape = "ape"
    case tta = "tta"
    case shn = "shn"

    /// Codec hints for ambiguous containers; these are technical names, not
    /// claims about a particular file or a replacement for stream inspection.
    public var supportCodecHint: String? {
        switch self {
        case .m4a, .m4b, .m4r: return "AAC / ALAC"
        case .m4p: return "AAC · DRM"
        case .wav: return "PCM / DTS / …"
        case .aif, .aiff: return "PCM"
        case .afc, .aifc: return "PCM / …"
        case .wma, .asf: return "WMA / WMA Lossless"
        case .mka: return "FLAC / PCM / AAC / …"
        case .oga, .ogg: return "FLAC / Vorbis / …"
        case .wv: return "WavPack"
        case .mod, .module, .nst, .wow, .it, .xm, .s3m: return "Tracker"
        default: return nil
        }
    }
    
    public static func premiumExtensions() -> [String] {
        let extensions: [AudioExtensionType] = [.dsf, .dff, .dsdiff, .ape, .opus]
        // Preserve the existing playback entitlement for legacy DSD/DTS files.
        return extensions.map { $0.rawValue } + ["dsd", "dts"]
    }
    
    /// Common system-decoder candidates for fingerprinting and tag editing.
    /// Actual codec support is checked when opening the file, not by suffix.
    public static var supportAutoEditArray: [AudioExtensionType] {
        return [.mp3, .aac, .flac, .wav, .m4a, .m4b, .m4r, .aif, .aiff, .aifc, .afc]
    }
}

public enum VideoExtensionType: String, CaseIterable {
    
    // 常见视频格式
    case mkv = "mkv" // Matroska Video
    case webm = "webm" // WebM Video
    case mp4 = "mp4" // MPEG-4 Video
    case mov = "mov" // QuickTime Movie
    case avi = "avi" // Audio Video Interleave
    case flv = "flv" // Flash Video
    case m4v = "m4v" // MPEG-4 Video with Video
    case gp2 = "3g2" // 3GPP2 audio/video container
    case ts = "ts" // MPEG Transport Stream
    case iso = "iso"
    
    // 其他视频格式
    case wmv = "wmv" // Windows Media Video
    case mpg = "mpg" // MPEG Video
    case mpeg = "mpeg" // MPEG Video
    case rm = "rm" // RealMedia
    case vob = "vob" // Video Object
    case ogv = "ogv" // Ogg Video
    case dvr = "dvr" // DVR-MS
    case hevc = "hevc" // High Efficiency Video Coding

}

public enum ImageExtensionType: String, CaseIterable {
    
    case png = "png"
    case jpg = "jpg"
    case jpeg = "jpeg"
    case gif = "gif"
    case webp = "webp"
    
}

public class AudioExtension {
    
    /// 支持的文件类型
    public static let videoUTTypes: [UTType] = [.movie, .video, .mpeg2Video, .mpeg, .mpeg4Movie, .appleProtectedMPEG4Video, .quickTimeMovie, .mpeg2TransportStream, .avi]
        
    /// Audio-oriented metadata extensions, used by format counts and UI.
    public static let audioSuffixs = AudioExtensionType.allCases.map(\.rawValue)

    /// These TagLib containers may contain video; do not classify them as
    /// ordinary music files just because TagLib can read their metadata.
    public static let taglibVideoContainerSuffixs = ["3g2", "mp4", "m4v", "mkv", "webm"]

    /// Exact defaultFileExtensions() coverage of the pinned WaketagLibKit.
    public static let taglibMetadataSuffixs = audioSuffixs + taglibVideoContainerSuffixs

    /// Previously accepted playback-only extensions. Keep existing libraries,
    /// downloads and remote listings working without advertising metadata
    /// support that WaketagLibKit does not declare. WVC is a correction sidecar,
    /// and OGV remains a video format, so neither belongs in this list.
    public static let playbackOnlyAudioSuffixs = ["dsd", "dts", "alac", "au", "caf", "wave", "mqa", "3gp", "amr"]
    public static let playableAudioSuffixs = audioSuffixs + playbackOnlyAudioSuffixs

    public static func isPlayableAudioExtension(_ suffix: String) -> Bool {
        let normalized = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
        return playableAudioSuffixs.contains(normalized)
    }
    
    /// 支持的视频格式
    public static var videoSuffixs: [String] {
        get {
            let array: [VideoExtensionType] = VideoExtensionType.allCases
            
            return array.map { $0.rawValue }
        }
    }
        
    // 禁止的音频格式
    public static let forbiddenExtensions: [String] = ["ncm", "kgm", "kwm", "band"]
    
}
