require 'json'

root = File.expand_path('../..', __dir__)
strings = JSON.parse(File.read(File.join(root, 'Mobie/Mobie/System/Localizable.xcstrings'))).fetch('strings')
locales = %w[ar ca cs da de el en en-AU en-GB en-IN es es-419 es-US fi fr fr-CA he hi hr hu id it ja ko ms nb nl pl pt-BR pt-PT ro ru sk sl sv th tr uk vi zh-HK zh-Hans zh-Hant]
products = %w[Monthly Annual Lifetime FamilyLifetime]
product_keys = products.flat_map { |product| %w[Title Description].map { |kind| "Purchase.#{product}.#{kind}" } }
billing_keys = %w[Purchase.Billing.Monthly Purchase.Billing.Annual Purchase.Billing.Once]
placeholder_keys = billing_keys + %w[Purchase.FreeTrialDuration]
keys = product_keys + billing_keys + %w[Purchase.AllPlans Purchase.ProductsUnavailable Purchase.Recommended Purchase.RemoteAccessMessage Purchase.CrossPlatformBenefit Purchase.BestChoice Purchase.FamilySharingFooter Purchase.FreeTrialDuration]

keys.each do |key|
  translations = strings.fetch(key).fetch('localizations')
  raise "Wrong locale set for #{key}" unless translations.keys.sort == locales.sort
  translations.each do |locale, translation|
    unit = translation.fetch('stringUnit')
    value = unit.fetch('value')
    raise "Untranslated #{key}/#{locale}" unless unit['state'] == 'translated' && !value.strip.empty?
    limit = key.end_with?('.Title') ? 30 : key.end_with?('.Description') ? 45 : nil
    raise "Metadata too long: #{key}/#{locale} (#{value.length})" if limit && !value.length.between?(2, limit)
    raise "Invalid placeholder: #{key}/#{locale}" if placeholder_keys.include?(key) && value.scan('%@').length != 1
    if key == 'Purchase.FamilySharingFooter'
      raise "Missing family size: #{locale}" unless value.include?('5') && value.include?('6')
    end
  end
end

obsolete = [
  'Best Value: %d-Day Free Trial, then %@/year (Only %@/month)',
  'Lifetime Discount',
  'Limited Time Offer',
  'Limited Time Offer: Get Lifetime Access for %@ before the timer expires! Save %@ permanently.',
  'Save %@',
  'Time-limited purchase',
  'View All Benefits',
  'You get a lifetime premium discount!',
  'You have get a limited time offer for the Lifetime Premium',
  'You’ve received a one-time lifetime offer!',
  'Upgrade to Premium at the lowest price currently available to unlock all remote features, plus upcoming Apple Watch and native CarPlay support.',
  'One-time purchase. Unlock all features on iPhone, iPad, and Mac.',
  'Congratulations!'
]
obsolete.each { |key| raise "Obsolete promotional copy remains: #{key}" if strings.key?(key) }

document = File.read(File.join(root, 'Documentation/PurchaseProductLocalizations.md'))
raise 'Missing localization tables' unless document.scan(/^### /).length == locales.length
rows = document.lines.grep(/^\| `(Monthly|Annual|Lifetime|FamilyLifetime)` \|/)
raise 'Wrong product row count' unless rows.length == products.length * locales.length
locales.each do |locale|
  section = document.split("（#{locale}）\n\n", 2).last&.split(/^### /, 2)&.first
  raise "Missing table for #{locale}" unless section
  products.each do |product|
    title = strings.fetch("Purchase.#{product}.Title").dig('localizations', locale, 'stringUnit', 'value')
    description = strings.fetch("Purchase.#{product}.Description").dig('localizations', locale, 'stringUnit', 'value')
    row = "| `#{product}` | #{title} | #{description} |"
    raise "Table/catalog mismatch: #{locale}/#{product}" unless section.include?(row)
  end
end

puts "PASS_PURCHASE_LOCALIZATIONS #{keys.length} keys × #{locales.length} locales; #{rows.length} product rows; metadata lengths, billing/trial placeholders, and family size valid."
