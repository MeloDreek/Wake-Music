#!/usr/bin/env ruby
require 'tmpdir'
require 'open3'
root = File.expand_path('../..', __dir__)
ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
build = Dir.mktmpdir('wakemusic-collection-tests-')
source = %w[Singer Album Genre].map do |name|
  File.read(File.join(root, "Mobie/Mobie/Business/MusicModule/Model/MusicViewModel+#{name}.swift"))
    .lines.reject { |line| line.start_with?('import ') }.join
end.join("\n")
file = File.join(build, 'Grouping.swift')
File.write(file, File.read(File.join(__dir__, 'GroupingRegression.swift')) + "\n" + source)
abort 'Compilation failed' unless system('xcrun', '--sdk', 'macosx', 'swiftc', '-swift-version', '5', '-parse-as-library', '-module-cache-path', File.join(build, 'modules'), file, '-o', File.join(build, 'tests'))
abort 'Regression failed' unless system(File.join(build, 'tests'))
