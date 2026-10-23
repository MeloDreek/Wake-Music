#!/usr/bin/env ruby
# Source/configuration checks; add --xcode-settings to verify Xcode's resolved
# Release settings as well. Supply existing package checkouts with
# WAKE_SOURCE_PACKAGES_DIR when automatic package resolution is disabled.
require 'json'
require 'open3'
require 'rexml/document'
require 'shellwords'
require 'tmpdir'

root = File.expand_path('../..', __dir__)
Dir.chdir(root)
checks = 0
check = lambda do |condition, message|
  abort("FAIL: #{message}") unless condition
  checks += 1
end
read = ->(relative_path) { File.read(File.join(root, relative_path)) }
method = lambda do |source, name|
  source.match(/(?:@objc\s+)?(?:public\s+)?(?:static\s+)?func #{Regexp.escape(name)}\b.*?(?=\n    (?:@objc\s+)?(?:public\s+)?(?:static\s+)?func |\n\})/m)&.to_s.to_s
end

editor = method.call(read.call('Mobie/Mobie/Business/MusicModule/Controller/MusicTagEditorController.swift'), 'coverImgView')
check.call(editor.include?('return view'), 'Inspect the actual cover image factory')
check.call(!editor.include?('#if DEBUG') && !editor.include?('UIBlurEffect'), 'No DEBUG-only screenshot blur on user artwork')
download = method.call(read.call('Mobie/Mobie/Business/ConnectModule/Controller/ConnectListViewController.swift'), 'downloadQueueAction')
check.call(download.include?('modalPresentationStyle = .automatic'), 'Download presentation preserves the Release appearance')
check.call(!download.include?('#if') && !download.include?('.fullScreen'), 'Download presentation is identical across build configurations')
proxy = method.call(read.call('LocalSDK/AppGroupKit/Classes/BaseModel/SearchEngineType.swift'), 'isHttpProxy')
check.call(proxy.include?('CFNetworkCopySystemProxySettings'), 'Preserve the existing system-proxy lookup')
check.call(!proxy.include?('#if'), 'Do not substitute a fake DEBUG proxy result')
social = method.call(read.call('Mobie/Mobie/Business/OtherModule/ProfileModule/Model/SocialMediaType.swift'), 'socialArray')
check.call(social.include?('switch language'), 'Preserve locale-aware contact options')
check.call(!social.include?('#if'), 'Contacts use the same logic in Debug and Release')
api = read.call('Mobie/Mobie/Base/Core/Tools/APIManager.swift')
subsonic = method.call(api, 'requestSubsonic')
check.call(subsonic.include?('navUser.subsonicParams()'), 'Preserve authenticated Subsonic requests')
check.call(!subsonic.match?(/(?:debugPrint|print)\([^\n]*(?:requestURL|parameters)/), 'Do not log Subsonic authentication URLs or parameters')

entitlements = read.call('Mobie/Mobie/Base/Core/Extension/PurchargeStatus+Extension.swift')
check.call(entitlements.match?(/#if Target_Mobie_Pro\s+return true\s+#else\s+return self\.isPremium\(\)\s+#endif/), 'Keep paid Pro access and verified ordinary-edition Premium access')
check.call(!entitlements.match?(/^\s*#if\s+!?DEBUG/), 'No DEBUG-specific VIP grant')
app_delegate = read.call('Mobie/Mobie/System/AppDelegate.swift')
check.call(app_delegate.include?('#if os(iOS) && !targetEnvironment(macCatalyst) && canImport(IQKeyboardManagerSwift)'), 'Keep legitimate keyboard-library platform compatibility')

project_path = 'Mobie/Mobie.xcodeproj/project.pbxproj'
json, error, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', project_path)
abort("Cannot parse project: #{error}") unless status.success?
objects = JSON.parse(json).fetch('objects')
project = objects.values.find { |value| value['isa'] == 'PBXProject' }
targets = objects.values.select { |value| value['isa'] == 'PBXNativeTarget' && %w[Mobie Mobie_Pro].include?(value['name']) }
check.call(targets.length == 2, 'Inspect both shipping application targets')
settings_list = lambda do |owner|
  objects.fetch(owner.fetch('buildConfigurationList')).fetch('buildConfigurations').map { |id| objects.fetch(id) }
end
tokens = lambda do |settings|
  %w[SWIFT_ACTIVE_COMPILATION_CONDITIONS OTHER_SWIFT_FLAGS GCC_PREPROCESSOR_DEFINITIONS].flat_map do |key|
    value = settings[key]
    value.is_a?(Array) ? value : Shellwords.split(value.to_s)
  end
end
([project] + targets).each do |owner|
  name = owner['name'] || 'Project'
  release = settings_list.call(owner).find { |config| config['name'] == 'Release' }
  check.call(!release.nil?, "#{name} has a Release configuration")
  flags = tokens.call(release.fetch('buildSettings'))
  check.call(flags.none? { |flag| flag.match?(/\A(?:-D)?DEBUG(?:=|\z)/) }, "#{name} Release does not define DEBUG")
  check.call(flags.none? { |flag| flag.match?(/\A(?:-D)?(?:APP_REVIEW|REVIEW_BUILD|BETA|TESTING)(?:=|\z)/) }, "#{name} Release has no review/test feature flags")
  next if name == 'Project'
  check.call(flags.include?('Target_Mobie_Pro') == (name == 'Mobie_Pro'), "#{name} has the correct edition flag")
  config_ref = objects.fetch(release.fetch('baseConfigurationReference'))
  check.call(config_ref.fetch('path').end_with?("Pods-#{name}.release.xcconfig"), "#{name} inherits the Release CocoaPods configuration")
  config = read.call("Pods/Target Support Files/Pods-#{name}/Pods-#{name}.release.xcconfig")
  check.call(!config.match?(/(?:^|\s)(?:-D\s*)?DEBUG(?:=|\s|$)/), "#{name} CocoaPods Release does not inject DEBUG")
  scheme = REXML::Document.new(read.call("Mobie/Mobie.xcodeproj/xcshareddata/xcschemes/#{name}.xcscheme"))
  check.call(scheme.root.elements['ArchiveAction'].attributes['buildConfiguration'] == 'Release', "#{name} archives Release, not Debug")
end
debug = settings_list.call(project).find { |config| config['name'] == 'Debug' }
check.call(tokens.call(debug.fetch('buildSettings')).include?('DEBUG'), 'Keep normal Debug diagnostics available')

if ARGV.delete('--xcode-settings')
  Dir.mktmpdir('wakemusic-release-settings-') do |derived_data|
    targets.each do |target|
      name = target.fetch('name')
      command = ['xcodebuild', '-workspace', 'Wake Music.xcworkspace', '-scheme', name,
                 '-configuration', 'Release', '-destination', 'generic/platform=iOS',
                 '-derivedDataPath', derived_data, '-disableAutomaticPackageResolution',
                 '-onlyUsePackageVersionsFromResolvedFile', '-showBuildSettings', '-json',
                 'CODE_SIGNING_ALLOWED=NO']
      package_dir = ENV['WAKE_SOURCE_PACKAGES_DIR']
      command += ['-clonedSourcePackagesDirPath', package_dir] if package_dir && !package_dir.empty?
      output, diagnostics, result = Open3.capture3(*command)
      abort("#{name}: xcodebuild -showBuildSettings failed; inspect Xcode setup/dependencies (exit #{result.exitstatus}).") unless result.success?
      settings = JSON.parse(output).find { |entry| entry['target'] == name }&.fetch('buildSettings')
      check.call(!settings.nil?, "Xcode returns effective #{name} settings")
      flags = tokens.call(settings)
      check.call(settings['CONFIGURATION'] == 'Release', "Xcode resolves #{name} as Release")
      check.call(flags.none? { |flag| flag.match?(/\A(?:-D)?DEBUG(?:=|\z)/) }, "Xcode effective #{name} Release excludes DEBUG")
      check.call(flags.include?('Target_Mobie_Pro') == (name == 'Mobie_Pro'), "Xcode effective #{name} preserves the correct edition")
      # Print only the verdict, never all build settings (which may include credentials).
      puts "#{name}: effective Release compilation conditions verified"
    end
  end
end
check.call(ARGV.empty?, 'Unknown test option')
puts "#{checks} conditional-compilation checks passed"
