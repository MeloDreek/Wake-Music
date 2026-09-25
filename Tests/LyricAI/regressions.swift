// Executed with the production LyricAIProvider source by run-tests.sh.
var checks = 0
func check(_ result: @autoclosure () -> Bool, _ message: String) {
    precondition(result(), message)
    checks += 1
}
for locale in ["zh-Hans", "zh-Hans-CN", "zh_Hans_SG", "ZH-HANS"] {
    check(LyricAIProvider.available(language: locale) == LyricAIProvider.allCases, "Simplified Chinese: \(locale)")
}
for locale in ["en", "en-CN", "zh-Hant", "zh-Hant-CN", "zh-HK", "zh-TW", "ja", "ar", ""] {
    check(LyricAIProvider.available(language: locale) == [.chatGPT, .gemini, .grok, .claude], "No regional inference: \(locale)")
}
check(Set(LyricAIProvider.allCases.map(\.title)).count == 7, "Seven distinct services")
for provider in LyricAIProvider.allCases {
    check(provider.url.scheme == "https", "HTTPS only")
    check(provider.url.query == nil && provider.url.fragment == nil, "Never transmit prompt in URL")
    check(provider.appURL.scheme != "https" && provider.appURL.scheme != "http" && provider.appURL.query == nil, "Native schemes never send the prompt")
}
check(LyricAIProvider.durationText(seconds: 233, fallback: 999) == "03:53", "Prefer actual file duration")
check(LyricAIProvider.durationText(seconds: 0, fallback: 65) == "01:05", "Use known duration if needed")
check(LyricAIProvider.durationText(seconds: 3601, fallback: 0) == "1:00:01", "Long audio")
check(LyricAIProvider.durationText(seconds: 0, fallback: 0) == nil, "Unknown is not zero-length")
check(LyricAIProvider.durationText(seconds: -1, fallback: -1) == nil, "Reject invalid durations")
for empty: String? in [nil, "", " \n\t", "　"] {
    check(LyricAIProvider.embeddedTags(title: empty, artist: "Artist") == nil, "Require embedded title")
    check(LyricAIProvider.embeddedTags(title: "Title", artist: empty) == nil, "Require embedded artist")
}
let tags = LyricAIProvider.embeddedTags(title: "  Song 100% %@ 🎵\n", artist: " A / B ")!
check(tags.title == "Song 100% %@ 🎵" && tags.artist == "A / B", "Preserve tag contents while trimming whitespace")

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let data = try Data(contentsOf: root.appendingPathComponent("Mobie/Mobie/System/Localizable.xcstrings"))
let catalog = try JSONSerialization.jsonObject(with: data) as! [String: Any]
let strings = catalog["strings"] as! [String: [String: Any]]
let keys = ["LyricAI.Search", "LyricAI.MissingMetadata", "LyricAI.Prompt", "LyricAI.CopyAndOpen", "LyricAI.OpenFailed", "LyricAI.Workflow", "LyricAI.PersonalUse"]
let expectedLocales = Set((strings["Super Lossless"]!["localizations"] as! [String: Any]).keys)
for key in keys {
    let translations = strings[key]!["localizations"] as! [String: [String: Any]]
    check(Set(translations.keys) == expectedLocales, "Complete localization: \(key)")
    for (locale, translation) in translations {
        let unit = translation["stringUnit"] as! [String: String]
        let text = unit["value"]!
        check(unit["state"] == "translated" && !text.isEmpty, "Translation: \(key)/\(locale)")
        if key == "LyricAI.Prompt" {
            check(text.components(separatedBy: "%@").count == 3, "Two metadata placeholders")
            let prompt = String(format: text, tags.title, tags.artist)
            check(prompt.contains(tags.title) && prompt.contains(tags.artist) && prompt.contains("[mm:ss.xx]"), "Valid localized LRC request")
        } else if key == "LyricAI.PersonalUse" {
            check(text.components(separatedBy: "%@").count == 2, "Duration placeholder")
            check(String(format: text, "03:53").contains("03:53"), "Localized duration")
        } else if key == "LyricAI.CopyAndOpen" {
            check(text.components(separatedBy: "%@").count == 2, "One provider placeholder")
        }
    }
}
let source = try String(contentsOf: root.appendingPathComponent("Mobie/Mobie/Business/MusicModule/Controller/LyricEditorViewController.swift"), encoding: .utf8)
check(source.contains("return section == 0 ? 1 : 3"), "One editor plus three action rows")
check(source.contains("indexPath.section == 1 && indexPath.row == 0") && source.contains("indexPath.section == 1 && indexPath.row == 1"), "Paste and import stay in the same section")
check(source.contains("readMetadata(withFileURL: url, read: .basic)"), "Read actual embedded tags without artwork")
check(source.contains("menuButton.showsMenuAsPrimaryAction = true"), "Tap opens UIMenu")
check(source.contains("open(provider.appURL, options: [:])"), "Attempt native scheme without opening browser first")
check(source.contains("guard !opened else { return }"), "Browser fallback only when native opening fails")
check(source.contains("#if targetEnvironment(macCatalyst)\n        // Apple"), "Separate Mac browser flow")
check(source.components(separatedBy: "accessoryType = .disclosureIndicator").count == 3, "Both normal action cells and AI menu cell show chevrons")
print("\(checks) lyric AI regression checks passed")
