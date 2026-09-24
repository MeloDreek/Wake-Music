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

        let groups = [AudioLevelType.SACD, .lossless, .normal, .other]
        let grouped = groups.flatMap { $0.audioArray() }
        check(Set(grouped) == Set(AudioExtensionType.allCases), "Every suffix is shown in a format group")
        check(grouped.count == AudioExtensionType.allCases.count, "Each suffix appears only once")
        check(AudioLevelType.SACD.rawValue == 0 && AudioLevelType.lossless.rawValue == 1 && AudioLevelType.normal.rawValue == 2, "Existing raw values stay stable")
        for item: AudioExtensionType in [.wav, .aif, .aiff, .aifc, .m4a, .wma, .asf, .wv, .mka, .mod] {
            check(AudioLevelType.other.audioArray().contains(item), "Do not promise source quality from container: \(item)")
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
        print("\(checks) audio-extension regression checks passed")
    }
}
