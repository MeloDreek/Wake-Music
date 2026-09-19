# Exercise actual queue setters/start-selection logic against small model boundaries.
require 'tmpdir'
root = File.expand_path('../..', __dir__)
core = File.read(File.join(root, 'Mobie/Mobie/Base/Music/KakaMusicPlayer.swift'))
play = File.read(File.join(root, 'Mobie/Mobie/Base/Music/KakaMusicPlayer+Play.swift'))
def block(source, declaration)
  start = source.index(declaration) or raise "Missing #{declaration}"
  opening = source.index('{', start)
  depth = 0
  source[opening..].each_char.with_index do |char, index|
    depth += 1 if char == '{'
    depth -= 1 if char == '}'
    return source[start..(opening + index)] if depth.zero?
  end
  raise 'Unbalanced source'
end
parts = [block(core, 'var musicArray:'), block(core, 'var tempMusicArray:'),
         block(core, 'func normalizedQueue('), block(play, 'public func startPlayMusic(')]
raise 'Missing persisted-folder playback guard' unless play.include?('guard !model.isFolder() else {')
source = <<~SWIFT
  import Foundation
  struct MusicItemModel: Equatable {
      var identity: String
      var folder: Bool = false
      func uniqueID() -> String { identity }
      func isFolder() -> Bool { folder }
  }
  final class MusicConfigManager {
      static let shared = MusicConfigManager()
      var lastPlayTime = 12
  }
  final class Player {
      var queueItems: [MusicItemModel] = []
      var originalQueue: [MusicItemModel] = []
      var nextPlayMusic: MusicItemModel?
      var pendingShuffleRound: [String]?
      var playingMusic: MusicItemModel?
      var retired = 0
      var plays = 0
      func retirePlayback() { retired += 1 }
      func playlistSortTypeChanged() {}
      func play() { plays += 1 }
      #{parts.join("\n")}
  }
  @main enum FolderEntryRegression {
      static func main() throws {
          let player = Player()
          let empty = MusicItemModel(identity: "empty", folder: true)
          let full = MusicItemModel(identity: "full", folder: true)
          let a = MusicItemModel(identity: "a")
          let b = MusicItemModel(identity: "b")
          let mixed = [empty, a, full, b, a]
          player.startPlayMusic(musics: mixed, itemIndex: 3)
          precondition(player.playingMusic == b, "Keep tapped song, not the filtered index")
          precondition(player.musicArray == [a, b] && player.tempMusicArray == [a, b])
          for index in [-1, 0, 2, 5] { player.startPlayMusic(musics: mixed, itemIndex: index) }
          player.startPlayMusic(musics: [empty], itemIndex: 0)
          player.startPlayMusic(musics: [], itemIndex: 0)
          precondition(player.retired == 1 && player.plays == 1 && player.playingMusic == b)
          player.musicArray = [empty, full, a, a]
          player.tempMusicArray = [full, a, empty, a]
          precondition(player.musicArray == [a] && player.tempMusicArray == [a])
          player.musicArray.append(empty)
          player.tempMusicArray.append(full)
          precondition(player.musicArray == [a] && player.tempMusicArray == [a])
          player.musicArray = [empty, full]
          player.tempMusicArray = [empty, full]
          precondition(player.musicArray.isEmpty && player.tempMusicArray.isEmpty)
          // Optional read-only run against the user's simulator test folders.
          if CommandLine.arguments.count == 2 {
              let base = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
              let urls = try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: [.isDirectoryKey])
              let models = try urls.map { url in
                  MusicItemModel(identity: url.lastPathComponent,
                                 folder: try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
              }
              for name in ["MMM", "PPP"] {
                  precondition(models.contains { $0.identity == name && $0.folder })
              }
              let emptyContents = try FileManager.default.contentsOfDirectory(atPath: base.appendingPathComponent("PPP").path)
              precondition(emptyContents.isEmpty)
              player.musicArray = models
              player.tempMusicArray = models
              precondition(!player.musicArray.contains { $0.folder })
              precondition(!player.tempMusicArray.contains { $0.folder })
              print("PASS_SIMULATOR_FOLDERS MMM/nonempty PPP/empty excluded without modifying files")
          }
          print("PASS_QUEUE_FOLDER_ENTRY selected identity, empty folders, duplicates, restored/original queue")
      }
  }
SWIFT
Dir.mktmpdir('queue-folder-', '/private/tmp') do |dir|
  path = File.join(dir, 'Entry.swift')
  File.write(path, source)
  ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
  abort 'compile failed' unless system('xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', File.join(dir, 'modules'),
    File.join(root, 'Mobie/Mobie/Base/Music/PlaybackQueue.swift'), path, '-o', File.join(dir, 'probe'))
  abort 'regression failed' unless system(File.join(dir, 'probe'), *ARGV)
end
