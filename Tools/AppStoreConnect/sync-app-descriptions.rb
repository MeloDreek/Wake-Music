#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative 'sync-purchase-localizations'
require 'tempfile'
require 'fileutils'

module AppDescriptionSync
  Error = PurchaseLocalizationSync::Error
  ROOT = File.expand_path('../../Documentation/AppStore/3.6.0', __dir__)
  LOCALES = (PurchaseLocalizationSync::SUPPORTED_ASC_LOCALES - ['sl-SI']).sort.freeze
  ALIASES = { 'en-CA' => 'en-US', 'en-GB' => 'en-US', 'en-AU' => 'en-US',
              'fr-CA' => 'fr-FR', 'es-MX' => 'es-ES' }.freeze
  LEGAL_LANGUAGES = %w[en zh-hans zh-hant ja ko de fr es pt-br it ru ar].freeze
  TARGETS = [
    ['6544783918', 'com.OfflineMusic.www', 'IOS', '026e2727-cc20-4253-87a7-0f634417fcb6', 'standard'],
    ['6544783918', 'com.OfflineMusic.www', 'MAC_OS', '0209638f-4c7e-4b5f-adee-4668e6694b03', 'standard'],
    ['6740429002', 'com.OfflineMusic.www.pro', 'IOS', 'def01ea4-4428-4a7c-93f5-65708ddce621', 'pro'],
    ['6740429002', 'com.OfflineMusic.www.pro', 'MAC_OS', 'd963eab9-b3c4-49fa-8ef4-c9578d16eccb', 'pro']
  ].freeze

  def self.legal_language(locale)
    value = { 'en-US'=>'en', 'en-CA'=>'en', 'en-AU'=>'en', 'en-GB'=>'en',
              'de-DE'=>'de', 'fr-FR'=>'fr', 'fr-CA'=>'fr', 'es-ES'=>'es',
              'es-MX'=>'es', 'ar-SA'=>'ar' }.fetch(locale, locale.downcase)
    LEGAL_LANGUAGES.include?(value) ? value : 'en'
  end

  def self.catalog
    LOCALES.to_h do |locale|
      source = ALIASES.fetch(locale, locale)
      raw = File.read(File.join(ROOT, 'source', "#{source}.txt"), encoding: 'UTF-8')
      raise Error, "Invalid sections: #{locale}" unless raw.scan('===STANDARD===').size == 1 && raw.scan('===PRO===').size == 1
      body, purchases = raw.split('===STANDARD===', 2)
      standard, pro = purchases.split('===PRO===', 2)
      raise Error, "Invalid purchase marker: #{locale}" unless body.scan('{{PURCHASE}}').size == 1
      values = { 'standard'=>standard, 'pro'=>pro }.to_h do |edition, purchase|
        text = body.gsub('{{PURCHASE}}', purchase.strip)
        %w[PRIVACY TERMS].each do |name|
          text = text.gsub("{{#{name}_URL}}", "https://kakainc.com/#{legal_language(locale)}/wakemusic/legal/app-store/#{name.downcase}/")
        end
        if %w[en-AU en-GB].include?(locale)
          text = text.gsub('organize', 'organise').gsub('favorite', 'favourite').gsub('Analyze', 'Analyse')
        end
        if locale == 'fr-CA'
          text = text.gsub('playlists', 'listes de lecture').gsub('en streaming', 'en continu')
                     .gsub('espaces cloud', 'espaces infonuagiques').gsub('aux clouds', 'aux services infonuagiques')
                     .gsub('l\'app', 'l\'application')
        elsif locale == 'es-MX'
          text = text.gsub('vídeos', 'videos').gsub('ordenador', 'computadora')
                     .gsub('con En familia', 'con Compartir en familia')
        end
        text = text.strip
        units = text.encode('UTF-16LE').bytesize / 2
        raise Error, "#{locale}/#{edition}: #{units} > 4000" unless units.between?(1000, 4000)
        raise Error, "Unresolved marker/bullet: #{locale}" if text.include?('{{') || text.include?('●') || text.include?('===')
        raise Error, "Wrong brand: #{locale}" if locale != 'zh-Hans' && text.match?(/维克|維克/)
        raise Error, "Missing brand/headings: #{locale}" unless text.include?('Wakemusic') && text.scan('◆◆◆').size == 8
        text.split('◆◆◆').drop(1).each do |section|
          numbers = section.scan(/^(\d+)\. /).flatten.map(&:to_i)
          raise Error, "Invalid numbering: #{locale}" unless numbers == (1..numbers.length).to_a
        end
        [edition, text]
      end
      [locale, values]
    end
  end

  class Client < PurchaseLocalizationSync::Client
    attr_accessor :allowed_ids
    def metadata_field
      'description'
    end
    def request(method, path, body = nil)
      return super if method == 'GET'
      id = path.delete_prefix('/v1/appStoreVersionLocalizations/')
      data = body && body['data']
      unless method == 'PATCH' && path == "/v1/appStoreVersionLocalizations/#{id}" && Array(allowed_ids).include?(id) &&
             body.keys == ['data'] && data.keys.sort == %w[attributes id type] && data['id'] == id &&
             data['type'] == 'appStoreVersionLocalizations' && data['attributes'].keys == [metadata_field] &&
             data['attributes'][metadata_field].is_a?(String) && data['attributes'][metadata_field].length.between?(1, 4000)
        raise Error, "Only discovered #{metadata_field} PATCH requests are permitted."
      end
      uri = URI("#{ORIGIN}#{path}")
      req = Net::HTTP::Patch.new(uri)
      req['Authorization'] = "Bearer #{token}"
      req['Content-Type'] = 'application/json'
      req.body = JSON.generate(body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 20
      http.read_timeout = 30
      http.max_retries = 0
      response = http.request(req)
      # Never retry an uncertain write; a fresh dry-run reconciles remote state.
      raise Error, "PATCH #{id}: HTTP #{response.code}; reconcile before retrying" unless response.code.to_i.between?(200, 299)
      JSON.parse(response.body)
    end
  end

  def self.save(dir, name, value)
    File.open(File.join(dir, name), File::WRONLY | File::CREAT | File::EXCL, 0600) { |f| f.write(JSON.pretty_generate(value)) }
  end

  def self.validate_version!(c, target)
    app_id, bundle, platform, version_id, = target
    app = c.request('GET', "/v1/apps/#{app_id}").fetch('data')
    version = c.request('GET', "/v1/appStoreVersions/#{version_id}").fetch('data')
    # Apple does not expose a readable inverse /app relationship here.
    owned_versions = c.list("/v1/apps/#{app_id}/appStoreVersions?limit=200")
    a = version.fetch('attributes')
    unless app.dig('attributes', 'bundleId') == bundle && owned_versions.any? { |v| v['id'] == version_id } &&
           a['versionString'] == '3.6.0' && a['platform'] == platform && a['appStoreState'] == 'PREPARE_FOR_SUBMISSION'
      raise Error, "Target identity/state changed: #{version_id}"
    end
    version
  end

  def self.sync(c, texts, output, apply, field: 'description', variant_index: 4)
    raise Error, 'Unsupported metadata field or variant.' unless %w[description whatsNew].include?(field) && [2,4].include?(variant_index)
    raise Error, 'Client field mismatch.' if c.respond_to?(:metadata_field) && c.metadata_field != field
    raise Error, 'Output must not already exist.' if File.exist?(output)
    FileUtils.mkdir_p(output, mode: 0700)
    snapshot = TARGETS.map do |target|
      v = validate_version!(c, target)
      rows = c.list("/v1/appStoreVersions/#{target[3]}/appStoreVersionLocalizations?limit=200")
      locales = rows.map { |r| r.dig('attributes', 'locale') }
      raise Error, "Unexpected locale set: #{target[3]}" unless locales.sort == LOCALES
      { 'target'=>target, 'version'=>v, 'localizations'=>rows }
    end
    save(output, 'before.json', snapshot)
    plan = snapshot.flat_map do |s|
      s['localizations'].map do |l|
        locale = l.dig('attributes', 'locale')
        text = texts.fetch(locale).fetch(s['target'][variant_index])
        { 'versionId'=>s['target'][3], 'id'=>l['id'], 'locale'=>locale, field=>text,
          'action'=>l.dig('attributes',field) == text ? 'unchanged' : 'update' }
      end
    end
    save(output, 'plan.json', plan)
    puts "#{apply ? 'APPLY' : 'DRY-RUN'} #{plan.group_by { |p| p['action'] }.transform_values(&:length)}"
    return unless apply
    c.allowed_ids = plan.map { |p| p['id'] }
    completed = []
    begin
      snapshot.each do |s|
        validate_version!(c, s['target'])
        plan.select { |p| p['versionId'] == s['target'][3] }.each do |p|
          old = s['localizations'].find { |r| r['id'] == p['id'] }
          latest = c.request('GET', "/v1/appStoreVersionLocalizations/#{p['id']}").fetch('data')
          raise Error, 'Concurrent metadata change; stopped.' unless latest['attributes'] == old['attributes']
          if p['action'] == 'update'
            c.request('PATCH', "/v1/appStoreVersionLocalizations/#{p['id']}",
                      { 'data'=>{ 'type'=>'appStoreVersionLocalizations', 'id'=>p['id'], 'attributes'=>{ field=>p[field] } } })
          end
          completed << p.slice('versionId','id','locale','action')
          puts "#{completed.length}/#{plan.length} #{s['target'][4]} #{s['target'][2]} #{p['locale']}"
          STDOUT.flush
        end
      end
      verified = snapshot.map do |s|
        validate_version!(c, s['target'])
        rows = c.list("/v1/appStoreVersions/#{s['target'][3]}/appStoreVersionLocalizations?limit=200")
        raise Error, 'Localization set changed.' unless rows.map { |l| l['id'] }.sort == s['localizations'].map { |l| l['id'] }.sort
        rows.each do |r|
          before = s['localizations'].find { |l| l['id'] == r['id'] }
          expected = before.fetch('attributes').merge(field=>texts.fetch(r.dig('attributes','locale')).fetch(s['target'][variant_index]))
          raise Error, "Verification mismatch: #{r['id']}" unless r['attributes'] == expected
        end
        { 'target'=>s['target'], 'localizations'=>rows }
      end
      save(output, 'verified.json', verified)
      puts "VERIFIED: #{plan.length} #{field} values. No other metadata changed. Not submitted."
    ensure
      save(output, 'completed.json', completed)
    end
  end

  def self.main
    options = {}
    OptionParser.new do |p|
      p.on('--key-file PATH') { |v| options[:key_path]=v }
      p.on('--key-id ID') { |v| options[:key_id]=v }
      p.on('--issuer-id ID') { |v| options[:issuer_id]=v }
      p.on('--output PATH') { |v| options[:output]=v }
      p.on('--apply') { options[:apply]=true }
      p.on('--validate') { options[:validate]=true }
      p.on('--render') { options[:render]=true }
    end.parse!
    texts = catalog
    puts "Validated #{texts.length} locales / #{texts.length * 2} edition texts; max #{texts.values.flat_map(&:values).map(&:length).max} characters."
    if options[:render]
      texts.each do |locale, editions|
        editions.each do |edition, text|
          folder = File.join(ROOT, 'descriptions', edition)
          FileUtils.mkdir_p(folder)
          File.write(File.join(folder, "#{locale}.txt"), text + "\n")
        end
      end
    end
    return if options[:validate] || options[:render]
    %i[key_path key_id issuer_id output].each { |k| raise Error, "Missing #{k}" unless options[k] }
    raise Error, 'Unexpected key size' unless File.size(options[:key_path]).between?(100,16_384)
    # Keep the user's file unchanged; securely stage only for in-memory key loading.
    c = Tempfile.create(['wake-description-key', '.p8']) do |f|
      f.chmod(0600)
      f.write(File.binread(options[:key_path])); f.flush
      Client.new(key_path:f.path, key_id:options[:key_id], issuer_id:options[:issuer_id])
    end
    sync(c, texts, options[:output], options[:apply])
  rescue Error, KeyError, OptionParser::ParseError => e
    warn "STOPPED: #{e.message}"
    exit 1
  end
end

AppDescriptionSync.main if $PROGRAM_NAME == __FILE__
