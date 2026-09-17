#!/usr/bin/env ruby
# Execute the actual app's transition methods against a deterministic, delayed fake engine.
require 'tmpdir'
require 'fileutils'
root = File.expand_path('../..', __dir__)
source = File.read(File.join(root, 'Mobie/Mobie/Base/Music/KakaMusicPlayer+Play.swift'))
names = %w[acceptsPlaybackRequest retirePlayback togglePlayback pause stop seek]
methods = names.map do |name|
  start = source.index("@MainActor func #{name}(") or abort "Missing method: #{name}"
  opening = source.index('{', start)
  depth = 1
  ending = opening + 1
  while depth > 0
    depth += 1 if source[ending] == '{'
    depth -= 1 if source[ending] == '}'
    ending += 1
  end
  source[start...ending]
end.join("\n")

%w[PlayControlDefaultView PlayControlTapeView].each do |view|
  code = File.read(File.join(root, "Mobie/Mobie/Business/PlayerModule/View/#{view}.swift"))
  status = code.split('func updatePlayStatus(', 2).last.split('// 下载', 2).first
  abort "#{view} drops hidden state updates" if status.include?('if self.isHidden { return }') && view == 'PlayControlTapeView'
  abort "#{view} does not render the published state" unless status.include?('self.playButton.isSelected = playStatus.isPlaying')
end
api = File.read(File.join(root, 'Mobie/Mobie/Base/Music/KakaMusicPlayer+API.swift'))
%w[Business/PlayerModule/View/PlayControlDefaultView.swift Business/PlayerModule/View/PlayerLyricCollectCell.swift Business/OtherModule/TabbarModule/iOS/PlayerControlToolBarView.swift].each do |path|
  code = File.read(File.join(root, 'Mobie/Mobie', path))
  abort "#{path} must seek and resume atomically" unless code.match?(/seek\(time: \w+, resumePlayback: true\)/)
end
%w[Baidu Aliyunpan 115Drive Google Dropbox OneDrive].each do |provider|
  body = api.split("func handle#{provider}Streaming", 2).last.split("\n    func ", 2).first
  abort "#{provider} has no request gate" unless body.include?('let requestID = playbackRequestID') && body.include?('acceptsPlaybackRequest(requestID, model: model)')
end

Dir.mktmpdir('wake-playback-state-', '/private/tmp') do |dir|
  harness = File.read(File.join(__dir__, 'PlaybackStateRegression.swift')).sub('// APP_TRANSITION_METHODS', methods)
  path = File.join(dir, 'Regression.swift')
  File.write(path, harness)
  ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
  abort 'Compile failed' unless system('xcrun', '--sdk', 'macosx', 'swiftc', '-swift-version', '5', '-parse-as-library', '-module-cache-path', File.join(dir, 'modules'), path, '-o', File.join(dir, 'check'))
  abort 'Regression failed' unless system(File.join(dir, 'check'))
end
