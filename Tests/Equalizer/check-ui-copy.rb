require 'json'
root = File.expand_path('../..', __dir__)
strings = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings'))).fetch('strings')
locales = strings.fetch('EQ.Title').fetch('localizations').keys.sort
keys = %w[EQ.ListeningGuide EQ.PremiumPrompt classical pop hip-hop r&b electronic blues country metal reggae soul punk folk latin ambient soundtrack disco]
keys.each do |key|
  translations = strings.fetch(key).fetch('localizations')
  raise "Missing locales: #{key}" unless (locales - translations.keys - ['en']).empty?
  translations.each do |locale, value|
    unit = value.fetch('stringUnit')
    raise "Untranslated #{key}/#{locale}" unless unit['state'] == 'translated' && !unit['value'].strip.empty?
  end
end
source = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/Controller/PlayerEqualizerViewController.swift'))
presets = source.split('private func makePresetsPanel()', 2).last.split('private func makeBandsPanel()', 2).first
raise 'Presets must not scroll horizontally' if presets.include?('UIScrollView')
raise 'Missing factory presets' unless presets.include?('PlayerEqualizerPreset.factoryPresets')
preamp = source.split('private func makePreampPanel()', 2).last.split('private func makeResetButton()', 2).first
catalyst = preamp.gsub(/#if !targetEnvironment\(macCatalyst\).*?#endif/m, '')
raise 'Unsupported Catalyst slider styling' if catalyst.match?(/TrackTintColor|setThumbImage/)
raise 'Missing confirmation before paywall' unless source.include?('showTwoAlert(message: "EQ.PremiumPrompt".localStr()')
raise 'Banner bypasses confirmation' if source.include?('premiumButton.addTarget(self, action: #selector(vipCenterClick)')
puts "PASS_EQ_UI_COPY #{keys.count} titles/messages across #{locales.count} locales; wrapping, Catalyst guard, confirmation."
