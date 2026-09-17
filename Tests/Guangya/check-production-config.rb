require 'json'
require 'open3'
require 'uri'

root = File.expand_path('../..', __dir__)
source = File.read(File.join(root, 'LocalSDK/AppGroupKit/Classes/Const/AppGroupConstKey.swift'))
checks = 0
assert = lambda do |condition, message|
  raise message unless condition
  checks += 1
end
settings = {}
%w[ClientID Secret RedirectURL].each do |key|
  declaration = source.lines.find { |line| line.start_with?("public let Guangya_#{key} =") }
  assert.call(!declaration.nil?, "Missing Guangya #{key}")
  values = declaration.scan(/"([^"]*)"/).flatten
  assert.call(declaration.include?('Bundle.main.bundleIdentifier ==') && values.size == 3 && values[0] == 'com.OfflineMusic.www.pro', "#{key}: select credentials using the host app bundle, not the shared framework bundle")
  settings[key] = {pro: values[1], standard: values[2]}
  assert.call(values[1] != values[2], "#{key}: ordinary and Pro configurations must be separate")
end
project = source.lines.find { |line| line.start_with?('public let Guangya_ProjectID =') }
assert.call(project && !project[/"([^"]*)"/, 1].to_s.empty?, 'Shared project ID must be configured')
{standard: 'Mobie', pro: 'Mobie_Pro'}.each do |variant, target|
  path = File.join(root, "Mobie/Mobie/System/#{target}.plist")
  json, status = Open3.capture2('plutil', '-convert', 'json', '-o', '-', path)
  assert.call(status.success?, "#{target}: valid Info.plist")
  info = JSON.parse(json)
  callback = URI.parse(settings['RedirectURL'][variant])
  expected_scheme = variant == :pro ? 'wakemusic-pro-guangya' : 'wakemusic-guangya'
  assert.call(callback.scheme == expected_scheme && callback.host == 'oauth' && callback.path == '/callback' && callback.query.nil? && callback.fragment.nil?, "#{target}: callback matches submitted application")
  schemes = info.fetch('CFBundleURLTypes').flat_map { |entry| entry.fetch('CFBundleURLSchemes', []) }
  assert.call(schemes.include?(callback.scheme), "#{target}: OAuth callback is registered with iOS")
  assert.call(!schemes.include?(variant == :pro ? 'wakemusic-guangya' : 'wakemusic-pro-guangya'), "#{target}: do not claim the other app's callback scheme")
  assert.call(!settings['ClientID'][variant].empty?, "#{target}: client ID is present")
  secret = settings['Secret'][variant]
  assert.call(!secret.empty? && secret.length <= 64, "#{target}: signing key meets the vendor's length constraint")
end
service = File.read(File.join(root, 'Mobie/Mobie/Base/Core/Extension/GuangyaDriveService.swift'))
assert.call(service.include?('["wakemusic-guangya", "wakemusic-pro-guangya"]'), 'Suppress both callback variants before general URL logging')
assert.call(service.include?('registeredSchemes.contains(scheme)'), 'Fail clearly if a callback was not registered in the target')
assert.call(service.include?('".guangya.oauth"'), 'Preserve app-isolated Keychain service')
# This intentionally prints no IDs, signing keys, authorization codes or tokens.
puts "PASS: #{checks} Guangya dual-app configuration checks (credential values omitted)"
