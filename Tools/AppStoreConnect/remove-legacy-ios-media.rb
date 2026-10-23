#!/usr/bin/env ruby
# frozen_string_literal: true

# Removes only explicit, backed-up iPhone media IDs from ordinary iOS 3.6.0.
# iPad media is always protected, even if its ID is accidentally in the plan.
# Sets, Asset Library assets, metadata, builds, and review endpoints are unwritable.
# Dry-run is offline; --apply additionally requires the existing ASC key arguments.
# Plan: [{"type":"appScreenshots|appPreviews","id":"...",
#         "localizationId":"...","setId":"..."}]
# Backup manifest: {"version":1,"baseDir":"/absolute/backup/root","assets":[
#   {"type":"appScreenshots|appPreviews","id":"...","file":"relative/file",
#    "sha256":"64 hexadecimal characters"}]}
require_relative 'sync-resubmission-release-notes'
require 'set'
require 'pathname'
require 'thread'

module LegacyIOSMediaCleanup
  Error = PurchaseLocalizationSync::Error
  TARGET = ResubmissionReleaseNotesSync::TARGET
  TARGET_ARRAY = [TARGET['appId'], TARGET['bundleId'], TARGET['platform'], TARGET['versionId'], 'standard'].freeze
  GROUPS = {
    'appScreenshots' => %w[screenshotSets appScreenshotSets screenshots screenshotDisplayType APP_IPHONE_65],
    'appPreviews' => %w[previewSets appPreviewSets previews previewType IPHONE_65]
  }.freeze
  ID_PATTERN = /\A[A-Za-z0-9-]+\z/
  PROCESSING_FIELDS = %w[assetDeliveryState imageAsset assetToken assetType uploadOperations].freeze

  def self.key(row)
    [row.fetch('type'), row.fetch('id')]
  end

  def self.phone?(ctx)
    (ctx['type'] == 'appScreenshots' && ctx['displayType'].match?(/\AAPP_IPHONE_[A-Z0-9_]+\z/)) ||
      (ctx['type'] == 'appPreviews' && ctx['displayType'].match?(/\AIPHONE_[A-Z0-9_]+\z/))
  end

  def self.resource!(row, type)
    unless row.is_a?(Hash) && row['type'] == type && row['id'].is_a?(String) &&
           row['id'].match?(ID_PATTERN) && row['attributes'].is_a?(Hash)
      raise Error, "Malformed #{type} resource."
    end
    row
  end

  # Only omit transport fields; metadata URLs (supportUrl/marketingUrl) remain.
  def self.stable(value)
    case value
    when Hash
      value.reject { |k, _| %w[links templateUrl videoUrl uploadOperations].include?(k) }
           .to_h { |k, v| [k, stable(v)] }
    when Array then value.map { |v| stable(v) }
    else value
    end
  end

  def self.same_resource!(expected, actual, label)
    resource!(actual, expected.fetch('type'))
    unless expected['id'] == actual['id'] && stable(expected.fetch('attributes')) == stable(actual.fetch('attributes'))
      raise Error, "Concurrent #{label} change: #{expected['id']}; stopped."
    end
  end

  def self.read_json(path)
    JSON.parse(File.read(path, encoding: 'UTF-8'), object_class: ResubmissionReleaseNotesSync::UniqueKeysHash)
  rescue JSON::ParserError
    raise Error, 'Invalid JSON input; no file contents logged.'
  end

  def self.index(snapshot)
    unless snapshot.is_a?(Array) && snapshot.length == 1 && snapshot.first['target'] == TARGET_ARRAY
      raise Error, 'Snapshot must contain only the exact ordinary iOS 3.6.0 target.'
    end
    s = snapshot.first
    version = resource!(s.fetch('version'), 'appStoreVersions')
    a = version.fetch('attributes')
    unless version['id'] == TARGET['versionId'] && a['platform'] == 'IOS' && a['versionString'] == '3.6.0' &&
           ResubmissionReleaseNotesSync::EDITABLE_STATES.include?(a['appStoreState'])
      raise Error, 'Snapshot version identity/state is not allowlisted.'
    end
    locals, sets, assets = {}, {}, {}
    s.fetch('localizations').each do |l|
      loc = resource!(l.fetch('localization'), 'appStoreVersionLocalizations')
      raise Error, 'Duplicate localization ID.' if locals.key?(loc['id'])
      locals[loc['id']] = loc
      GROUPS.each do |type, (group, set_type, children, display_field, _)|
        l.fetch(group).each do |set|
          r = resource!(set.fetch('resource'), set_type)
          set_key = [set_type, r['id']]
          raise Error, 'Duplicate set ID.' if sets.key?(set_key)
          ctx = { 'resource' => r, 'localizationId' => loc['id'], 'locale' => loc.dig('attributes', 'locale'),
                  'displayType' => r.fetch('attributes').fetch(display_field), 'type' => type,
                  'assets' => set.fetch(children) }
          sets[set_key] = ctx
          ctx['assets'].each do |asset|
            resource!(asset, type)
            raise Error, 'Duplicate media resource ID.' if assets.key?(key(asset))
            assets[key(asset)] = ctx.merge('asset' => asset)
          end
        end
      end
    end
    unless locals.values.map { |l| l.dig('attributes', 'locale') }.sort == ResubmissionReleaseNotesSync::LOCALES
      raise Error, 'Snapshot must contain all 39 unique expected localizations.'
    end
    { 'version' => version, 'localizations' => locals, 'sets' => sets, 'assets' => assets }
  end

  def self.validate_plan!(before, plan)
    baseline = index(before)
    raise Error, 'Plan must be a nonempty array.' unless plan.is_a?(Array) && !plan.empty?
    seen = Set.new
    plan.map do |row|
      unless row.is_a?(Hash) && %w[type id localizationId setId].all? { |k| row[k].is_a?(String) } &&
             GROUPS.key?(row['type']) && %w[id localizationId setId].all? { |k| row[k].match?(ID_PATTERN) }
        raise Error, 'Plan must use exact type, id, localizationId and setId values.'
      end
      k = key(row)
      raise Error, 'Duplicate planned resource.' unless seen.add?(k)
      ctx = baseline['assets'][k]
      unless ctx && phone?(ctx) && ctx['localizationId'] == row['localizationId'] && ctx['resource']['id'] == row['setId']
        raise Error, "Planned media is outside the exact ordinary iOS iPhone target scope: #{row['id']}"
      end
      if (row.key?('locale') && row['locale'] != ctx['locale']) ||
         (row.key?('versionId') && row['versionId'] != TARGET['versionId']) ||
         (row.key?('displayType') && row['displayType'] != ctx['displayType'])
        raise Error, 'Plan annotations conflict with the verified target.'
      end
      row.slice('type', 'id', 'localizationId', 'setId').merge(
        'locale' => ctx['locale'], 'displayType' => ctx['displayType'], 'versionId' => TARGET['versionId'],
        'fileName' => ctx['asset'].dig('attributes', 'fileName'))
    end
  end

  def self.empty_upload?(asset)
    return false unless asset['type'] == 'appScreenshots' && asset.dig('attributes', 'assetDeliveryState', 'state') == 'AWAITING_UPLOAD'
    return false unless asset.dig('attributes', 'sourceFileChecksum').to_s.empty?
    image = asset.dig('attributes', 'imageAsset')
    return true if image.nil?
    return false unless image.is_a?(Hash) && [nil, 0].include?(image['width']) && [nil, 0].include?(image['height'])
    template = image['templateUrl'].to_s
    template.empty? || template.match?(%r{\Ahttps://is[0-9]+-ssl\.mzstatic\.com/image/thumb//\{w\}x\{h\}bb\.\{f\}\z})
  end

  def self.verify_backups!(manifest, plan, before: nil)
    unless manifest.is_a?(Hash) && manifest['version'] == 1 && manifest['baseDir'].is_a?(String) &&
           Pathname.new(manifest['baseDir']).absolute? && manifest['assets'].is_a?(Array)
      raise Error, 'Backup manifest requires version 1, absolute baseDir and assets array.'
    end
    base = File.realpath(manifest['baseDir'])
    raise Error, 'Backup base must be a directory.' unless File.directory?(base)
    records = {}
    baseline = before && index(before)
    manifest['assets'].each do |row|
      unless row.is_a?(Hash) && GROUPS.key?(row['type']) && row['id'].is_a?(String) && row['id'].match?(ID_PATTERN) &&
             row['file'].is_a?(String) && !row['file'].empty? && !Pathname.new(row['file']).absolute? &&
             row['sha256'].is_a?(String) && row['sha256'].match?(/\A[0-9a-fA-F]{64}\z/)
        raise Error, 'Malformed backup record.'
      end
      raise Error, 'Duplicate backup resource.' if records.key?(key(row))
      path = File.realpath(File.join(base, row['file']))
      unless path.start_with?(base + File::SEPARATOR) && File.file?(path) && File.size(path).positive?
        raise Error, 'Backup file must be a nonempty regular file inside baseDir.'
      end
      unless Digest::SHA256.file(path).hexdigest == row['sha256'].downcase
        raise Error, "Backup hash mismatch: #{row['id']}"
      end
      kind = row.fetch('backupKind', 'media')
      if kind == 'metadata-only-unuploaded'
        asset = baseline && baseline['assets'][key(row)] && baseline['assets'][key(row)]['asset']
        unless asset && empty_upload?(asset) && read_json(path) == asset
          raise Error, 'Metadata-only backup requires an unchanged empty AWAITING_UPLOAD screenshot resource.'
        end
      elsif kind != 'media'
        raise Error, 'Unknown backupKind.'
      end
      records[key(row)] = row.merge('bytes' => File.size(path))
    end
    missing = plan.map { |row| key(row) } - records.keys
    raise Error, "Missing #{missing.length} planned media backups." unless missing.empty?
    plan.map { |row| records.fetch(key(row)) }
  rescue Errno::ENOENT, Errno::EACCES, Errno::ENOTDIR
    raise Error, 'Backup path is missing or inaccessible.'
  end

  class Client < PurchaseLocalizationSync::Client
    def initialize(**options)
      @token_mutex = Mutex.new
      super
    end

    def token
      @token_mutex.synchronize { super }
    end

    def allow_plan!(plan)
      @allowed = plan.map { |row| LegacyIOSMediaCleanup.key(row) }.to_set.freeze
    end

    def request(method, path, body = nil)
      return super if method == 'GET'
      match = path.match(%r{\A/v1/(appScreenshots|appPreviews)/([A-Za-z0-9-]+)\z})
      unless method == 'DELETE' && body.nil? && match && @allowed && @allowed.include?([match[1], match[2]])
        raise Error, 'Only exact planned screenshot/preview DELETE requests are permitted.'
      end
      uri = URI("#{ORIGIN}#{path}")
      req = Net::HTTP::Delete.new(uri)
      req['Authorization'] = "Bearer #{token}"
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 20
      http.read_timeout = 30
      http.max_retries = 0
      response = http.request(req)
      unless response.code.to_i == 204
        raise Error, "DELETE #{match[2]}: HTTP #{response.code}; reconcile remote state before retrying."
      end
      {}
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError
      raise Error, 'DELETE transport failure; reconcile remote state before retrying. No automatic retry.'
    end
  end

  def self.new_output!(output)
    raise Error, 'Output must be a new directory.' if File.exist?(output) || File.symlink?(output)
    FileUtils.mkdir_p(output, mode: 0700)
    File.open(File.join(output, '.gitignore'), File::WRONLY | File::CREAT | File::EXCL, 0600) { |f| f.write("*\n!.gitignore\n") }
  end

  def self.save(output, name, object)
    AppDescriptionSync.save(output, name, object)
  end

  def self.checkpoint(output, name, object)
    Tempfile.create(['.checkpoint-', '.json'], output) do |f|
      f.chmod(0600)
      f.write(JSON.pretty_generate(object))
      f.flush
      f.fsync
      File.rename(f.path, File.join(output, name))
    end
  end

  def self.metadata!(client, baseline)
    same_resource!(baseline['version'], ResubmissionReleaseNotesSync.version!(client), 'version metadata')
    locals = ResubmissionReleaseNotesSync.localizations!(client).to_h { |loc| [loc['id'], loc] }
    raise Error, 'Localization membership changed.' unless locals.keys.sort == baseline['localizations'].keys.sort
    baseline['localizations'].each do |id, old|
      same_resource!(old, locals.fetch(id), 'localization metadata')
    end
    locals.values
  end

  def self.snapshot(client, baseline)
    locals = metadata!(client, baseline)
    [{ 'target' => TARGET_ARRAY, 'version' => baseline['version'], 'localizations' => parallel_map(locals) do |loc|
      result = { 'localization' => loc }
      GROUPS.each do |type, (group, set_type, children, _field, _display)|
        result[group] = client.list("/v1/appStoreVersionLocalizations/#{loc['id']}/#{set_type}?limit=200").map do |set|
          resource!(set, set_type)
          { 'resource' => set, children => client.list("/v1/#{set_type}/#{set['id']}/#{type}?limit=200") }
        end
      end
      result
    end }]
  end

  def self.parallel_map(items)
    queue, errors = Queue.new, Queue.new
    values = Array.new(items.length)
    items.each_with_index { |item, i| queue << [item, i] }
    Array.new([4, items.length].min) do
      Thread.new do
        loop do
          pair = queue.pop(true) rescue nil
          break unless pair
          item, i = pair
          begin
            values[i] = yield(item)
          rescue StandardError => e
            errors << e
            break
          end
        end
      end
    end.each(&:join)
    raise errors.pop unless errors.empty?
    values
  end

  def self.new_61?(ctx)
    ctx['type'] == 'appScreenshots' && ctx['displayType'] == 'APP_IPHONE_61'
  end

  # Keep identities/content/order strict, while allowing existing unfinished
  # 6.1-inch uploads to acquire server-generated image/processing metadata.
  def self.same_preserved_asset!(old, actual, allow_processing: false)
    return false if stable(old.fetch('attributes')) == stable(actual.fetch('attributes'))
    a, b = old.fetch('attributes'), actual.fetch('attributes')
    if allow_processing && a.dig('assetDeliveryState', 'state') != 'COMPLETE' &&
       b.dig('assetDeliveryState', 'state') == 'COMPLETE' &&
       stable(a.reject { |k, _| PROCESSING_FIELDS.include?(k) }) == stable(b.reject { |k, _| PROCESSING_FIELDS.include?(k) })
      return true
    end
    raise Error, "Protected media changed: #{old['id']}"
  end

  def self.verify!(before, after, removed, require_phone_empty: false)
    old, now = index(before), index(after)
    removed = removed.map { |r| key(r) }.to_set
    same_resource!(old['version'], now['version'], 'version metadata')
    raise Error, 'Localization membership changed.' unless old['localizations'].keys.sort == now['localizations'].keys.sort
    old['localizations'].each { |id, loc| same_resource!(loc, now['localizations'].fetch(id), 'localization metadata') }
    removed.each { |k| raise Error, "Planned deletion still present: #{k.last}" if now['assets'].key?(k) }
    changes = { 'new61Sets' => [], 'new61Assets' => [], 'completed61Processing' => [] }
    old['sets'].each do |set_key, ctx|
      current = now['sets'][set_key]
      raise Error, "Protected set removed: #{set_key.last}" unless current
      unless current['localizationId'] == ctx['localizationId']
        raise Error, 'Set localization ownership changed.'
      end
      same_resource!(ctx['resource'], current['resource'], 'set metadata')
      expected = ctx['assets'].reject { |a| removed.include?(key(a)) }
      expected_ids = expected.map { |a| key(a) }
      actual_ids = current['assets'].map { |a| key(a) }
      extras = actual_ids - expected_ids
      unless ((!require_phone_empty && new_61?(ctx)) || extras.empty?) && actual_ids.select { |k| expected_ids.include?(k) } == expected_ids
        raise Error, "Protected media membership/order changed: #{set_key.last}"
      end
      expected.each do |asset|
        actual = now['assets'].fetch(key(asset)).fetch('asset')
        changed = same_preserved_asset!(asset, actual, allow_processing: !require_phone_empty && new_61?(ctx))
        changes['completed61Processing'] << key(asset) if changed
      end
      changes['new61Assets'].concat(extras.map { |type, id| { 'type' => type, 'id' => id, 'setId' => set_key.last, 'locale' => ctx['locale'] } })
    end
    (now['sets'].keys - old['sets'].keys).each do |set_key|
      ctx = now['sets'].fetch(set_key)
      raise Error, 'Unexpected added media set.' if require_phone_empty || !new_61?(ctx)
      changes['new61Sets'] << { 'id' => set_key.last, 'locale' => ctx['locale'] }
      changes['new61Assets'].concat(ctx['assets'].map { |a| a.slice('type', 'id').merge('setId' => set_key.last, 'locale' => ctx['locale']) })
    end
    changes
  end

  def self.check_set!(client, baseline, row, removed)
    type = row.fetch('type')
    _, set_type, = GROUPS.fetch(type)
    ctx = baseline['sets'].fetch([set_type, row['setId']])
    sets = client.list("/v1/appStoreVersionLocalizations/#{row['localizationId']}/#{set_type}?limit=200")
    matches = sets.select { |s| s['id'] == row['setId'] }
    raise Error, 'Planned set no longer belongs to the exact target localization.' unless matches.length == 1
    same_resource!(ctx['resource'], matches.first, 'set metadata')
    current = client.list("/v1/#{set_type}/#{row['setId']}/#{type}?limit=200")
    expected = ctx['assets'].reject { |a| removed.include?(key(a)) }
    unless current.map { |a| key(a) } == expected.map { |a| key(a) }
      raise Error, 'Concurrent planned-set media membership/order change; stopped.'
    end
    expected.zip(current).each { |a, b| same_resource!(a, b, 'planned-set media') }
  end

  def self.run(client, before:, plan:, manifest:, output:, apply: false, workers: 1, require_phone_empty: false)
    raise Error, 'workers must be an integer from 1 through 4.' unless workers.is_a?(Integer) && workers.between?(1, 4)
    plan = validate_plan!(before, plan)
    baseline = index(before)
    phone_keys = baseline['assets'].select { |_k, ctx| phone?(ctx) }.keys
    if require_phone_empty && plan.map { |row| key(row) }.sort != phone_keys.sort
      raise Error, 'Phone-clear plan must cover every iPhone media resource in the baseline exactly once; iPad stays protected.'
    end
    backups = manifest ? verify_backups!(manifest, plan, before: before) : []
    raise Error, 'All planned media backups are required before applying.' if apply && backups.length != plan.length
    raise Error, 'An explicit deletion client is required.' if apply && !client.respond_to?(:allow_plan!)
    new_output!(output)
    save(output, 'before.json', before)
    save(output, 'plan.json', plan)
    save(output, 'verified-backups.json', backups)
    checkpoint(output, 'completed.json', [])
    puts "#{apply ? 'APPLY' : 'DRY-RUN'}: #{plan.length} exact ordinary iOS 3.6.0 media IDs; #{plan.group_by { |p| p['type'] }.transform_values(&:length)}"
    return plan unless apply

    _, version = ResubmissionReleaseNotesSync.identity!(client)
    same_resource!(baseline['version'], version, 'version metadata')
    current = snapshot(client, baseline)
    save(output, 'preflight.json', current)
    save(output, 'preflight-changes.json', verify!(before, current, [], require_phone_empty: require_phone_empty))
    # Validate every backup before the first mutation, not lazily per resource.
    verify_backups!(manifest, plan, before: before)
    client.allow_plan!(plan)
    completed, removed, pending, uncertain, failures = [], Set.new, {}, [], []
    mutex = Mutex.new
    queue = Queue.new
    plan.group_by { |row| [row['type'], row['setId']] }.each_value { |rows| queue << rows }
    backup_by_key = backups.to_h { |r| [key(r), r] }
    # Each set has exactly one worker; mutation journals are serialized. Any
    # failure stops new DELETEs; requests already in flight still get recorded.
    Array.new([workers, queue.length].min) do
      Thread.new do
        begin
          loop do
            break if mutex.synchronize { !failures.empty? }
            rows = queue.pop(true) rescue nil
            break unless rows
            metadata!(client, baseline)
            check_set!(client, baseline, rows.first, mutex.synchronize { removed.dup })
            rows.each do |row|
              break if mutex.synchronize { !failures.empty? }
              same_resource!(baseline['version'], ResubmissionReleaseNotesSync.version!(client), 'version metadata')
              loc = client.request('GET', "/v1/appStoreVersionLocalizations/#{row['localizationId']}").fetch('data')
              same_resource!(baseline['localizations'].fetch(row['localizationId']), loc, 'localization metadata')
              asset = client.request('GET', "/v1/#{row['type']}/#{row['id']}").fetch('data')
              same_resource!(baseline['assets'].fetch(key(row)).fetch('asset'), asset, 'planned media')
              if backup_by_key.fetch(key(row))['backupKind'] == 'metadata-only-unuploaded' && !empty_upload?(asset)
                raise Error, 'Empty placeholder acquired uploaded content; obtain a media backup before deletion.'
              end
              proceed = mutex.synchronize do
                next false unless failures.empty?
                pending[key(row).join('/')] = row.merge('startedAt' => Time.now.utc.iso8601)
                checkpoint(output, 'pending.json', pending.values)
                true
              end
              break unless proceed
              begin
                client.request('DELETE', "/v1/#{row['type']}/#{row['id']}")
              rescue StandardError => e
                mutex.synchronize do
                  failures << e
                  uncertain << row.merge('message' => 'DELETE not confirmed; reconcile remote state before any retry.')
                  checkpoint(output, 'uncertain.json', uncertain)
                end
                break
              end
              mutex.synchronize do
                completed << row.merge('completedAt' => Time.now.utc.iso8601)
                removed.add(key(row))
                checkpoint(output, 'completed.json', completed)
                pending.delete(key(row).join('/'))
                checkpoint(output, 'pending.json', pending.values)
                puts "REMOVED #{completed.length}/#{plan.length} #{row['locale']} #{row['type']} #{row['id']}"
                STDOUT.flush
              end
            end
          end
        rescue StandardError => e
          mutex.synchronize { failures << e }
        end
      end
    end.each(&:join)
    raise failures.first unless failures.empty?
    raise Error, 'Not all planned deletions completed.' unless completed.length == plan.length
    after = snapshot(client, baseline)
    save(output, 'after.json', after)
    changes = verify!(before, after, completed, require_phone_empty: require_phone_empty)
    remaining = index(after)['assets'].length
    remaining_phone = index(after)['assets'].count { |_k, ctx| phone?(ctx) }
    raise Error, 'Phone-clear verification found remaining iPhone media.' if require_phone_empty && remaining_phone != 0
    metadata!(client, baseline)
    save(output, 'verified.json', { 'target' => TARGET, 'removedCount' => completed.length,
                                  'plannedIdsAbsent' => true, 'protectedIdsAndOrderPreserved' => true,
                                  'metadataUnchanged' => true, 'notSubmitted' => true,
                                  'phoneClear' => require_phone_empty, 'remainingMediaCount' => remaining,
                                  'remainingPhoneMediaCount' => remaining_phone, 'iPadMediaPreserved' => true,
                                  'concurrent61Changes' => changes })
    puts "VERIFIED: #{completed.length} removed; protected media/order and metadata preserved; no submission."
    completed
  end

  def self.main
    options = { apply: false, workers: 1, require_phone_empty: false }
    OptionParser.new do |p|
      p.banner = 'Usage: remove-legacy-ios-media.rb --before PATH --plan PATH --output NEWPATH [--backup-manifest PATH] [--apply --key-file PATH --key-id ID --issuer-id ID]'
      p.on('--before PATH') { |v| options[:before] = File.expand_path(v) }
      p.on('--plan PATH') { |v| options[:plan] = File.expand_path(v) }
      p.on('--backup-manifest PATH') { |v| options[:manifest] = File.expand_path(v) }
      p.on('--output PATH') { |v| options[:output] = File.expand_path(v) }
      p.on('--key-file PATH') { |v| options[:key_path] = v }
      p.on('--key-id ID') { |v| options[:key_id] = v }
      p.on('--issuer-id ID') { |v| options[:issuer_id] = v }
      p.on('--apply') { options[:apply] = true }
      p.on('--workers N', Integer) { |v| options[:workers] = v }
      p.on('--require-phone-empty', 'Require every iPhone ID in plan; preserve iPad and finish with zero iPhone media') { options[:require_phone_empty] = true }
    end.parse!
    %i[before plan output].each { |k| raise Error, "Missing #{k}." unless options[k] }
    before, plan = read_json(options[:before]), read_json(options[:plan])
    manifest = options[:manifest] && read_json(options[:manifest])
    # Validate local inputs and every backup before opening the private key.
    normalized_plan = validate_plan!(before, plan)
    verify_backups!(manifest, normalized_plan, before: before) if manifest
    client = nil
    if options[:apply]
      %i[manifest key_path key_id issuer_id].each { |k| raise Error, "Missing #{k}." unless options[k] }
      client = Client.new(key_path: options[:key_path], key_id: options[:key_id], issuer_id: options[:issuer_id])
    end
    run(client, before: before, plan: plan, manifest: manifest, output: options[:output], apply: options[:apply],
        workers: options[:workers], require_phone_empty: options[:require_phone_empty])
  rescue Error, KeyError, TypeError, OptionParser::ParseError, SystemCallError => e
    warn "STOPPED: #{e.message}"
    exit 1
  end
end

LegacyIOSMediaCleanup.main if $PROGRAM_NAME == __FILE__
