#!/usr/bin/env ruby
# Checks the shipping demo's displayed properties and the two public transitions.
# Does not modify the audio file or require a simulator, account, or network.
require 'json'
require 'open3'
require 'tmpdir'

root = File.expand_path('../..', __dir__)
checks = 0
check = lambda do |condition, message|
  abort "FAILED: #{message}" unless condition
  checks += 1
end

welcome = File.read(File.join(root, 'Mobie/Mobie/Business/OtherModule/LoginModule/WelcomeViewController+Page.swift'))
coordinator = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Navigation/AppModeCoordinator.swift'))
[welcome, coordinator].each do |source|
  check.call(source.include?('transition.type = .push'), 'Use a public transition type')
  check.call(!source.include?('CATransitionType(rawValue:'), 'No undocumented transition type')
  check.call(source.include?('!kaka_IsMacOS()') && source.include?('!UIAccessibility.isReduceMotionEnabled'), 'Preserve Mac and Reduce Motion behavior')
  check.call(source.include?('effectiveUserInterfaceLayoutDirection == .rightToLeft'), 'Preserve RTL direction')
end
check.call(coordinator.include?('returning != rtl ? .fromLeft : .fromRight'), 'Reverse the public transition when returning')

model = File.read(File.join(root, 'Mobie/Mobie/Base/Core/Extension/MusicItemModel+Kaka.swift'))
demo = model[/static func demoMusicModel\(\) -> MusicItemModel \{.*?\n    \}/m] or abort 'Demo model not found'
helper = model[/private static func demoAudioValue\(_ value: UInt\?, fallback: Int\) -> Int \{.*?\n    \}/m] or abort 'Production property validator not found'
expected = { 'durationSeconds' => 34, 'bitrate' => 1_411_200, 'sampleRate' => 44_100, 'channel' => 6 }
actual = {}
expected.each do |property, value|
  token = demo[/demoAudioValue\(metaData\?\.#{property}, fallback: ([\d_]+)\)/, 1]
  actual[property] = token&.delete('_')&.to_i
  check.call(actual[property] == value, "Use parsed #{property} or the verified bundled-file fallback")
end
check.call(!demo.include?('7.1 Surround') && !demo.include?('surround71'), 'Demo does not claim 7.1 audio')
check.call(demo.include?('embeddedTitle?.isEmpty == false ? embeddedTitle : placeArtist'), 'Empty demo title has a neutral brand fallback')
check.call(!demo.match?(/FFmpegUtility|FFprobeKit|FFmpegKit\./), 'No new synchronous FFmpeg probe on the UI path')

# Execute the production validator, including zero properties from unsupported
# formats and integer overflow, without importing UIKit or a third-party SDK.
Dir.mktmpdir('wakemusic-demo-properties-') do |dir|
  swift = "enum Demo {\n#{helper.sub('private static', 'static')}\n}\n"
  swift += <<~SWIFT
    precondition(Demo.demoAudioValue(nil, fallback: 44100) == 44100)
    precondition(Demo.demoAudioValue(0, fallback: 44100) == 44100)
    precondition(Demo.demoAudioValue(48000, fallback: 44100) == 48000)
    precondition(Demo.demoAudioValue(UInt.max, fallback: 44100) == 44100)
    precondition(Demo.demoAudioValue(2, fallback: 6) == 2)
    print("Passed 5 production metadata fallback checks")
  SWIFT
  source = File.join(dir, 'main.swift')
  binary = File.join(dir, 'checks')
  File.write(source, swift)
  output, status = Open3.capture2e('xcrun', 'swiftc', '-module-cache-path', File.join(dir, 'modules'), source, '-o', binary)
  abort output unless status.success?
  system(binary) or abort 'Metadata fallback checks failed'
end

ffprobe = ENV.fetch('FFPROBE', '/opt/homebrew/bin/ffprobe')
if File.executable?(ffprobe)
  file = File.join(root, 'Mobie/Mobie/Base/Bundle/Reasource.bundle/Files/Wakemusic.dts')
  output, status = Open3.capture2e(ffprobe, '-v', 'error', '-show_entries',
    'stream=codec_name,sample_rate,channels,bit_rate:format=duration', '-of', 'json', file)
  abort output unless status.success?
  probe = JSON.parse(output)
  audio = probe.fetch('streams').first
  check.call(audio.fetch('codec_name') == 'dts', 'Demo codec remains DTS')
  check.call(audio.fetch('sample_rate').to_i == actual.fetch('sampleRate'), 'Sample-rate fallback matches the actual asset')
  check.call(audio.fetch('bit_rate').to_i == actual.fetch('bitrate'), 'Bitrate fallback matches the actual asset')
  check.call(audio.fetch('channels') == actual.fetch('channel'), 'Channel fallback matches the actual asset')
  check.call(probe.fetch('format').fetch('duration').to_f.to_i == actual.fetch('durationSeconds'), 'Duration fallback matches the actual asset')
else
  warn 'Asset probe skipped: install ffprobe or set FFPROBE to its executable path.'
end

puts "Passed #{checks} demo/transition checks"
