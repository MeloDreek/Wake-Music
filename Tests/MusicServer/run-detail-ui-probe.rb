#!/usr/bin/env ruby
require 'tmpdir'
root = File.expand_path('../..', __dir__)
ui = File.join(root, 'Mobie/Mobie/Business/MusicServerModule/UI')
source = File.read(File.join(ui, 'MusicServerCells.swift'))
cell = source[/final class MusicServerRecentUploadCell:.*?^\}/m] or abort 'Recent upload production cell not found'
description = File.read(File.join(ui, 'MusicServerExpandableTextView.swift'))
fixture = File.read(File.join(__dir__, 'DetailUIRegression.swift'))
Dir.mktmpdir('wake-server-detail-ui-') do |directory|
  path = File.join(directory, 'Probe.swift')
  File.write(path, fixture + "\n" + cell + "\n" + description)
  sdk = IO.popen(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], &:read).strip
  executable = File.join(directory, 'detail-ui-probe')
  abort 'Compilation failed' unless system('xcrun', '--sdk', 'iphonesimulator', 'swiftc',
    '-swift-version', '5', '-parse-as-library', '-target', 'arm64-apple-ios16.0-simulator', '-sdk', sdk,
    '-module-cache-path', File.join(directory, 'module-cache'), path, '-o', executable)
  abort 'Detail UI regressions failed' unless system('xcrun', 'simctl', 'spawn',
    ENV.fetch('LAYOUT_SIMULATOR_UDID', 'booted'), executable)
end
