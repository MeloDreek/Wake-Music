#!/usr/bin/env ruby
require 'tmpdir'
require 'fileutils'
root = File.expand_path('../..', __dir__)
source = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/Model/OrientationManager.swift'))
policy = source[/struct PlayerViewportLayout \{.*?^\}/m]
abort 'Production layout policy was not found' unless policy
Dir.mktmpdir('wake-player-layout-') do |directory|
  path = File.join(directory, 'PlayerViewportLayout.swift')
  File.write(path, "import Foundation\n" + policy + "\n")
  executable = File.join(directory, 'player-layout-tests')
  abort 'Compilation failed' unless system('xcrun', 'swiftc', '-module-cache-path', File.join(directory, 'module-cache'), path,
    File.join(__dir__, 'PlayerLayoutRegression.swift'), '-o', executable)
  abort 'Player layout regressions failed' unless system(executable)
end
