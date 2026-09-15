#!/usr/bin/env ruby
require 'tmpdir'
require 'fileutils'
require 'open3'
root = File.expand_path('../..', __dir__)
device = ARGV.fetch(0) { abort 'Supply a booted arm64 simulator UDID' }
sdk_root = ARGV[1] || '/Users/kaka/Documents/本地公开库/DominantColors'
ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
ENV.delete('SDKROOT')
build = Dir.mktmpdir('wakemusic-palette-tests-')
app = File.join(build, 'PaletteTests.app')
frameworks = File.join(app, 'Frameworks')
FileUtils.mkdir_p(frameworks)
sdk, status = Open3.capture2('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
abort 'Missing SDK' unless status.success?
def run!(*args); abort 'Command failed' unless system(*args); end
common = ['xcrun', 'swiftc', '-swift-version', '5', '-sdk', sdk.strip, '-target', 'arm64-apple-ios16.0-simulator', '-module-cache-path', File.join(build, 'modules')]
sources = Dir.glob(File.join(sdk_root, 'Sources/DominantColors/**/*.swift'))
abort 'DominantColors source not found' if sources.empty?
library = File.join(frameworks, 'libDominantColors.dylib')
run!(*common, '-emit-library', '-emit-module', '-module-name', 'DominantColors', '-emit-module-path', File.join(build, 'DominantColors.swiftmodule'), *sources, '-Xlinker', '-install_name', '-Xlinker', '@rpath/libDominantColors.dylib', '-o', library)
run!(*common, '-parse-as-library', '-I', build, '-L', frameworks, '-lDominantColors', '-Xlinker', '-rpath', '-Xlinker', '@executable_path/Frameworks',
     File.join(root, 'Mobie/Mobie/Business/PlayerModule/View/ArtworkPalette.swift'), File.join(__dir__, 'PaletteRegression.swift'), '-o', File.join(app, 'PaletteTests'))
File.write(File.join(app, 'Info.plist'), <<~PLIST)
<?xml version="1.0"?><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.wakemusic.tests.palette</string>
<key>CFBundleName</key><string>PaletteTests</string><key>CFBundleExecutable</key><string>PaletteTests</string>
<key>CFBundlePackageType</key><string>APPL</string><key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>1.0</string><key>MinimumOSVersion</key><string>16.0</string>
<key>UILaunchScreen</key><dict/></dict></plist>
PLIST
run!('codesign', '--force', '--sign', '-', library)
run!('codesign', '--force', '--sign', '-', app)
run!('xcrun', 'simctl', 'install', device, app)
run!('xcrun', 'simctl', 'launch', '--console', '--terminate-running-process', device, 'com.wakemusic.tests.palette')
container, status = Open3.capture2('xcrun', 'simctl', 'get_app_container', device, 'com.wakemusic.tests.palette', 'data')
abort 'Missing test container' unless status.success?
report = File.read(File.join(container.strip, 'Documents/palette-results.txt'))
puts report
abort 'Palette regression failed' unless report.include?('0 failures')
