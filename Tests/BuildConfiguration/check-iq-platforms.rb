#!/usr/bin/env ruby
require 'json'
require 'open3'
require 'shellwords'
root = File.expand_path('../..', __dir__)
names = %w[IQKeyboardCore IQKeyboardManagerSwift IQKeyboardNotification IQKeyboardReturnManager IQKeyboardToolbar IQKeyboardToolbarManager IQTextInputViewNotification IQTextView]
pattern = Regexp.union(names)
checks = 0
check = ->(condition, message) { abort("FAIL: #{message}") unless condition; checks += 1 }
json, error, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', File.join(root, 'Pods/Pods.xcodeproj/project.pbxproj'))
abort error unless status.success?
objects = JSON.parse(json).fetch('objects')
objects.values.select { |o| o['isa'] == 'PBXTargetDependency' }.each do |dependency|
  target = objects[dependency['target']]
  next unless target && names.any? { |name| target['name'] == name || target['name'].start_with?(name + '-') }
  check.call(dependency['platformFilters'] == ['ios'] && !dependency.key?('platformFilter'), 'IQ dependency is iOS-only')
end
%w[Mobie Mobie_Pro].each do |target|
  prefix = "Pods-#{target}"
  support = File.join(root, 'Pods/Target Support Files', prefix)
  %w[debug release].each do |config|
    text = File.read(File.join(support, "#{prefix}.#{config}.xcconfig"))
    %w[OTHER_LDFLAGS FRAMEWORK_SEARCH_PATHS HEADER_SEARCH_PATHS OTHER_CFLAGS OTHER_MODULE_VERIFIER_FLAGS].each do |key|
      base = text.lines.find { |l| l.start_with?(key + ' =') }
      check.call(base && !base.match?(pattern) && base.include?("$(WAKE_IQ_#{key})"), "#{target} #{config}: no unconditional IQ #{key}")
      check.call(text.lines.any? { |l| l.start_with?("WAKE_IQ_#{key}[sdk=iphone*] =") && l.match?(pattern) }, "#{target}: iPhone/iPad keeps #{key}")
      check.call(text.include?("WAKE_IQ_#{key} =\n"), "#{target}: other platforms default to no IQ #{key}")
    end
    # CocoaPods may add -iframework pairs only after regenerating the integration.
    # Keep option/value pairs together; bare directories are interpreted as inputs.
    ['OTHER_CFLAGS =', 'WAKE_IQ_OTHER_CFLAGS[sdk=iphone*] ='].each do |prefix|
      value = text.lines.find { |line| line.start_with?(prefix) }.split(' = ', 2).last
      tokens = Shellwords.split(value)
      tokens.each_with_index do |token, index|
        if %w[-iframework -isystem -iquote -F].include?(token)
          check.call(tokens[index + 1] && !tokens[index + 1].start_with?('-'), 'Compiler search option retains its path argument')
        elsif token.include?('PODS_CONFIGURATION_BUILD_DIR')
          check.call(index > 0 && %w[-iframework -isystem -iquote -F].include?(tokens[index - 1]), 'No bare framework paths in compiler flags')
        end
      end
    end
    %w[input output].each do |kind|
      ios = File.read(File.join(support, "#{prefix}-frameworks-#{config.capitalize}-#{kind}-files.xcfilelist"))
      mac = File.read(File.join(support, "#{prefix}-frameworks-#{config.capitalize}-macosx-#{kind}-files.xcfilelist"))
      check.call(names.all? { |name| ios.include?(name + '.framework') }, 'iOS embed list retains all IQ frameworks')
      check.call(!mac.match?(pattern), 'Catalyst embed list excludes IQ')
    end
  end
  script = File.join(support, prefix + '-frameworks.sh')
  check.call(system('bash', '-n', script), 'Generated embed script has valid shell syntax')
  check.call(File.read(script).include?('if [ "${PLATFORM_NAME:-}" != "macosx" ]; then'), 'Embed uses SDK platform, not CPU architecture')
end
app = File.read(File.join(root, 'Mobie/Mobie/System/AppDelegate.swift'))
check.call(app.scan('#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(IQKeyboardManagerSwift)').length == 2, 'Import and initialization both exclude Catalyst')
check.call(File.read(File.join(root, 'Podfile')).include?('post_integrate do'), 'pod install reapplies platform isolation')
project = File.read(File.join(root, 'Mobie/Mobie.xcodeproj/project.pbxproj'))
check.call(project.scan('${CONFIGURATION}${WAKE_IQ_PLATFORM_SUFFIX}').length == 4, 'Both app embed phases select SDK-specific file lists')
puts "#{checks} IQ platform-isolation checks passed"
