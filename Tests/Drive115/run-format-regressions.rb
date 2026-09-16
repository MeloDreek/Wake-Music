#!/usr/bin/env ruby
require 'tmpdir'
require 'json'
root = File.expand_path('../..', __dir__)
ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
build = Dir.mktmpdir('wakemusic-115-format-tests-')
model = File.read(File.join(root, 'LocalSDK/AppGroupKit/Classes/CoreData/CloudDrive/Drive115FileModel.swift'))
source = model.lines.reject { |line| line == "import SmartCodable\n" }.join
test_file = File.join(build, 'Drive115FormatRegression.swift')
File.write(test_file, File.read(File.join(__dir__, 'Drive115FormatRegression.swift')) + "\n" + source)
audio = File.join(root, 'LocalSDK/AppGroupKit/Classes/Const/AudioExtension.swift')
abort 'Compilation failed' unless system('xcrun', '--sdk', 'macosx', 'swiftc', '-swift-version', '5', '-parse-as-library', '-module-cache-path', File.join(build, 'modules'), audio, test_file, '-o', File.join(build, 'tests'))
abort 'Regression failed' unless system(File.join(build, 'tests'))

# Guard the integration points without starting the player or accessing accounts.
checks = {
  'LocalSDK/AppGroupKit/Classes/CoreData/Music/MusicItemModel+Extension.swift' => 'return drive115Model.isMusic() ? .music : .other',
  'Mobie/Mobie/Business/MusicModule/View/MusicTableViewCell.swift' => 'isSupportType = drive115Model.isMusic()',
  'Mobie/Mobie/Business/ConnectModule/Controller/Drive115FileListController.swift' => 'guard subModel.drive115Model?.isMusic() == true',
  'Mobie/Mobie/Base/Music/KakaMusicPlayer+Play.swift' => 'if model.drive115Model?.isUnsupportedStreamingAudio == true',
  'Mobie/Mobie/Base/Music/KakaMusicPlayer.swift' => 'guard nextPlayMusic.drive115Model?.isUnsupportedStreamingAudio != true'
}
checks.each { |file, snippet| abort "Missing 115 policy wiring: #{file}" unless File.read(File.join(root, file)).include?(snippet) }
puts "#{checks.count} 115 policy wiring checks passed"

list = File.read(File.join(root, 'Mobie/Mobie/Business/ConnectModule/Controller/Drive115FileListController.swift'))
play = list.split('func playWithMusic(_ subModel: MusicItemModel)', 2).last.split('// 下载', 2).first
abort 'DSD must prompt before changing playback' unless play.index('show115StreamingDownloadAlert(for: subModel)') < play.index('let isPlaying')
abort 'Exclude DSD from automatic streaming queue' unless play.include?('$0.fileType() == .music && $0.drive115Model?.isUnsupportedStreamingAudio != true')
alerts = File.read(File.join(root, 'Mobie/Mobie/Base/BaseUI/UIApplication+Top.swift'))
helper = alerts.split('func show115StreamingDownloadAlert', 2).last.split('public func isPresent', 2).first
abort 'Download must enqueue only after confirmation' unless helper.match?(/title: "Download"\.localStr\(\), style: \.default\).*?DownloadManager.shared.addMusicModel\(\[model\]\)/m)
abort 'Cancel action missing' unless helper.include?('title: "Cancel".localStr(), style: .cancel')
abort 'Unexpected extra destination picker' if helper.include?('SelectPlaylistController')
player = File.read(File.join(root, 'Mobie/Mobie/Base/Music/KakaMusicPlayer+Play.swift'))
abort 'Persisted queue needs the same download prompt' unless player.include?('show115StreamingDownloadAlert(for: model)')
artwork = File.read(File.join(root, 'Mobie/Mobie/Base/Core/Extension/MusicItemModel+Kaka.swift')).split('self.fileSourceType == .from115Drive', 2).last
abort 'Keep format artwork for 115 music' unless artwork.include?('else if drive115Model.isMusic()') && artwork.include?('KakaImage(named: "\(fileExtension)_icon")')
catalog = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings')))['strings']
key = '115 Drive does not support streaming DSF or DFF files. Download them to your device to play them.'
locales = catalog.fetch('Download').fetch('localizations').keys
locales.each do |locale|
  unit = catalog.fetch(key).fetch('localizations').fetch(locale).fetch('stringUnit')
  abort "Missing translation: #{locale}" unless unit['state'] == 'translated' && unit['value'].include?('DSF') && unit['value'].include?('DFF')
end
puts "Download prompt, playlist, artwork wiring and #{locales.count} translations passed"
