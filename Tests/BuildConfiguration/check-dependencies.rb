#!/usr/bin/env ruby
require 'json'
require 'open3'
require 'set'

root = File.expand_path('../..', __dir__)
json, status = Open3.capture2('plutil', '-convert', 'json', '-o', '-', File.join(root, 'Mobie/Mobie.xcodeproj/project.pbxproj'))
abort 'Cannot parse app project' unless status.success?
project = JSON.parse(json)
objects = project.fetch('objects')
refs = objects.fetch(project.fetch('rootObject')).fetch('packageReferences')
local = refs.map { |id| objects.fetch(id) }.select { |ref| ref['isa'] == 'XCLocalSwiftPackageReference' }
expected_local = %w[KSPlayer firebase-ios-sdk MEGASDK].to_set
abort 'Unexpected local third-party dependency' unless local.map { |ref| File.basename(ref.fetch('relativePath')) }.to_set == expected_local
mega = local.find { |ref| File.basename(ref.fetch('relativePath')) == 'MEGASDK' }
abort 'MEGASDK must travel with the app sources' unless mega.fetch('relativePath') == '../LocalSDK/MEGASDK'
uploader = refs.map { |id| objects.fetch(id) }.find { |ref| ref['repositoryURL'] == 'https://github.com/MeloDreek/GCDWebServer_Swift.git' }
abort 'SwiftyUploader must use the published fork' unless uploader && uploader['requirement'] == { 'kind' => 'exactVersion', 'version' => '1.0.0' }

objects.values.select { |o| o['isa'] == 'PBXNativeTarget' }.each do |target|
  products = target.fetch('packageProductDependencies').map { |id| objects.fetch(id) }
  names = products.map { |p| p.fetch('productName') }
  abort "Duplicate or missing products: #{target['name']}" unless names.size == 24 && names.uniq.size == 24
  products.each { |p| abort 'Product bound to inactive package' unless refs.include?(p.fetch('package')) }
  framework_ids = target.fetch('buildPhases').flat_map do |id|
    phase = objects.fetch(id)
    phase['isa'] == 'PBXFrameworksBuildPhase' ? phase.fetch('files') : []
  end
  linked = framework_ids.map { |id| objects.fetch(id)['productRef'] }.compact
  abort "Duplicate/missing package linkage: #{target['name']}" unless linked.sort == target.fetch('packageProductDependencies').sort
end

pins = JSON.parse(File.read(File.join(root, 'Wake Music.xcworkspace/xcshareddata/swiftpm/Package.resolved'))).fetch('pins')
refs.map { |id| objects.fetch(id) }.select { |ref| ref['isa'] == 'XCRemoteSwiftPackageReference' }.each do |ref|
  url = ref.fetch('repositoryURL')
  identity = File.basename(url, '.git').downcase
  pin = pins.find { |p| p['identity'] == identity }
  abort "Missing resolved pin: #{identity}" unless pin
  requirement = ref.fetch('requirement')
  if requirement['kind'] == 'revision'
    abort "Revision differs: #{identity}" unless pin.fetch('state')['revision'] == requirement.fetch('revision')
  elsif requirement['kind'] == 'exactVersion'
    abort "Version differs: #{identity}" unless pin.fetch('state')['version'] == requirement.fetch('version')
  end
end
puts 'PASS: 14 upstream packages + published uploader fork, in-repo MEGA, both targets unique linkage, resolved pins.'
