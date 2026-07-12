//
//  AudioExtension.swift
//  AppGroupKit
//
//  Created by 张文 on 10/17/24.
//

import Foundation
import UniformTypeIdentifiers

public enum AudioLevelType: Int {
    case SACD = 0
    case lossless = 1
    case normal = 2
    
    public func audioArray() -> [AudioExtensionType] {
        switch self {
        case .SACD:
            return [.dsd, .dsf, .dff]
        case .lossless:
            return [.dts, .flac, .m4a, .wav, .ape, .asf, .aifc, .aiff, .alac, .aif, .au, .caf, .tta, .wma, .wave, .wv, .wvc]
        case .normal:
            return [.mp3, .aac, .ogg, .opus, .mod, .xm, .mqa, .gp3, .s3m, .m4r, .ogv, .amr]
        }
    }
    
    public func videoArray() -> [VideoExtensionType] {
        return VideoExtensionType.allCases
    }
    
}

public enum AudioExtensionType: String, CaseIterable {
    
    // 高分辨率无损格式
    case dsd = "dsd" // Direct Stream Digital
    case dsf = "dsf" // DSD Stream File
    case dff = "dff" // DSD Interchange File Format
    
    // 有损格式
    case mp3 = "mp3"
    case aac = "aac"
    case ogg = "ogg"
    case opus = "opus"
    case mod = "mod"
    case xm = "xm"
    case mqa = "mqa"
    case gp3 = "3gp"
    case s3m = "s3m"
    case m4r = "m4r"
    case ogv = "ogv"
    case amr = "amr"
    
    // 无损格式
    case flac = "flac"
    case wav = "wav"
    case alac = "alac"
    case m4a = "m4a"
    case asf = "asf"
    case dts = "dts"
    case ape = "ape" // Monkey's Audio
    case aif = "aif"
    case aifc = "aifc"
    case aiff = "aiff"
    case au = "au"
    case caf = "caf"
    case tta = "tta"
    case wma = "wma" // 包括有和无损
    case wave = "wave"
    case wv = "wv"
    case wvc = "wvc" // WavPack 的纠错文件，通常不单独使用
    
    public static func premiumExtensions() -> [String] {
        let extensions: [AudioExtensionType] = [.dsd, .dsf, .dff, .ape, .dts, .ape, .opus]
        return extensions.map { $0.rawValue }
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
        
    /// 支持的音频后缀
    public static var audioSuffixs: [String] {
        get {
            let array: [AudioExtensionType] = AudioLevelType.SACD.audioArray() + AudioLevelType.lossless.audioArray() + AudioLevelType.normal.audioArray()
            
            return array.map { $0.rawValue }
        }
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

