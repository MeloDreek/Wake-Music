# Compile the real return action against navigation-boundary doubles. No app launch.
require 'tmpdir'
root = File.expand_path('../..', __dir__)
engine = File.read(File.join(root, 'Mobie/Mobie/Business/OtherModule/ProfileModule/Controller/PlayerEngineViewController.swift'))
eq = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/Controller/PlayerEqualizerViewController.swift'))
start = engine.index('    @objc func cancelBarClick() {') or raise 'Missing engine return action'
opening = engine.index('{', start)
depth = 0
ending = nil
engine[opening..].each_char.with_index do |char, index|
  depth += 1 if char == '{'
  depth -= 1 if char == '}'
  if depth.zero?
    ending = opening + index
    break
  end
end
action = engine[start..ending].sub('@objc ', '')
raise 'Missing engine entry' unless eq.include?('navigationItem.rightBarButtonItem = engine') && eq.include?('#selector(showPlayerEngine)')
raise 'Missing localized entry label' unless eq.include?('engine.accessibilityLabel = SettingCellItemType.selectPlayer.titleStr()')
raise 'Missing push route' unless eq.include?('navigationController.pushViewController(engine, animated: true)')
raise 'Pushed engine page must preserve Back' unless engine.include?('navigationController?.viewControllers.first === self')
source = <<~SWIFT
  import Foundation
  class Screen {
      var navigationController: Navigation?
      var dismissals = 0
      func dismiss(animated: Bool) { dismissals += 1 }
  }
  final class Navigation: Screen {
      var viewControllers: [Screen] = []
      var pops = 0
      func popViewController(animated: Bool) { pops += 1; viewControllers.removeLast() }
  }
  final class EngineScreen: Screen {
  #{action}
  }
  let eq = Screen()
  let pushed = EngineScreen()
  let stack = Navigation()
  stack.viewControllers = [eq, pushed]
  pushed.navigationController = stack
  pushed.cancelBarClick()
  precondition(stack.pops == 1 && stack.viewControllers.first === eq)
  precondition(stack.dismissals == 0 && pushed.dismissals == 0, "Do not dismiss EQ's sheet")
  let modal = EngineScreen()
  let modalNavigation = Navigation()
  modalNavigation.viewControllers = [modal]
  modal.navigationController = modalNavigation
  modal.cancelBarClick()
  precondition(modalNavigation.dismissals == 1 && modalNavigation.pops == 0)
  let standalone = EngineScreen()
  standalone.cancelBarClick()
  precondition(standalone.dismissals == 1)
  print("PASS_EQ_ENGINE_NAVIGATION pushed, modal, standalone; localized right entry")
SWIFT
Dir.mktmpdir('eq-navigation-', '/private/tmp') do |dir|
  file = File.join(dir, 'Navigation.swift')
  File.write(file, source)
  ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
  abort 'Navigation probe compile failed' unless system('xcrun', '--sdk', 'macosx', 'swiftc', '-module-cache-path', File.join(dir, 'modules'), file, '-o', File.join(dir, 'probe'))
  abort 'Navigation probe failed' unless system(File.join(dir, 'probe'))
end
