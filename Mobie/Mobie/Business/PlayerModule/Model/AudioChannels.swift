//
//  AudioChannels.swift
//  Mobie
//
//  Created by 张文 on 10/10/24.
//

import SmartCodable
import AppGroupKit

extension AudioChannels {
    func formatStr() -> String {
        switch self {
        case .mono:
            return "Mono".localStr()
        case .stereo:
            return "Stereo".localStr()
        case .surround51:
            return "5.1 Surround".localStr()
        case .surround71:
            return "7.1 Surround".localStr()
        case .atmos:
            return "Dolby Atmos".localStr()
        }
    }
}
