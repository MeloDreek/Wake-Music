#!/usr/bin/env ruby
require 'tmpdir'
require 'json'
require 'open3'

root = File.expand_path('../..', __dir__)
source_root = File.join(root, 'Mobie/Mobie/Business')
library = File.read(File.join(source_root, 'MusicServerModule/UI/MusicServerLibraryViewController.swift'))
entries = library.scan(/Entry\(title: "([^"]+)"/).flatten
abort 'Library ordering changed unexpectedly' unless entries == ['Songs', 'Artists', 'Albums', 'Favourite Songs', 'My Playlists', 'Recently Played', 'Radio Stations', 'Discover Music']
imports = File.read(File.join(source_root, 'ImportModule/Model/ImportFileType+Extension.swift'))
abort 'Missing shared title' unless imports.include?('return "Navidrome/Subsonic"')
abort 'Missing shared icon' unless imports.include?('return MusicServerConnectionIcon.image')
connection = File.read(File.join(source_root, 'ConnectModule/View/ConnectListTableCell.swift'))
abort 'Connected account name overwritten' unless connection.include?('cellConfig.text = serverModel.showTitle()')
abort 'Shared label missing from connected account' unless connection.include?('[serverModel.serverType.titleStr(), serverModel.descString()]')
auth = File.read(File.join(source_root, 'ImportModule/Controller/AuthNavidromeController.swift'))
abort 'Login no longer shares title/icon' unless auth.include?('ImportFileType.fromNavidrome.titleStr()') && auth.include?('ImportFileType.fromNavidrome.iconImage()')
session = File.read(File.join(source_root, 'MusicServerModule/Data/MusicServerSession.swift'))
abort 'Subsonic authentication fallback missing' unless session.include?('subsonic("ping", authenticatedUser: updated)')
puts 'PASS_ENTRY_SOURCE: library order, shared label/icon, custom account names, existing Subsonic authentication fallback'

output = Dir.mktmpdir('wake-server-entry-', '/private/tmp')
icon = imports[/private enum MusicServerConnectionIcon \{.*\z/m] or abort 'Icon source missing'
empty = File.read(File.join(source_root, 'MusicServerModule/UI/NavidromeDownloadViewController.swift'))[/final class NavidromeDownloadEmptyCell: UITableViewCell \{.*\z/m] or abort 'Empty-cell source missing'
assets = File.join(root, 'Mobie/Mobie/Base/Bundle/Reasource.bundle/Images')
fixture = File.read(File.join(__dir__, 'EntryRegression.swift'))
fixture = fixture.sub('// PRODUCTION_ICON', icon).sub('// PRODUCTION_EMPTY_CELL', empty)
fixture = fixture.sub('"ASSET_DIRECTORY"', JSON.generate(assets))
File.write(File.join(output, 'Probe.swift'), fixture)
sdk, status = Open3.capture2('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
abort 'Simulator SDK unavailable' unless status.success?
executable = File.join(output, 'entry-probe')
abort 'UIKit entry probe compilation failed' unless system('xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-ios16.0-simulator', '-sdk', sdk.strip,
                                                        '-module-cache-path', File.join(output, 'modules'), File.join(output, 'Probe.swift'), '-o', executable)
abort 'UIKit entry probe failed' unless system('xcrun', 'simctl', 'spawn', ENV.fetch('LAYOUT_SIMULATOR_UDID', 'booted'), executable)
