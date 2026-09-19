require 'json'
root = File.expand_path('../..', __dir__)
strings = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings'))).fetch('strings')
locales = strings.fetch('EQ.Title').fetch('localizations').keys.sort
keys = %w[EQ.ListeningGuide EQ.PremiumPrompt EQ.Custom EQ.BassReduction EQ.Treble EQ.TrebleReduction EQ.Warmth EQ.Clarity EQ.Soft EQ.PresetsGuide classical pop hip-hop r&b electronic blues country metal reggae soul punk folk latin ambient soundtrack disco]
keys.each do |key|
  translations = strings.fetch(key).fetch('localizations')
  raise "Missing locales: #{key}" unless (locales - translations.keys - (key.start_with?('EQ.') ? [] : ['en'])).empty?
  translations.each do |locale, value|
    unit = value.fetch('stringUnit')
    raise "Untranslated #{key}/#{locale}" unless unit['state'] == 'translated' && !unit['value'].strip.empty?
  end
end
source = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/Controller/PlayerEqualizerViewController.swift'))
presets = source.split('private func makePresetsPanel()', 2).last.split('private func makeBandsPanel()', 2).first
raise 'Preset gestures must yield vertical swipes to page' unless presets.include?('scrollView.panGestureRecognizer.require(toFail: grid.scrollView.panGestureRecognizer)')
raise 'Missing curated presets and Custom' unless presets.include?('PlayerEqualizerPreset.displayedPresets')
raise 'Missing preset guidance' unless presets.include?('"EQ.PresetsGuide".localStr()')
raise 'Missing audio-engine navigation entry' unless source.include?('navigationItem.rightBarButtonItem = engine') && source.include?('engine.accessibilityLabel = SettingCellItemType.selectPlayer.titleStr()')
raise 'Engine entry must open its existing settings page' unless source.include?('let engine = PlayerEngineViewController()') && source.include?('navigationController.pushViewController(engine, animated: true)')
engine = File.read(File.join(root, 'Mobie/Mobie/Business/OtherModule/ProfileModule/Controller/PlayerEngineViewController.swift'))
raise 'Pushed engine settings must return to EQ' unless engine.include?('navigationController.viewControllers.first !== self') && engine.include?('navigationController.popViewController(animated: true)')
preamp = source.split('private func makePreampPanel()', 2).last.split('private func makeResetButton()', 2).first
catalyst = preamp.gsub(/#if !targetEnvironment\(macCatalyst\).*?#endif/m, '')
raise 'Unsupported Catalyst slider styling' if catalyst.match?(/TrackTintColor|setThumbImage/)
raise 'Missing confirmation before paywall' unless source.include?('showTwoAlert(message: "EQ.PremiumPrompt".localStr()')
raise 'Banner bypasses confirmation' if source.include?('premiumButton.addTarget(self, action: #selector(vipCenterClick)')
puts "PASS_EQ_UI_COPY #{keys.count} titles/messages across #{locales.count} locales; curated presets, Custom, engine navigation, horizontal browsing, Catalyst guard, confirmation."
