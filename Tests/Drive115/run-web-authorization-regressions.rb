#!/usr/bin/env ruby
require 'tmpdir'
root = File.expand_path('../..', __dir__)
ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
source = File.read(File.join(root, 'Mobie/Mobie/Business/ImportModule/Controller/Auth115LifeViewController.swift'))
helper = source[/enum Drive115WebOAuth \{.*?(?=\nextension Auth115LifeViewController \{)/m]
abort 'Production OAuth helper not found' unless helper
build = Dir.mktmpdir('wakemusic-115-web-tests-')
file = File.join(build, 'WebAuthorization.swift')
File.write(file, File.read(File.join(__dir__, 'WebAuthorizationRegression.swift')) + "\n" + helper)
abort 'Compilation failed' unless system('xcrun', '--sdk', 'macosx', 'swiftc', '-swift-version', '5', '-parse-as-library', '-module-cache-path', File.join(build, 'modules'), file, '-o', File.join(build, 'tests'))
abort 'Regression failed' unless system(File.join(build, 'tests'))
abort 'Unexpected credential logging' if source.match?(/debugPrint.*(responseString|parameters|codeVerifier|absoluteString)/)
abort 'POST redirect protection missing' unless source.scan('Redirector(behavior: .doNotFollow)').count == 4
abort 'Cancellation not wired' unless source.include?('request?.cancel()') && source.include?('pollWork?.cancel()')
puts 'Credential logging, POST redirect and cancellation wiring checks passed'
