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
exchange = source[/exchangeToken\(url: "https:\/\/passportapi\.115\.com\/open\/authCodeToToken", parameters: \[(.*?)\], id: attempt\)/m]
abort 'Authorization-code exchange missing' unless exchange
abort 'OAuth must use AppSecret, never AppKey' unless exchange.match?(/"client_secret":\s*Drive115_AppSecret\b/) && !exchange.include?('Drive115_AppKey')
abort 'Stale ambiguous credential name' if source.include?('Drive115_ClientSecret')
abort 'OAuth redirect differs from authorization request' unless exchange.match?(/"redirect_uri":\s*Drive115_RedirectURL\b/)
abort 'QR fallback must retain ClientID' unless source.match?(/"client_id":\s*Drive115_ClientID,\s*"code_challenge":\s*generatePKCE\(\)/m)
puts '5 AppSecret/ClientID/redirect credential wiring checks passed'
