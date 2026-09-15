#!/usr/bin/env ruby
# Compile an isolated UIKit host using the ACTUAL production navigation methods.
# No Wake Music account, keychain, network, or app data is accessed.
require 'tmpdir'
require 'fileutils'
require 'open3'

root = File.expand_path('../..', __dir__)
device = ARGV.fetch(0) { abort 'Usage: ruby Tests/Connections/run-navigation-regressions.rb SIMULATOR_UDID' }
ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
source = File.read(File.join(root, 'Mobie/Mobie/Business/ImportModule/Controller/ImportViewController.swift'))
header = source[/class ImportViewController: SuperViewController \{.*?(?=    override func preSetupSubViews)/m]
method = source[/    func finishRemoteAuthorization\(_ server: ServerConfigModel\) \{.*?(?=    \/\/ MARK:  GET && SET)/m]
extensions = source[/extension UIViewController \{.*?(?=extension ImportViewController: UITableViewDataSource)/m]
abort 'Production routing markers changed; update extraction.' unless header && method && extensions
header = header.sub('SuperViewController', 'UIViewController')
build = Dir.mktmpdir('wakemusic-navigation-')
puts "Harness: #{build}"
app = File.join(build, 'NavigationHarness.app')
FileUtils.mkdir_p(app)
swift = File.join(build, 'NavigationHarness.swift')
File.write(swift, File.read(File.join(__dir__, 'ImportNavigationHarness.swift')) + "\n" + header + method + "}\n" + extensions)
File.write(File.join(app, 'Info.plist'), <<~PLIST)
  <?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.wakemusic.tests.import-navigation</string>
  <key>CFBundleExecutable</key><string>NavigationHarness</string>
  <key>CFBundleName</key><string>NavigationHarness</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>MinimumOSVersion</key><string>16.0</string>
  <key>UILaunchScreen</key><dict/>
  <key>UIDeviceFamily</key><array><integer>1</integer><integer>2</integer></array>
  </dict></plist>
PLIST
def run!(*args)
  abort "Failed: #{args.first}" unless system(*args)
end
sdk, status = Open3.capture2('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
abort 'Simulator SDK unavailable' unless status.success?
run!('xcrun', 'swiftc', '-parse-as-library', '-sdk', sdk.strip,
     '-target', 'arm64-apple-ios16.0-simulator', swift, '-o', File.join(app, 'NavigationHarness'))
run!('codesign', '--force', '--sign', '-', app)
run!('xcrun', 'simctl', 'install', device, app)
run!('xcrun', 'simctl', 'launch', '--console', '--terminate-running-process', device, 'com.wakemusic.tests.import-navigation')
container, status = Open3.capture2('xcrun', 'simctl', 'get_app_container', device, 'com.wakemusic.tests.import-navigation', 'data')
abort 'Harness data unavailable' unless status.success?
report = File.read(File.join(container.strip, 'Documents/navigation-results.txt'))
puts report
abort 'Navigation regression failure' unless report.include?('0 failures')
