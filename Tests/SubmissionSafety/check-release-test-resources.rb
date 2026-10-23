#!/usr/bin/env ruby
# Keep developer fixtures available, but never copy them into shipping app bundles.
# Optional: ruby .../check-release-test-resources.rb /path/to/Wakemusic.app [...]
require 'json'
require 'open3'

root = File.expand_path('../..', __dir__)
Dir.chdir(root)
checks = 0
check = lambda do |condition, message|
  raise message unless condition
  checks += 1
end
json, error, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', 'Mobie/Mobie.xcodeproj/project.pbxproj')
raise error unless status.success?
objects = JSON.parse(json).fetch('objects')
targets = objects.values.select { |o| o['isa'] == 'PBXNativeTarget' && %w[Mobie Mobie_Pro].include?(o['name']) }
check.call(targets.length == 2, 'Inspect both app targets')
targets.each do |target|
  target.fetch('buildPhases').each do |phase_id|
    phase = objects.fetch(phase_id)
    next unless %w[PBXSourcesBuildPhase PBXResourcesBuildPhase PBXCopyFilesBuildPhase].include?(phase['isa'])
    paths = phase.fetch('files', []).map do |id|
      reference = objects[id]['fileRef']
      objects[reference]&.[]('path')
    end.compact
    check.call(paths.none? { |path| path.end_with?('.storekit') }, "#{target['name']} must not ship StoreKit testing fixtures")
    check.call(paths.none? { |path| path.match?(%r{(?:^|/)Tests/|(?:^|/)(?:Mock|Fixture).*\.swift$}) }, "#{target['name']} must not ship development test sources")
  end
end
check.call(File.file?('Mobie/Mobie/System/StoreKitTest.storekit'), 'Keep the local StoreKit fixture for development, outside app resources')
scene = File.read('Mobie/Mobie/System/SceneDelegate.swift')
check.call(!scene.match?(/(?:AppLocalManager|MusicConfigManager|ColorFontManager|ConnectConfigManager|DownloadManager)\.reset\(\)/), 'Do not leave startup test-reset scaffolding')
check.call(!scene.include?('AppLocalManager.shared.isGuideFiveStar = false'), 'Do not re-arm review prompts on every launch')
check.call(!scene.include?('跳转回来的URL'), 'Do not retain an example OAuth callback with credentials')
check.call(scene.include?('ConnectConfigManager.updateConnectNewData()'), 'Keep production connection migration')
check.call(scene.include?('if UserInfoManager.shared.isVIP()'), 'Keep actual entitlement handling')

ARGV.each do |app|
  check.call(File.directory?(app) && File.extname(app) == '.app', 'Supply a real compiled app bundle')
  check.call(Dir.glob(File.join(app, '**', '*.storekit')).empty?, "Compiled #{File.basename(app)} contains a StoreKit test fixture")
  check.call(Dir.glob(File.join(app, '**', '*.{swift,m,mm}')).empty?, "Compiled #{File.basename(app)} contains source/test code resources")
end
puts "#{checks} release test-resource checks passed#{ARGV.empty? ? ' (source configuration only)' : ' (including compiled app bundles)'}"
