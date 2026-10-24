#!/usr/bin/env ruby
# Local-file identification remains supported; no unexposed microphone capture ships.
require 'json'
require 'open3'

root = File.expand_path('../..', __dir__)
Dir.chdir(root)
checks = 0
check = lambda do |condition, message|
  raise message unless condition
  checks += 1
end
source = File.read('Mobie/Mobie/Base/Core/Tools/AudioFingerprintMatcher.swift')
%w[startTunnelingMicrophone stopTunnelingMicrophone AVCaptureDevice AVAudioEngine
   signatureGeneratorForMic microphoneCompletion microphoneGeneration microphoneLock
   inputNode installTap isLocal].each do |token|
  check.call(!source.include?(token), "Unexposed microphone implementation remains: #{token}")
end
%w[matchLocalAudio cancelLocalMatching makeSignatures SHSignatureGenerator
   submitNextSignature fetchLRCLyricArray].each do |token|
  check.call(source.include?(token), "Production local-file recognition lost: #{token}")
end
check.call(source.include?('AVAudioFile(forReading: url)'), 'Recognition must continue decoding the selected file')
check.call(source.include?('guard url.isFileURL else'), 'Do not silently capture external audio')
check.call(source.include?('requests[request.id] === request && request.generation == currentGeneration()'), 'Cancellation must invalidate stale local matches')
check.call(source.include?('where request.generation != self.currentGeneration()'), 'Cancellation must retire old sessions')

catalog = JSON.parse(File.read('Mobie/Mobie/System/InfoPlist.xcstrings'))
project = File.read('Mobie/Mobie.xcodeproj/project.pbxproj')
unused_permissions = %w[NSMicrophoneUsageDescription NSCameraUsageDescription]
unused_permissions.each do |key|
  check.call(!catalog.fetch('strings').key?(key), "Unused permission description: #{key}")
  check.call(!project.include?("INFOPLIST_KEY_#{key}"), "Unused permission build setting: #{key}")
end
app_sources = Dir.glob('Mobie/Mobie/**/*.swift').map { |path| File.read(path) }.join("\n")
%w[AVCaptureDevice UIImagePickerController].each do |token|
  check.call(!app_sources.include?(token), "Unused collection code reintroduced: #{token}")
end
ads = File.read('Mobie/Mobie/Base/Core/Tools/AppleSearchAdsManager.swift')
check.call(ads.include?('AAAttribution.attributionToken()') && ads.include?('https://api-adservices.apple.com/api/v1/'), 'Keep official Apple attribution without IDFA collection')

ARGV.each do |app|
  info, error, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', File.join(app, 'Info.plist'))
  raise error unless status.success?
  plist = JSON.parse(info)
  unused_permissions.each do |key|
    check.call(!plist.key?(key), "#{app} still declares #{key}")
  end
  binary_strings, error, status = Open3.capture3('strings', '-a', File.join(app, plist.fetch('CFBundleExecutable')))
  raise error unless status.success?
  check.call(!binary_strings.include?('signatureGeneratorForMic'), 'Removed microphone state must not remain in the app binary')
  localized = Dir.glob(File.join(app, '*.lproj', 'InfoPlist.strings'))
  check.call(!localized.empty?, 'Verify compiled permission translations as well')
  localized.each do |path|
    json, error, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', path)
    raise error unless status.success?
    unused_permissions.each do |key|
      check.call(!JSON.parse(json).key?(key), "Stale #{key} in #{path}")
    end
  end
end
puts "#{checks} local fingerprint and permission checks passed"
