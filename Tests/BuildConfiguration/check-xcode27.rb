#!/usr/bin/env ruby
require 'json'
require 'open3'
require 'rexml/document'

ROOT = File.expand_path('../..', __dir__)
def project(path)
  json, error, status = Open3.capture3('plutil', '-convert', 'json', '-o', '-', File.join(ROOT, path))
  abort error unless status.success?
  JSON.parse(json)
end
def check(condition, message)
  abort "FAIL: #{message}" unless condition
  puts "PASS: #{message}"
end

app = project('Mobie/Mobie.xcodeproj/project.pbxproj')
objects = app.fetch('objects')
app_configs = objects.fetch(objects.fetch(app.fetch('rootObject')).fetch('buildConfigurationList')).fetch('buildConfigurations')
check(app_configs.all? { |id| objects.fetch(id).fetch('buildSettings')['STRING_CATALOG_GENERATE_SYMBOLS'] == 'NO' }, 'Legacy localStr catalogs do not generate Swift reserved-word symbols')
targets = objects.values.select { |o| o['isa'] == 'PBXNativeTarget' }
products = {}
%w[Mobie Mobie_Pro].each do |name|
  target = targets.find { |t| t['name'] == name }
  configs = objects.fetch(target.fetch('buildConfigurationList')).fetch('buildConfigurations')
  products[name] = configs.map { |id| objects.fetch(id).fetch('buildSettings').fetch('PRODUCT_NAME') }.uniq
  check(products[name].size == 1, "#{name}: Debug/Release use the same product name")
  configs.each do |id|
    config = objects.fetch(id)
    settings = config.fetch('buildSettings')
    expected_id = name == 'Mobie' ? 'com.OfflineMusic.www' : 'com.OfflineMusic.www.pro'
    check(settings['PRODUCT_BUNDLE_IDENTIFIER'] == expected_id, "#{name} #{config['name']}: bundle identity unchanged")
    check((settings['PRODUCT_MODULE_NAME'] || settings['PRODUCT_NAME']) == 'Wakemusic', "#{name} #{config['name']}: Swift runtime module unchanged")
  end
  product = products[name].first + '.app'
  check(objects.fetch(target.fetch('productReference'))['path'] == product, "#{name}: Products reference matches output")
  scheme = REXML::Document.new(File.read(File.join(ROOT, "Mobie/Mobie.xcodeproj/xcshareddata/xcschemes/#{name}.xcscheme")))
  refs = REXML::XPath.match(scheme, '//BuildableReference')
  check(!refs.empty? && refs.all? { |ref| ref.attributes['BuildableName'] == product }, "#{name}: scheme Build/Run/Profile references match output")
end
check((products['Mobie'] & products['Mobie_Pro']).empty?, 'Ordinary/Pro products cannot overwrite one another')

pods = project('Pods/Pods.xcodeproj/project.pbxproj')
pod_objects = pods.fetch('objects')
config_list = pod_objects.fetch(pods.fetch('rootObject')).fetch('buildConfigurationList')
configs = pod_objects.fetch(config_list).fetch('buildConfigurations')
check(configs.all? { |id| pod_objects.fetch(id).fetch('buildSettings')['ENABLE_MODULE_VERIFIER'] == 'NO' }, 'Pods generated-header compatibility applies to Debug and Release')
check(pod_objects.values.select { |o| o['isa'] == 'XCBuildConfiguration' }.none? { |o| o.fetch('buildSettings', {})['ENABLE_MODULE_VERIFIER'] == 'YES' }, 'No Pod target overrides module-verifier compatibility')
check(File.read(File.join(ROOT, 'Podfile')).include?("config.build_settings['ENABLE_MODULE_VERIFIER'] = 'NO'"), 'Podfile preserves the compatibility setting on regeneration')
