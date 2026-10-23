#!/usr/bin/env ruby
# The updated KSPlayer package keeps its UIKit player wrapper in KSPlayerUI.
# Verify normal SPM linkage for both products, without modifying the SDK.
require 'json'
require 'open3'

root = File.expand_path('../..', __dir__)
project = File.join(root, 'Mobie/Mobie.xcodeproj/project.pbxproj')
output, status = Open3.capture2e('plutil', '-convert', 'json', '-o', '-', project)
abort output unless status.success?
objects = JSON.parse(output).fetch('objects')
checks = 0
check = lambda do |condition, message|
  abort "FAILED: #{message}" unless condition
  checks += 1
end
%w[Mobie Mobie_Pro].each do |name|
  target = objects.values.find { |object| object['isa'] == 'PBXNativeTarget' && object['name'] == name }
  check.call(!target.nil?, "#{name} exists")
  products = target.fetch('packageProductDependencies').map { |id| [id, objects.fetch(id)] }
  core = products.find { |_, product| product['productName'] == 'KSPlayer' }
  ui = products.select { |_, product| product['productName'] == 'KSPlayerUI' }
  check.call(ui.length == 1 && !core.nil?, "#{name} links one UI product alongside the core")
  ui_id, ui_product = ui.first
  check.call(ui_product['package'] == core.last['package'], "#{name} uses the same KSPlayer package for both modules")
  phase = target.fetch('buildPhases').map { |id| objects.fetch(id) }.find { |object| object['isa'] == 'PBXFrameworksBuildPhase' }
  check.call(phase.fetch('files').any? { |id| objects.fetch(id)['productRef'] == ui_id }, "#{name} includes KSPlayerUI in its framework phase")
end

%w[KakaMusicPlayer.swift KakaMusicPlayer+Delegate.swift].each do |name|
  source = File.read(File.join(root, 'Mobie/Mobie/Base/Music', name))
  check.call(source.match?(/^import KSPlayerUI$/), "#{name} imports the split UI module")
end
delegate = File.read(File.join(root, 'Mobie/Mobie/Base/Music/KakaMusicPlayer+Delegate.swift'))
check.call(delegate.include?('action: KSPlayerUI.PlayerButtonType'), 'Action callback uses the new owning module')
check.call(!delegate.include?('KSPlayer.PlayerButtonType'), 'No stale core-module qualification')
puts "Passed #{checks} KSPlayerUI module/linkage checks"
