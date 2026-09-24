#!/usr/bin/env ruby
# Executes the production geometry with Foundation; no iOS runtime or account needed.
require 'tmpdir'
require 'open3'

root = File.expand_path('../..', __dir__)
source_path = File.join(root, 'Mobie/Mobie/Business/OtherModule/TabbarModule/iOS/PlayerControlToolBarView.swift')
source = File.read(source_path)
geometry = source[/enum PlayerMinibarGeometry \{.*?\n\}/m] or abort 'Production geometry not found'
Dir.mktmpdir('wakemusic-minibar-tests-') do |dir|
  production = File.join(dir, 'PlayerMinibarGeometry.swift')
  File.write(production, "import Foundation\nimport CoreGraphics\n#{geometry}\n")
  executable = File.join(dir, 'tests')
  command = ['xcrun', 'swiftc', '-module-cache-path', File.join(dir, 'module-cache'), production,
    File.join(__dir__, 'PlayerMinibarGeometryTests.swift'), '-o', executable]
  out, status = Open3.capture2e(*command)
  abort out unless status.success?
  system(executable) or abort 'Geometry tests failed'
end

# Guard the ownership contract: folding must not create sessions/queues or roots.
navigation = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Navigation/MusicServerRootControllers.swift'))
adaptive = navigation[/final class MusicServerAdaptiveRootController:.*?(?=\n@MainActor\nfinal class MusicServerSplitViewController)/m] or abort 'Adaptive root not found'
checks = {
  'persistent tab owner' => adaptive.include?('private let tabs: MusicServerTabBarController'),
  'secondary owns tabs' => adaptive.include?('UINavigationController(rootViewController: tabs)'),
  'compact chooses secondary' => adaptive.include?('return .secondary'),
  'selection preserves navigation stacks' => adaptive.include?('tabs.selectedIndex = destination.rawValue'),
  'both collapse and expansion reconcile UI' => adaptive.include?('splitViewControllerDidCollapse') && adaptive.include?('splitViewControllerDidExpand'),
  'no root/session/player reset during folding' => !adaptive.match?(/rootViewController\s*=|MusicServerSession\(|resetToPausedDemo|restoreRemoteQueueIfNeeded/),
  'tab visibility does not rebuild destinations' => adaptive.include?('tabs.setTabBarHidden(hasSidebar, animated: false)')
}
checks.each { |name, passes| abort "FAILED: #{name}" unless passes }
puts "Passed #{checks.length} adaptive navigation ownership checks"
