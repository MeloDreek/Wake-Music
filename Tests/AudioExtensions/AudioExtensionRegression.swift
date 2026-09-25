import Foundation

@main
enum AudioExtensionRegression {
    static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            precondition(condition(), message)
            checks += 1
        }

        let upstream = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let body = upstream.components(separatedBy: "StringList FileRef::defaultFileExtensions()")[1]
            .components(separatedBy: "return l;")[0]
        let pattern = try NSRegularExpression(pattern: #"l\.append\("([^"]+)"\)"#)
        let range = NSRange(body.startIndex..., in: body)
        let expected = pattern.matches(in: body, range: range).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: body) else { return nil }
            return String(body[range])
        }
        check(expected.count == 40, "Review upstream parser changes rather than silently changing the advertised count")
        check(Set(AudioExtension.taglibMetadataSuffixs) == Set(expected), "Metadata support must match pinned TagLib extensions exactly")
        check(AudioExtension.audioSuffixs.count == 35, "35 audio-oriented suffixes, not 40 audio formats")
        check(Set(AudioExtension.audioSuffixs).count == AudioExtension.audioSuffixs.count, "No duplicate audio suffixes")
        check(Set(AudioExtension.playableAudioSuffixs).count == AudioExtension.playableAudioSuffixs.count, "No duplicate playback suffixes")
        check(Set(AudioExtension.audioSuffixs).isDisjoint(with: AudioExtension.taglibVideoContainerSuffixs), "Keep video containers separate")
        check(Set(AudioExtension.taglibVideoContainerSuffixs).isSubset(of: AudioExtension.videoSuffixs), "Video metadata containers remain videos")

        let groups = AudioLevelType.allCases
        check(groups == [.SACD, .lossless, .normal], "Exactly three ordered display groups")
        let grouped = groups.flatMap { $0.audioArray() }
        check(Set(grouped) == Set(AudioExtensionType.allCases), "Every suffix is shown in a format group")
        check(grouped.count == AudioExtensionType.allCases.count, "Each suffix appears only once")
        check(AudioLevelType.SACD.rawValue == 0 && AudioLevelType.lossless.rawValue == 1 && AudioLevelType.normal.rawValue == 2, "Existing raw values stay stable")
        for item: AudioExtensionType in [.wav, .aif, .aiff, .aifc, .afc, .m4a, .m4b, .m4r, .wma, .asf, .wv, .mka, .oga] {
            check(AudioLevelType.lossless.audioArray().contains(item), "Show lossless-capable formats: \(item)")
            check(item.supportCodecHint != nil, "Explain ambiguous format: \(item)")
        }
        check(AudioLevelType.SACD.audioArray() == [.dsf, .dff, .dsdiff], "Keep DSD aliases together")
        check(AudioLevelType.normal.audioArray().contains(.m4p), "Protected AAC is not ALAC")
        check(AudioExtensionType.m4a.supportCodecHint == "AAC / ALAC", "Explain ALAC's actual file extension")
        for item: AudioExtensionType in [.mod, .module, .nst, .wow, .it, .xm, .s3m] {
            check(item.supportCodecHint == "Tracker", "Identify tracker modules explicitly")
        }
        for suffix in AudioExtension.audioSuffixs {
            check(AudioExtension.isPlayableAudioExtension(" .\(suffix.uppercased()) "), "Case and provider whitespace normalization: \(suffix)")
            check(URL(fileURLWithPath: "/test/Song.\(suffix.uppercased())").isSupportMusicFile(false), "Local scanner accepts metadata suffix: \(suffix)")
        }
        for suffix in AudioExtension.playbackOnlyAudioSuffixs {
            check(!AudioExtension.taglibMetadataSuffixs.contains(suffix), "Legacy playback must not claim metadata support: \(suffix)")
            check(URL(fileURLWithPath: "/test/Song.\(suffix)").isSupportMusicFile(false), "Do not hide old library files: \(suffix)")
        }
        for suffix in ["wvc", "ogv", "mp4", "m4v", "3g2", "mkv", "webm", "txt", "ncm", ""] {
            check(!AudioExtension.isPlayableAudioExtension(suffix), "Do not mistake sidecars/videos/unsupported files for songs: \(suffix)")
        }
        check(URL(fileURLWithPath: "/test/Song.LRC").isSupportMusicFile(true), "Allow requested LRC import")
        check(!URL(fileURLWithPath: "/test/Song.LRC").isSupportMusicFile(false), "LRC is not a playable song")
        check(Set(AudioExtensionType.supportAutoEditArray).isSubset(of: AudioExtensionType.allCases), "Auto-edit candidates have a metadata parser")
        check(!AudioExtensionType.supportAutoEditArray.contains(.m4p), "Do not promise system fingerprint decoding for protected media")
        let premium = AudioExtensionType.premiumExtensions()
        check(Set(premium).count == premium.count, "Remove duplicate premium APE entry")
        check(premium.contains("dsdiff") && premium.contains("dts"), "DSDIFF alias and legacy DTS keep matching entitlements")

        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let catalogURL = root.appendingPathComponent("Mobie/Mobie/System/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as! [String: Any]
        let strings = catalog["strings"] as! [String: [String: Any]]
        func translations(_ key: String) -> [String: [String: Any]] {
            strings[key]!["localizations"] as! [String: [String: Any]]
        }
        let notes = translations("Formats.GroupingNote")
        check(Set(translations("Super Lossless").keys).isSubset(of: Set(notes.keys)), "Disclaimer covers all supported languages")
        for (locale, translation) in notes {
            let unit = translation["stringUnit"] as! [String: String]
            check(unit["state"] == "translated" && !(unit["value"] ?? "").isEmpty, "Translated grouping disclaimer: \(locale)")
        }
        for (key, title) in [("Super Lossless", "超级无损"), ("Lossless", "普通无损"), ("Lossy", "有损")] {
            let unit = translations(key)["zh-Hans"]!["stringUnit"] as! [String: String]
            check(unit["value"] == title, "Chinese section title: \(title)")
        }
        print("\(checks) audio-extension regression checks passed")
    }
}
