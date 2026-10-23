#!/usr/bin/env ruby
require 'pathname'

root = Pathname.new(__dir__).join('../..').realpath
Dir.chdir(root)
checks = 0
check = lambda do |condition, message|
  raise message unless condition
  checks += 1
end

project = File.read('Mobie/Mobie.xcodeproj/project.pbxproj')
app_sources = Dir.glob('Mobie/Mobie/**/*.{swift,m,mm,h,plist,storyboard,xib}')
removed_types = %w[RadioTableViewCell VideoPlayerController DownloadPoolView]
removed_types.each do |name|
  check.call(app_sources.none? { |path| File.basename(path, '.*') == name }, "Remove unused legacy file #{name}")
  check.call(!project.include?(name), "Remove #{name} from both application targets")
  check.call(app_sources.none? { |path| File.read(path).match?(/\b#{Regexp.escape(name)}\b/) }, "No dynamic or static legacy reference to #{name}")
end

# The removed radio marketing cell is unrelated to radio stations configured on
# the user's Navidrome server. Keep that working feature intact.
session = File.read('Mobie/Mobie/Business/MusicServerModule/Data/MusicServerSession.swift')
browse = File.read('Mobie/Mobie/Business/MusicServerModule/UI/MusicServerBrowseViewController.swift')
check.call(session.include?('struct MusicServerRadio'), 'Preserve music-server radio models')
check.call(session.include?('case .radios: path = "/api/radio"'), 'Preserve the Navidrome radio endpoint')
check.call(session.include?('func musicItem(for radio: MusicServerRadio)'), 'Preserve playable server radio conversion')
check.call(browse.include?('session.musicItem(for: radio)'), 'Preserve the user-visible server radio playback path')

# The removed floating download-pool prototype must not remove the current
# queue, execution layer, download pages, or their ordinary entry points.
%w[
  LocalSDK/AppGroupKit/Classes/CoreManager/Manager/DownloadManager.swift
  Mobie/Mobie/Business/ImportModule/Model/DownloadManager+Tasks.swift
  Mobie/Mobie/Business/ImportModule/Controller/DownloadViewController.swift
  Mobie/Mobie/Business/MusicServerModule/UI/NavidromeDownloadViewController.swift
].each { |path| check.call(File.file?(path), "Preserve current download implementation: #{path}") }
check.call(File.read('Mobie/Mobie/System/AppDelegate.swift').include?('DownloadManager.shared.activateDownloads()'), 'Preserve automatic queue activation')
check.call(project.scan(/\/\* DownloadViewController\.swift in Sources \*\/ =/).size == 2, 'Preserve current download page in both targets')
check.call(project.scan(/\/\* NavidromeDownloadViewController\.swift in Sources \*\/ =/).size == 2, 'Preserve server download page in both targets')

puts "#{checks} legacy-feature removal / active radio and download preservation checks passed"
