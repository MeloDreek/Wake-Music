#!/usr/bin/env ruby
# frozen_string_literal: true

# A deliberately narrow, one-version metadata tool. It cannot submit a review,
# change a build, create a locale, or modify a released Pro/macOS version.
require_relative 'sync-release-notes'

module ResubmissionReleaseNotesSync
  Error = ReleaseNotesSync::Error
  TARGET = {
    'appId' => '6544783918', 'bundleId' => 'com.OfflineMusic.www',
    'platform' => 'IOS', 'versionString' => '3.6.0',
    'versionId' => '026e2727-cc20-4253-87a7-0f634417fcb6'
  }.transform_values(&:freeze).freeze
  # A developer-withdrawn version remains editable; editing copy must not
  # restore its submission. Waiting/in-review/released states stay excluded.
  EDITABLE_STATES = %w[PREPARE_FOR_SUBMISSION READY_FOR_REVIEW REJECTED METADATA_REJECTED DEVELOPER_REJECTED].freeze
  LOCALES = AppDescriptionSync::LOCALES
  FIELD = 'whatsNew'

  class UniqueKeysHash < Hash
    def []=(key, value)
      raise Error, "Duplicate catalog key: #{key}" if key?(key)
      super
    end
  end

  def self.validate_text!(text, locale)
    raise Error, "Expected plain text: #{locale}" unless text.is_a?(String) && text.valid_encoding?
    units = text.encode('UTF-16LE').bytesize / 2
    unless units.between?(1, 4000) && text == text.strip
      raise Error, "Invalid text length/outer whitespace: #{locale} (#{units} UTF-16 units)"
    end
    # ASC displays plain text; retain the requested diamonds and numbered items.
    markup = /<\/?[A-Za-z][^>]*>|\]\(|```|\*\*|__|\{\{|\}\}|^\s*\#{1,6}\s|●/
    if text.match?(markup) || text.match?(/[\x00-\x09\x0B-\x1F\x7F]/)
      raise Error, "Markup, unresolved placeholders, or control characters: #{locale}"
    end
    true
  end

  def self.load_catalog(path)
    raw = File.binread(path)
    utf8 = raw.dup.force_encoding(Encoding::UTF_8)
    raise Error, 'Catalog must be valid UTF-8.' unless utf8.valid_encoding?
    texts = JSON.parse(utf8, object_class: UniqueKeysHash)
    unless texts.is_a?(Hash) && texts.keys.sort == LOCALES
      raise Error, 'Catalog must contain exactly the 39 existing ASC locales.'
    end
    texts.each { |locale, text| validate_text!(text, locale); text.freeze }
    [texts.freeze, { 'sha256' => Digest::SHA256.hexdigest(raw), 'bytes' => raw.bytesize }]
  rescue JSON::ParserError
    raise Error, 'Catalog is not valid JSON; no file contents logged.'
  end

  def self.check_catalog_unchanged!(path, fingerprint)
    unless File.file?(path) && Digest::SHA256.file(path).hexdigest == fingerprint.fetch('sha256')
      raise Error, 'Catalog changed after planning; stopped. Reconcile with a new dry-run.'
    end
  end

  class Client < ReleaseNotesSync::Client
    def request(method, path, body = nil)
      if method != 'GET'
        data = body.is_a?(Hash) && body['data']
        attrs = data.is_a?(Hash) && data['attributes']
        unless method == 'PATCH' && body.is_a?(Hash) && body.keys == ['data'] && data.is_a?(Hash) &&
               data.keys.sort == %w[attributes id type] && attrs.is_a?(Hash) && attrs.keys == [FIELD] &&
               data['type'] == 'appStoreVersionLocalizations' && Array(allowed_ids).include?(data['id']) &&
               path == "/v1/appStoreVersionLocalizations/#{data['id']}"
          raise Error, 'Only the discovered single-version whatsNew PATCH is permitted.'
        end
        ResubmissionReleaseNotesSync.validate_text!(attrs[FIELD], data['id'])
      end
      super
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => e
      # The parent deliberately sets max_retries=0 for PATCH. Do not print a
      # response body, JWT, private key, or attempt a second uncertain mutation.
      raise Error, "#{method} failed (#{e.class}); stopped. Run a new dry-run to reconcile."
    end
  end

  def self.version!(client)
    version = client.request('GET', "/v1/appStoreVersions/#{TARGET['versionId']}").fetch('data')
    attrs = version.fetch('attributes')
    unless version['id'] == TARGET['versionId'] && version['type'] == 'appStoreVersions' &&
           attrs['versionString'] == TARGET['versionString'] && attrs['platform'] == TARGET['platform'] &&
           EDITABLE_STATES.include?(attrs['appStoreState'])
      raise Error, 'Version identity/state is not allowlisted; nothing will be submitted.'
    end
    version
  end

  def self.identity!(client)
    app = client.request('GET', "/v1/apps/#{TARGET['appId']}").fetch('data')
    versions = client.list("/v1/apps/#{TARGET['appId']}/appStoreVersions?limit=200")
    matches = versions.select { |version| version['id'] == TARGET['versionId'] }
    unless app['id'] == TARGET['appId'] && app['type'] == 'apps' &&
           app.dig('attributes', 'bundleId') == TARGET['bundleId'] && matches.length == 1 &&
           matches.first['type'] == 'appStoreVersions'
      raise Error, 'App/bundle/version ownership is not the exact allowlisted target.'
    end
    [app, version!(client)]
  end

  def self.localizations!(client)
    rows = client.list("/v1/appStoreVersions/#{TARGET['versionId']}/appStoreVersionLocalizations?limit=200")
    ids = rows.map { |row| row['id'] }
    unless rows.all? { |row| row['type'] == 'appStoreVersionLocalizations' && row['attributes'].is_a?(Hash) } &&
           ids.all? { |id| id.is_a?(String) && id.match?(/\A[A-Za-z0-9-]+\z/) } &&
           ids.uniq.length == ids.length && rows.map { |row| row.dig('attributes', 'locale') }.sort == LOCALES
      raise Error, 'Expected exactly 39 unique existing localization resources.'
    end
    rows.sort_by { |row| row.dig('attributes', 'locale') }
  end

  def self.save(output, name, object)
    AppDescriptionSync.save(output, name, object)
  end

  def self.checkpoint(output, completed)
    Tempfile.create(['.completed-', '.json'], output) do |file|
      file.chmod(0600)
      file.write(JSON.pretty_generate(completed))
      file.flush
      file.fsync
      File.rename(file.path, File.join(output, 'completed.json'))
    end
  end

  def self.sync(client, catalog_path:, output:, apply: false)
    texts, fingerprint = load_catalog(catalog_path)
    unless client.respond_to?(:metadata_field) && client.metadata_field == FIELD
      raise Error, 'Client must permit only whatsNew changes.'
    end
    raise Error, 'Output must be a new directory.' if File.exist?(output) || File.symlink?(output)
    FileUtils.mkdir_p(output, mode: 0700)
    app, version = identity!(client)
    rows = localizations!(client)
    baseline = rows.to_h { |row| [row.fetch('id'), row] }
    save(output, 'before.json', { 'target' => TARGET, 'capturedAt' => Time.now.utc.iso8601,
                                'app' => app, 'version' => version, 'localizations' => rows })
    save(output, 'catalog.json', { 'fingerprint' => fingerprint, 'texts' => texts })
    plan = rows.map do |row|
      locale = row.dig('attributes', 'locale')
      { 'versionId' => TARGET['versionId'], 'id' => row['id'], 'locale' => locale, FIELD => texts.fetch(locale),
        'action' => row.dig('attributes', FIELD) == texts.fetch(locale) ? 'unchanged' : 'update' }
    end
    save(output, 'plan.json', { 'target' => TARGET, 'catalogFingerprint' => fingerprint, 'entries' => plan })
    check_catalog_unchanged!(catalog_path, fingerprint)
    puts "#{apply ? 'APPLY' : 'DRY-RUN'}: ordinary iOS 3.6.0 only; #{plan.group_by { |p| p['action'] }.transform_values(&:length)}"
    unless apply
      save(output, 'completed.json', [])
      return plan
    end

    client.allowed_ids = plan.map { |entry| entry.fetch('id') }
    completed = []
    checkpoint(output, completed)
    begin
      plan.each do |entry|
        # Check state before EVERY item, not just once at discovery. In-review
        # or released versions are rejected even if they changed mid-run.
        current_version = version!(client)
        unless current_version.fetch('attributes') == version.fetch('attributes')
          raise Error, 'Version metadata changed concurrently; stopped.'
        end
        latest = client.request('GET', "/v1/appStoreVersionLocalizations/#{entry['id']}").fetch('data')
        old = baseline.fetch(entry['id'])
        unless latest['id'] == old['id'] && latest['type'] == old['type'] && latest['attributes'] == old['attributes']
          raise Error, "Concurrent localization metadata change: #{entry['locale']}; stopped."
        end
        check_catalog_unchanged!(catalog_path, fingerprint)
        if entry['action'] == 'update'
          client.request('PATCH', "/v1/appStoreVersionLocalizations/#{entry['id']}",
                         { 'data' => { 'type' => 'appStoreVersionLocalizations', 'id' => entry['id'],
                                       'attributes' => { FIELD => entry[FIELD] } } })
        end
        completed << entry.slice('versionId', 'id', 'locale', 'action')
        checkpoint(output, completed)
        puts "#{completed.length}/#{plan.length} #{entry['locale']} #{entry['action']}"
        STDOUT.flush
      end

      final_app, final_version = identity!(client)
      unless final_app.fetch('attributes') == app.fetch('attributes') && final_version.fetch('attributes') == version.fetch('attributes')
        raise Error, 'App/version metadata changed during sync; reconcile before doing anything else.'
      end
      verified = localizations!(client)
      unless verified.map { |row| row['id'] }.sort == baseline.keys.sort
        raise Error, 'Localization identities changed during sync.'
      end
      verified.each do |row|
        expected = baseline.fetch(row['id']).fetch('attributes').merge(FIELD => texts.fetch(row.dig('attributes', 'locale')))
        raise Error, "Readback mismatch: #{row['id']}" unless row['attributes'] == expected
      end
      check_catalog_unchanged!(catalog_path, fingerprint)
      save(output, 'verified.json', { 'target' => TARGET, 'catalogFingerprint' => fingerprint,
                                     'verifiedAt' => Time.now.utc.iso8601, 'localizations' => verified })
      puts 'VERIFIED: all 39 whatsNew values match; all other app/version/localization attributes are unchanged. Not submitted.'
      plan
    ensure
      checkpoint(output, completed)
      client.allowed_ids = []
    end
  end

  def self.main(args = ARGV)
    opts = {}
    OptionParser.new do |parser|
      parser.banner = 'Usage: sync-resubmission-release-notes.rb --catalog PATH [--validate | credentials --output PATH [--apply]]'
      parser.on('--catalog PATH') { |value| opts[:catalog] = value }
      parser.on('--key-file PATH') { |value| opts[:key_path] = value }
      parser.on('--key-id ID') { |value| opts[:key_id] = value }
      parser.on('--issuer-id ID') { |value| opts[:issuer_id] = value }
      parser.on('--output PATH') { |value| opts[:output] = value }
      parser.on('--apply') { opts[:apply] = true }
      parser.on('--validate') { opts[:validate] = true }
    end.parse!(args)
    raise Error, 'Unexpected arguments.' unless args.empty?
    raise Error, 'Missing catalog.' unless opts[:catalog]
    raise Error, '--validate cannot be combined with --apply.' if opts[:validate] && opts[:apply]
    texts, fingerprint = load_catalog(opts[:catalog])
    puts "Validated #{texts.length} locales; SHA-256 #{fingerprint['sha256']}; max #{texts.values.map { |text| text.encode('UTF-16LE').bytesize / 2 }.max} UTF-16 units."
    return if opts[:validate] # No key access, HTTP request, or output write.
    %i[key_path key_id issuer_id output].each { |key| raise Error, "Missing #{key}." unless opts[key] }
    unless File.file?(opts[:key_path]) && File.size(opts[:key_path]).between?(100, 16_384)
      raise Error, 'Unexpected private-key file/size.'
    end
    client = Tempfile.create(['wake-resubmission-key', '.p8']) do |file|
      file.chmod(0600)
      file.write(File.binread(opts[:key_path]))
      file.flush
      Client.new(key_path: file.path, key_id: opts[:key_id], issuer_id: opts[:issuer_id])
    end # Temporary key deleted; original untouched, key material only in memory.
    sync(client, catalog_path: opts[:catalog], output: opts[:output], apply: opts[:apply])
  rescue Error, KeyError, TypeError, ArgumentError, OptionParser::ParseError, IOError, SystemCallError => e
    warn "STOPPED: #{e.message}"
    exit 1
  end
end

ResubmissionReleaseNotesSync.main if $PROGRAM_NAME == __FILE__
