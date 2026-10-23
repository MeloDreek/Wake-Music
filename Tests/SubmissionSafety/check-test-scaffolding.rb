#!/usr/bin/env ruby
# Keep development fixtures out of production UI. This does not prohibit tests,
# diagnostic logging, platform guards, or the disclosed bundled demo audio.
require 'pathname'

root = Pathname.new(File.expand_path('../..', __dir__))
app = root.join('Mobie/Mobie')
checks = 0
check = lambda do |condition, message|
  abort("FAIL: #{message}") unless condition
  checks += 1
end
read = ->(relative) { app.join(relative).read }
auth_path = 'Business/ImportModule/Controller'
%w[AuthNavidromeController AuthWebdavViewController AuthFTPViewController AuthSMBViewController AuthMEGAViewController].each do |name|
  source = read.call("#{auth_path}/#{name}.swift")
  check.call(!source.match?(/#if\s+!?DEBUG\b/), "#{name}: no Debug-only account substitution")
end

%w[AuthNavidromeController AuthWebdavViewController].each do |name|
  source = read.call("#{auth_path}/#{name}.swift")
  initializer = source[/    init\(_ model:.*?(?=\n    @MainActor)/m]
  check.call(initializer&.include?('self.loginModel = model'), "#{name}: preserve the supplied account")
  check.call(initializer && !initializer.match?(/(?:NavidromeUserModel|WebdavUserModel)\s*\(/), "#{name}: no hard-coded test-account constructor")
end
%w[AuthFTPViewController AuthSMBViewController].each do |name|
  source = read.call("#{auth_path}/#{name}.swift")
  check.call(source.include?('.host: user?.host ?? ""'), "#{name}: use the existing host or an empty field")
  check.call(source.include?('.username: user?.username ?? "", .password: ""'), "#{name}: do not prefill a test credential")
end
mega = read.call("#{auth_path}/AuthMEGAViewController.swift")
check.call(mega.include?('emailField.text = account?.email'), 'MEGA: retain the existing account email')
check.call(!mega.match?(/(?:emailField|passwordField)\.text\s*=\s*"/), 'MEGA: no fixture overwrites entered/existing credentials')

sources = Dir.glob(app.join('**/*.swift').to_s).map { |path| File.read(path) }
check.call(sources.none? { |source| source.include?('模拟mock数据') }, 'No obsolete mock screenshot warning markers')
check.call(sources.none? { |source| source.match?(/^\s*\/\/\s*#if\s+!?DEBUG\b/) }, 'No commented Debug-only UI fixture blocks')
check.call(sources.none? { |source| source.include?('ProcessInfo.processInfo.arguments') || source.include?('ProcessInfo.processInfo.environment') }, 'No launch-argument/environment feature or fixture switches in the app')

demo = read.call('Base/Core/Extension/MusicItemModel+Kaka.swift')
check.call(demo.include?('demoMusicModel'), 'Keep the actual product demo instead of deleting legitimate demo behavior')
check.call(root.join('Tests').directory?, 'Keep isolated regression tests outside the app sources')
puts "#{checks} test-scaffolding checks passed"
