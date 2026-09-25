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

# Guard root routing independently of the UIKit probe: iPhone (including wide
# Duo) stays a direct tab root, while iPad and Mac retain their original split.
navigation = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Navigation/MusicServerRootControllers.swift'))
coordinator = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/Navigation/AppModeCoordinator.swift'))
routing = coordinator[/private func makeServerRoot\(.*?\n    \}/m] or abort 'Production root routing not found'
tabs = navigation[/final class MusicServerTabBarController:.*?\n\}/m] or abort 'Production tab root not found'
split = navigation[/final class MusicServerSplitViewController:.*?\n\}/m] or abort 'Original split root not found'
home = File.read(File.join(root, 'Mobie/Mobie/Business/MusicServerModule/UI/NavidromeHomeViewController.swift'))
checks = {
  'iPad and Mac keep original split root' => routing.match?(/if UIDevice\.current\.userInterfaceIdiom == \.pad \|\| kaka_IsMacOS\(\)\s*\{\s*return MusicServerSplitViewController\(session: session, onExit: exit\)\s*\}/),
  'phone returns direct tabs regardless of size class' => routing.match?(/return MusicServerTabBarController\(session: session, onExit: exit\)\s*\}\z/) && !routing.match?(/horizontalSizeClass|traitCollection|#available/),
  'nested adaptive root is removed' => !navigation.include?('MusicServerAdaptiveRootController') && !routing.include?('MusicServerAdaptiveRootController'),
  'tabs directly own destination navigation controllers' => tabs.include?('viewControllers = MusicServerDestination.allCases.map') && tabs.include?('KakaNavigationController(rootViewController: controller)'),
  'no split shell callback or forced tab hiding' => !tabs.match?(/onSelectedDestination|setTabBarHidden|rootViewController\s*=|MusicServerSession\(|resetToPausedDemo/),
  'original split retains destination navigation cache' => split.include?('private var destinations: [MusicServerDestination: UINavigationController]') && split.include?('if let existing = destinations[destination]'),
  'home keeps its existing classic exit action' => home.include?('AppModeCoordinator.exitImage') && home.include?('navigationItem.leftBarButtonItem = exit')
}
checks.each { |name, passes| abort "FAILED: #{name}" unless passes }
puts "Passed #{checks.length} navigation routing/ownership checks"
