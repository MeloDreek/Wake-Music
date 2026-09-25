#!/usr/bin/env ruby
require 'tmpdir'

root = File.expand_path('../..', __dir__)
ui = File.join(root, 'Mobie/Mobie/Business/MusicServerModule/UI')
source = File.read(File.join(ui, 'MusicServerAlbumDetailViewController.swift'))
methods = ['configureHeader', 'configureButton'].map do |name|
  source[/    private func #{name}\(.*?^    \}/m]&.sub('private func', 'func') or abort "Missing production method #{name}"
end
methods << (source[/    override func viewDidLayoutSubviews\(\).*?^    \}/m] or abort 'Missing production layout method')
methods << ((source[/    private static func displayDuration\(.*?^    \}/m] or abort 'Missing duration sanitizer').sub('private static func', 'static func'))
description = File.read(File.join(ui, 'MusicServerExpandableTextView.swift'))
fixture = File.read(File.join(__dir__, 'AlbumHeaderProbe.swift')).sub('/* PRODUCTION_METHODS */', methods.join("\n"))

abort 'Album route lost its detail controller' unless File.read(File.join(ui, 'MusicServerBrowseViewController.swift')).include?('MusicServerAlbumDetailViewController(session: session, album: album)')
abort 'Album songs must retain normal song actions' unless source.include?('cellType: .navidromeTrack') && source.include?('songActions.handle(model: model, action: action)')
abort 'Album request needs pagination bounds' unless source.include?('nextOffset < 10_000') && source.include?('nextOffset <= offset')
abort 'Refresh must clear the old album snapshot' unless source.include?('session.invalidateAlbumDetails(id: album.id)')

Dir.mktmpdir('wake-album-header-') do |directory|
  path = File.join(directory, 'Probe.swift')
  File.write(path, fixture + "\n" + description)
  sdk = IO.popen(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], &:read).strip
  executable = File.join(directory, 'album-header-probe')
  abort 'Compilation failed' unless system('xcrun', '--sdk', 'iphonesimulator', 'swiftc',
    '-swift-version', '5', '-parse-as-library', '-target', 'arm64-apple-ios26.0-simulator', '-sdk', sdk,
    '-module-cache-path', File.join(directory, 'module-cache'), path, '-o', executable)
  abort 'Album header regressions failed' unless system('xcrun', 'simctl', 'spawn',
    ENV.fetch('LAYOUT_SIMULATOR_UDID', 'booted'), executable,
    File.join(root, 'Mobie/Mobie/System/Assets.xcassets/Other/demo_art.imageset/demo_art@3x.png'))
end
