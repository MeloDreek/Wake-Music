//
//  AudioFormatEnum.swift
//  AppGroupKit
//
//  Created by 张文 on 10/15/24.
//

import SmartCodable
import AVFoundation

public enum AudioFormatEnum: String, SmartCaseDefaultable {
    case mp3 = "MP3"
    case aac = "AAC"

    case alac = "ALAC" // Apple Lossless Audio Codec
    case wav = "WAV"

    // 编码器
    public func encoderStr() -> String {
        switch self {
        case .mp3:
            return "libmp3lame"
        case .aac:
            return "aac"
            
        case .alac:
            return "alac"
        case .wav:
            return "pcm_s16le"
        }
    }

    // 文件后缀名
    public func suffixName() -> String {
        switch self {
        case .mp3:
            return "mp3"
        case .aac:
            return "aac"
            
        case .alac:
            return "m4a" // 常用的封装格式
        case .wav:
            return "wav"
        }
    }
    
    /// 文件输出类型
    public func outputFileType() -> AVFileType {
        switch self {
        case .mp3:
            return .mp3
        case .aac:
            return .ac3
        case .alac:
            return .m4a
        case .wav:
            return .wav
        }
    }
    
}
