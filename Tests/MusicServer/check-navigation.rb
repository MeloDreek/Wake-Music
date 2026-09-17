require 'pathname'

root = Pathname.new(__dir__).join('../..').realpath
coordinator = root.join('Mobie/Mobie/Business/MusicServerModule/Navigation/AppModeCoordinator.swift').read
access = root.join('Mobie/Mobie/Business/ConnectModule/Controller/ConnectListViewController+Access.swift').read
checks = 0
assert = lambda do |condition, message|
  raise message unless condition
  checks += 1
end

# Structural regression checks supplement the two-account simulator round trip.
# A transaction completion can wait forever when root setup starts repeat animations.
assert.call(!coordinator.include?('CATransaction.'), 'Do not tie navigation availability to an animation transaction')
assert.call(coordinator.include?('defer { self.isSwitching = false }'), 'Always release the switch gate after replacement')
assert.call(coordinator.index('defer { self.isSwitching = false }') < coordinator.index('guard let window else { return }', coordinator.index('let replace =')), 'Release the gate even if the window disappears')
assert.call(coordinator.include?('window.layer.removeAnimation(forKey: "musicServerModeTransition")'), 'Replace an in-flight transition on rapid switches')
assert.call(coordinator.include?('CATransitionType(rawValue: "cube")'), 'Keep the requested cube transition')
assert.call(coordinator.include?('!kaka_IsMacOS() && !UIAccessibility.isReduceMotionEnabled'), 'Mac and Reduce Motion must not animate')
assert.call(coordinator.include?('returning != rtl'), 'Transition direction must respect RTL')
assert.call(coordinator.include?('context.cgContext.scaleBy(x: -1, y: 1)'), 'Bake the mirrored SF Symbol before UIBarButtonItem reconfiguration')
assert.call(coordinator.include?('imageFlippedForRightToLeftLayoutDirection()'), 'Mirror the exit glyph back for RTL')
assert.call(access.include?('AppModeCoordinator.enterNavidrome(navUser, from: self)'), 'Saved Navidrome accounts must enter the module directly')
%w[UI/MusicServerHomeViewController.swift Navigation/MusicServerRootControllers.swift].each do |file|
  assert.call(root.join('Mobie/Mobie/Business/MusicServerModule', file).read.include?('AppModeCoordinator.exitImage'), 'Home and split sidebar must share the exit glyph')
end
puts "Navigation source invariants passed (#{checks} checks); validate visual LTR/RTL and account round trips in Simulator as well."
