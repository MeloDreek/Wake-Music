#!/usr/bin/env ruby
require 'tmpdir'
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
