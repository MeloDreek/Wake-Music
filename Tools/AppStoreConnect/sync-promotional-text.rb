#!/usr/bin/env ruby
# frozen_string_literal: true
# Standard edition 3.6.0 only. Never changes other metadata or submits a version.
require_relative 'sync-app-descriptions'

module PromotionalTextSync
  Error = AppDescriptionSync::Error
  TARGETS = AppDescriptionSync::TARGETS.select { |t| t[4] == 'standard' }.freeze
  class Client < AppDescriptionSync::Client
    def metadata_field
      'promotionalText'
    end
    def request(method, path, body = nil)
      if method != 'GET'
        value = body&.dig('data', 'attributes', 'promotionalText')
        raise Error, 'Promotional text must be 1–170 UTF-16 units.' unless value.is_a?(String) && (value.encode('UTF-16LE').bytesize / 2).between?(1, 170)
      end
      super
    end
  end

  def self.validate_version!(client, target)
    app_id, bundle, platform, version_id, edition = target
    app = client.request('GET', "/v1/apps/#{app_id}").fetch('data')
    versions = client.list("/v1/apps/#{app_id}/appStoreVersions?limit=200")
    version = versions.find { |v| v['id'] == version_id }
    attrs = version && version['attributes']
    unless app_id == '6544783918' && edition == 'standard' && bundle == 'com.OfflineMusic.www' &&
           app.dig('attributes','bundleId') == bundle && attrs && attrs['platform'] == platform &&
           attrs['versionString'] == '3.6.0'
      raise Error, "Target identity changed: #{version_id}"
    end
    # Promotional text is independently editable; never change review state to make a write succeed.
    # Apple remains authoritative about whether this field can be updated in the current state.
    puts "Verified #{platform} 3.6.0 (#{attrs['appStoreState']})"
    version
  end

  def self.main
    opts = {}
    OptionParser.new do |p|
      p.on('--key-file PATH') { |v| opts[:key_path] = v }
      p.on('--key-id ID') { |v| opts[:key_id] = v }
      p.on('--issuer-id ID') { |v| opts[:issuer_id] = v }
      p.on('--output PATH') { |v| opts[:output] = v }
      p.on('--apply') { opts[:apply] = true }
      p.on('--validate') { opts[:validate] = true }
    end.parse!
    raise Error, 'Unexpected arguments' unless ARGV.empty?
    texts = JSON.parse(File.read(File.join(AppDescriptionSync::ROOT, 'promotional-text.json'), encoding: 'UTF-8'))
    raise Error, 'Locale set mismatch' unless texts.keys.sort == AppDescriptionSync::LOCALES
    texts.each do |locale, value|
      raise Error, "Invalid text: #{locale}" unless value.is_a?(String) && value == value.strip && !value.include?("\n") && (value.encode('UTF-16LE').bytesize / 2).between?(1,170)
    end
    puts "Validated #{texts.size} locales; maximum #{texts.values.map { |s| s.encode('UTF-16LE').bytesize / 2 }.max}/170 units."
    return if opts[:validate]
    %i[key_path key_id issuer_id output].each { |k| raise Error, "Missing #{k}" unless opts[k] }
    raise Error, 'Output already exists' if File.exist?(opts[:output])
    raise Error, 'Unexpected key size' unless File.size(opts[:key_path]).between?(100,16_384)
    c = Tempfile.create(['wake-promo-key', '.p8']) do |f|
      f.chmod(0600)
      f.write(File.binread(opts[:key_path])); f.flush
      Client.new(key_path:f.path, key_id:opts[:key_id], issuer_id:opts[:issuer_id])
    end
    snapshot = TARGETS.map do |t|
      validate_version!(c,t)
      rows = c.list("/v1/appStoreVersions/#{t[3]}/appStoreVersionLocalizations?limit=200")
      raise Error, "Unexpected locales: #{t[2]}" unless rows.map { |r| r.dig('attributes','locale') }.sort == texts.keys.sort
      {'target'=>t, 'localizations'=>rows}
    end
    FileUtils.mkdir_p(opts[:output], mode:0700)
    AppDescriptionSync.save(opts[:output], 'before.json', snapshot)
    plan = snapshot.flat_map do |s|
      s['localizations'].map do |l|
        locale = l.dig('attributes','locale')
        {'id'=>l['id'], 'platform'=>s['target'][2], 'locale'=>locale, 'promotionalText'=>texts.fetch(locale),
         'action'=>l.dig('attributes','promotionalText') == texts.fetch(locale) ? 'unchanged' : 'update'}
      end
    end
    AppDescriptionSync.save(opts[:output], 'plan.json', plan)
    puts "#{opts[:apply] ? 'APPLY' : 'DRY-RUN'}: #{plan.size} standard-edition localizations across iOS/macOS; #{plan.count { |p| p['action'] == 'update' }} changes."
    return unless opts[:apply]
    c.allowed_ids = plan.map { |p| p['id'] }
    completed = []
    begin
      snapshot.each do |s|
        validate_version!(c,s['target'])
        s['localizations'].each do |old|
          path = "/v1/appStoreVersionLocalizations/#{old['id']}"
          latest = c.request('GET',path).fetch('data')
          raise Error, 'Concurrent metadata edit; stopped' unless latest['attributes'] == old['attributes']
          text = texts.fetch(old.dig('attributes','locale'))
          if latest.dig('attributes','promotionalText') != text
            c.request('PATCH',path,{'data'=>{'type'=>'appStoreVersionLocalizations','id'=>old['id'],'attributes'=>{'promotionalText'=>text}}})
          end
          completed << old['id']
          puts "#{completed.size}/#{plan.size} #{s['target'][2]} #{old.dig('attributes','locale')}"
          STDOUT.flush
        end
      end
      verified = snapshot.map do |s|
        rows = c.list("/v1/appStoreVersions/#{s['target'][3]}/appStoreVersionLocalizations?limit=200")
        raise Error, 'Localization set changed' unless rows.map { |r| r['id'] }.sort == s['localizations'].map { |r| r['id'] }.sort
        rows.each do |r|
          old = s['localizations'].find { |l| l['id'] == r['id'] }
          expected = old.fetch('attributes').merge('promotionalText'=>texts.fetch(r.dig('attributes','locale')))
          raise Error, "Readback mismatch: #{r['id']}" unless r['attributes'] == expected
        end
        {'target'=>s['target'],'localizations'=>rows}
      end
      AppDescriptionSync.save(opts[:output], 'verified.json', verified)
      puts "VERIFIED #{completed.size} promotional texts. Other metadata unchanged; Pro untouched; nothing submitted."
    ensure
      AppDescriptionSync.save(opts[:output], 'completed.json', completed)
    end
  rescue Error, KeyError, OptionParser::ParseError => e
    warn "STOPPED: #{e.message}"
    exit 1
  end
end

PromotionalTextSync.main if $PROGRAM_NAME == __FILE__
