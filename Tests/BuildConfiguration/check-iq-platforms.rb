#!/usr/bin/env ruby
require 'json'
require 'open3'

root = File.expand_path('../..', __dir__)
names = %w[IQKeyboardCore IQKeyboardManagerSwift IQKeyboardNotification IQKeyboardReturnManager IQKeyboardToolbar IQKeyboardToolbarManager IQTextInputViewNotification IQTextView]
checks = 0
check = ->(condition, message) { abort("FAIL: #{message}") unless condition; checks += 1 }
podfile = File.read(File.join(root, 'Podfile'))
check.call(podfile.scan("pod 'IQKeyboardManagerSwift', '~> 8.0.3'").length == 2, 'Both apps retain the official pinned dependency')
check.call(!podfile.include?('ios_only_keyboard_pods') && !podfile.include?('IOSOnlyKeyboardPods'), 'No custom IQ integration hook')
check.call(!File.exist?(File.join(root, 'scripts/ios_only_keyboard_pods.rb')), 'Removed platform-rewriting script')

json, error, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', File.join(root, 'Pods/Pods.xcodeproj/project.pbxproj'))
abort error unless status.success?
objects = JSON.parse(json).fetch('objects')
objects.values.select { |o| o['isa'] == 'PBXTargetDependency' }.each do |dependency|
  target = objects[dependency['target']]
  next unless target && names.any? { |name| target['name'] == name || target['name'].start_with?(name + '-') }
  check.call(!dependency.key?('platformFilters') && !dependency.key?('platformFilter'), 'IQ dependencies use the generated CocoaPods platform configuration')
end
objects.values.select { |o| o['isa'] == 'PBXBuildFile' }.each do |file|
  reference = objects[file['fileRef']]
  next unless reference && names.include?(File.basename(reference['path'].to_s, '.framework'))
  check.call(!file.key?('platformFilters') && !file.key?('platformFilter'), 'IQ framework build files have no custom platform filter')
end

%w[Mobie Mobie_Pro].each do |target|
  prefix = "Pods-#{target}"
  support = File.join(root, 'Pods/Target Support Files', prefix)
  %w[debug release].each do |config|
    text = File.read(File.join(support, "#{prefix}.#{config}.xcconfig"))
    check.call(!text.include?('WAKE_IQ_'), "#{target} #{config}: no custom conditional IQ variables")
    linker_flags = text.lines.find { |line| line.start_with?('OTHER_LDFLAGS =') }.to_s
    check.call(names.all? { |name| linker_flags.include?(%(-framework "#{name}")) }, "#{target} #{config}: normal IQ linkage")
    %w[input output].each do |kind|
      list = File.read(File.join(support, "#{prefix}-frameworks-#{config.capitalize}-#{kind}-files.xcfilelist"))
      check.call(names.all? { |name| list.include?(name + '.framework') }, 'Generated embedding list retains IQ frameworks')
    end
  end
  check.call(Dir.glob(File.join(support, '*-frameworks-*-macosx-*-files.xcfilelist')).empty?, 'No custom Catalyst embedding lists remain')
  script = File.join(support, prefix + '-frameworks.sh')
  check.call(system('bash', '-n', script), 'Generated embedding script has valid shell syntax')
  text = File.read(script)
  check.call(!text.include?('WakeMusic: iOS-only IQ frameworks') && !text.include?('if [ "${PLATFORM_NAME:-}" != "macosx" ]; then'), 'No IQ-specific embedding guard')
end

app = File.read(File.join(root, 'Mobie/Mobie/System/AppDelegate.swift'))
check.call(app.scan('#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(IQKeyboardManagerSwift)').length == 2, 'App import and initialization retain standard Swift platform guards')
project = File.read(File.join(root, 'Mobie/Mobie.xcodeproj/project.pbxproj'))
check.call(!project.include?('WAKE_IQ_'), 'App embedding phases use standard configuration file lists')
puts "#{checks} standard IQ integration checks passed (not a Catalyst compatibility guarantee)"
