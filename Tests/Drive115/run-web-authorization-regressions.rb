#!/usr/bin/env ruby
require 'tmpdir'
require 'json'
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
inspection = source[/func webView\(_ webView: WKWebView, didFinish navigation: WKNavigation!\).*?(?=\n    func webView)/m]
abort 'Official-page guard missing' unless inspection&.include?('Drive115WebOAuth.isAuthorizationPage(pageURL)')
abort 'Stale web inspection guard missing' unless inspection.include?('self.attempt == id') && inspection.include?('navigation === self.activeWebNavigation') && inspection.include?('webView.url == pageURL')
abort 'Unbounded page inspection' unless inspection.include?('document.body.innerText.length <= 16384')
fallback = source[/private func showRedirectDomainFailure\(\).*?(?=\n    \/\/ QR fallback)/m]
abort 'QR fallback not wired' unless fallback&.include?('self.refreshAuthQrCode()') && fallback.include?('self.attempt == id')
abort 'Repeated-alert guard missing' unless fallback.include?('webState != nil') && fallback.index('stopAuthorization()') < fallback.index('showTwoAlert(')
catalog = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings')))['strings']
translations = catalog.fetch('Drive115.WebLogin.DomainReview').fetch('localizations')
expected = catalog.fetch('Scan QR Code').fetch('localizations').keys | ['en']
abort 'Missing domain-review localization' unless (expected - translations.keys).empty?
abort 'Empty domain-review localization' unless translations.values.all? { |entry| !entry.fetch('stringUnit').fetch('value').strip.empty? }
puts "Domain-error handling wiring and #{translations.size} localizations checked"
