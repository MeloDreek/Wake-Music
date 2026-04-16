//
//  AIType.swift
//  Mobie
//
//  Created by 张文 on 5/8/25.
//

import KakaFoundation

enum AIType: Int {
    case chatGPT = 0
    case Gemini = 1
    case Llama = 2
    case deepseek = 3
    case doubao = 4
    case kimi = 5
    
    static func allTypes() -> [AIType] {
        let isChinese = PhoneSetManager.formatLanguage() == .chinese_simplified || PhoneSetManager.localPhoneCountry() == .chinese
        let storageArray: [AIType] = isChinese ? [.deepseek, .doubao, .kimi] : [.chatGPT, .Gemini, .deepseek, .Llama]
        return storageArray
    }
    
    func iconImage() -> UIImage? {
        switch self {
        case .chatGPT:
            return Reasource.named("ai_chatgpt")
        case .deepseek:
            return Reasource.named("ai_deepseek")
        case .Gemini:
            return Reasource.named("ai_gemini")
        case .Llama:
            return Reasource.named("ai_llama")
        case .doubao:
            return Reasource.named("ai_doubao")
        case .kimi:
            return Reasource.named("ai_kimi")
        }
    }
    
    func titleStr() -> String {
        switch self {
        case .chatGPT:
            return "ChatGPT"
        case .Gemini:
            return "Gemini"
        case .deepseek:
            return "DeepSeek"
        case .Llama:
            return "Llama"
        case .doubao:
            return "豆包"
        case .kimi:
            return "Kimi"
        }
    }
    
    func websiteURL() -> (URL?, URL?) {
        switch self {
        case .chatGPT:
            return (URL(string: "chatgpt://"), URL(string: "https://chat.openai.com/"))
        case .Gemini:
            return (URL(string: "gemini://"), URL(string: "https://gemini.google.com/"))
        case .deepseek:
            return (URL(string: "deepseek://"), URL(string: "https://chat.deepseek.com/"))
        case .Llama:
            return (URL(string: "llama://"), URL(string: "https://www.meta.ai/"))
        case .doubao:
            return (URL(string: "doubao://"), URL(string: "https://www.doubao.com/chat/"))
        case .kimi:
            return (URL(string: "kimi://"), URL(string: "https://kimi.ai/"))
        }
    }
    
}

