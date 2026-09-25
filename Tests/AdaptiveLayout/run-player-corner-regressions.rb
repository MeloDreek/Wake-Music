#!/usr/bin/env ruby
require 'tmpdir'
require 'open3'

root = File.expand_path('../..', __dir__)
source = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/Controller/MusicPlayerViewController.swift'))
method = source[/    private func updatePresentationCorners\(\) \{.*?^    \}/m]
policy = source[/    var shouldRoundTopCorners: Bool \{.*?^    \}/m]
abort 'Production corner method or PanModal policy was not found' unless method && policy

# Check compatibility boundaries as well as the real UIKit corner resolution.
code = method.gsub(%r{//[^\n]*}, '')
unless code.match?(/\A\s*private func updatePresentationCorners\(\) \{\s*#if !targetEnvironment\(macCatalyst\).*#endif\s*\}\s*\z/m)
  abort 'Adaptive player corners must remain excluded from Mac Catalyst'
end
abort 'The adaptive path must require iOS 26' unless code.match?(/guard #available\(iOS 26\.0, \*\)/)
unless policy.match?(/if #available\(iOS 26\.0, \*\) \{ return false \}\s*return true/)
  abort 'PanModal must retain its legacy corner fallback before iOS 26'
end
if code.match?(/\b(?:UIScreen|UIDevice|utsname|sysctl|uname)\b|hw\.machine|["'](?:iPhone|Duo)/)
  abort 'Adaptive corners must follow container geometry without device-model or screen lookups'
end
abort 'Player layout must refresh presentation corners' unless source.match?(/override func viewDidLayoutSubviews\(\) \{\s*super\.viewDidLayoutSubviews\(\)\s*updatePresentationCorners\(\)/)
puts 'Passed production availability, Catalyst exclusion, fallback, and device-independent wiring checks.'

def command_output(*arguments)
  output, status = Open3.capture2(*arguments)
  abort "Command failed: #{arguments.join(' ')}" unless status.success?
  output.strip
end

Dir.mktmpdir('wake-player-corners-') do |directory|
  production = File.join(directory, 'PlayerCornerProbe.swift')
  File.write(production, <<~SWIFT)
    import UIKit
    // Only the third-party presentation holder is stubbed. The complete corner
    // update method and availability policy below are extracted from production.
    final class PanModalPresentationController {
        let presentedView: UIView
        init(surface: UIView) { presentedView = surface }
    }
    final class PlayerCornerProbe {
        let presentationController: AnyObject?
        init(surface: UIView) {
            presentationController = PanModalPresentationController(surface: surface)
        }
    #{method.sub('private func', 'func')}
    #{policy}
    }
  SWIFT
  sdk = command_output('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
  architecture = command_output('uname', '-m')
  executable = File.join(directory, 'player-corner-tests')
  abort 'Compilation failed' unless system(
    'xcrun', '--sdk', 'iphonesimulator', 'swiftc',
    '-target', "#{architecture}-apple-ios26.0-simulator", '-sdk', sdk,
    '-module-cache-path', File.join(directory, 'module-cache'),
    production, File.join(__dir__, 'PlayerCornerRegression.swift'), '-o', executable
  )
  unless ARGV.include?('--build-only')
    simulator = ARGV.find { |argument| !argument.start_with?('--') } || ENV.fetch('LAYOUT_SIMULATOR_UDID', 'booted')
    abort 'Player corner regressions failed' unless system('xcrun', 'simctl', 'spawn', simulator, executable)
  end
end
