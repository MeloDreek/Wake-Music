#!/usr/bin/env ruby
# frozen_string_literal: true

# Only remove discovered 6.9-inch iOS screenshots from the two 3.6.0 drafts.
# Never change screenshot sets, previews, localization metadata, or app settings.
require_relative 'sync-app-descriptions'
require 'thread'

module ScreenshotCleanup
  Error = PurchaseLocalizationSync::Error
  TARGETS = AppDescriptionSync::TARGETS.select { |t| t[2] == 'IOS' }.freeze
  SIZES_69 = [[1260, 2736], [1290, 2796], [1320, 2868]].freeze
  SIZES_65 = [[1242, 2688], [1284, 2778]].freeze
  SOURCE = 'https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications'

  class Client < PurchaseLocalizationSync::Client
    attr_accessor :allowed_screenshot_ids

    def initialize(**options)
      @token_mutex = Mutex.new
      super
    end

    def token
      @token_mutex.synchronize { super }
    end

    def request(method, path, body = nil)
      return super if method == 'GET'
      id = path.delete_prefix('/v1/appScreenshots/')
      unless method == 'DELETE' && body.nil? && id.match?(/\A[A-Za-z0-9-]+\z/) &&
             path == "/v1/appScreenshots/#{id}" && Array(allowed_screenshot_ids).include?(id)
        raise Error, 'Only exact, discovered screenshot DELETE requests are permitted.'
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
      # Never retry an uncertain deletion; inspect the actual remote state first.
      raise Error, "DELETE #{id}: HTTP #{response.code}; reconcile before retrying." unless response.code.to_i == 204
      {}
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
      raise Error, "Transport failure (#{e.class}) for #{method}; reconcile before retrying."
    end
  end

  def self.save(dir, name, value)
    AppDescriptionSync.save(dir, name, value)
  end

  def self.parallel_map(items, workers: 5)
    queue = Queue.new
    items.each_with_index { |item, i| queue << [item, i] }
    values = Array.new(items.length)
    errors = Queue.new
    Array.new([workers, items.length].min) do
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

  def self.media(c, localization)
    id = localization.fetch('id')
    screenshot_sets = c.list("/v1/appStoreVersionLocalizations/#{id}/appScreenshotSets?limit=200")
    preview_sets = c.list("/v1/appStoreVersionLocalizations/#{id}/appPreviewSets?limit=200")
    {
      'localization' => localization,
      'screenshotSets' => screenshot_sets.map do |set|
        { 'resource' => set, 'screenshots' => c.list("/v1/appScreenshotSets/#{set.fetch('id')}/appScreenshots?limit=200") }
      end,
      'previewSets' => preview_sets.map do |set|
        { 'resource' => set, 'previews' => c.list("/v1/appPreviewSets/#{set.fetch('id')}/appPreviews?limit=200") }
      end
    }
  end

  def self.snapshot(c)
    AppDescriptionSync::TARGETS.map do |target|
      version = AppDescriptionSync.validate_version!(c, target)
      locals = c.list("/v1/appStoreVersions/#{target[3]}/appStoreVersionLocalizations?limit=200")
      result = {
        'target' => target,
        'version' => version,
        'localizations' => parallel_map(locals) { |loc| media(c, loc) }
      }
      puts "INVENTORIED #{target[4]} #{target[2]}: #{locals.length} localizations"
      STDOUT.flush
      result
    end
  end

  def self.dimensions(screenshot)
    a = screenshot.fetch('attributes').fetch('imageAsset', {})
    [a['width'], a['height']].compact.sort
  end

  def self.plan(snapshot)
    snapshot.select { |s| s['target'][2] == 'IOS' }.flat_map do |s|
      s['localizations'].flat_map do |l|
        sets = l['screenshotSets']
        selected = sets.select { |set| set.dig('resource', 'attributes', 'screenshotDisplayType') == 'APP_IPHONE_67' }
        selected.flat_map do |set|
          screenshots = set['screenshots']
          next [] if screenshots.empty?
          replacement = sets.select { |v| v.dig('resource', 'attributes', 'screenshotDisplayType') == 'APP_IPHONE_65' }
                            .flat_map { |v| v['screenshots'] }
          locale = l.dig('localization', 'attributes', 'locale')
          unless replacement.any? && replacement.all? { |r| SIZES_65.include?(dimensions(r)) && r.dig('attributes', 'assetDeliveryState', 'state') == 'COMPLETE' }
            raise Error, "Missing complete 6.5-inch screenshots for #{s['target'][4]}/#{locale}; no deletions permitted."
          end
          screenshots.map do |screenshot|
            unless SIZES_69.include?(dimensions(screenshot)) && screenshot.dig('attributes', 'assetDeliveryState', 'state') == 'COMPLETE'
              raise Error, "Ambiguous 6.9-inch dimensions/state for #{s['target'][4]}/#{locale}/#{screenshot['id']}"
            end
            {
              'edition' => s['target'][4], 'versionId' => s['target'][3],
              'locale' => locale, 'localizationId' => l['localization']['id'],
              'setId' => set['resource']['id'], 'id' => screenshot['id'],
              'displayType' => 'APP_IPHONE_67', 'dimensions' => dimensions(screenshot),
              'fileName' => screenshot.dig('attributes', 'fileName'),
              'replacement65Count' => replacement.length
            }
          end
        end
      end
    end
  end

  def self.inventory(snapshot)
    snapshot.map do |s|
      {
        'edition' => s['target'][4], 'platform' => s['target'][2],
        'locales' => s['localizations'].map do |l|
          {
            'locale' => l.dig('localization', 'attributes', 'locale'),
            'screenshots' => l['screenshotSets'].map do |v|
              { 'displayType' => v.dig('resource', 'attributes', 'screenshotDisplayType'),
                'count' => v['screenshots'].length, 'dimensions' => v['screenshots'].map { |r| dimensions(r) }.uniq }
            end,
            'previews' => l['previewSets'].map do |v|
              { 'displayType' => v.dig('resource', 'attributes', 'previewType'), 'count' => v['previews'].length }
            end
          }
        end
      }
    end
  end

  # Ignore transport links while comparing all stored metadata and asset identities.
  # CDN template URLs may acquire a different query signature between reads.
  def self.stable(value)
    case value
    when Hash
      value.reject { |k, _| %w[links templateUrl url uploadOperations].include?(k) }
           .to_h do |k, v|
        # ASC does not guarantee list ordering for localizations or containers.
        # Screenshot and preview order inside each container remains significant.
        v = v.sort_by { |r| r.fetch('localization').fetch('id') } if k == 'localizations'
        v = v.sort_by { |r| r.fetch('resource').fetch('id') } if %w[screenshotSets previewSets].include?(k)
        [k, stable(v)]
      end
    when Array then value.map { |v| stable(v) }
    else value
    end
  end

  def self.verify!(before, after, removed_ids)
    expected = Marshal.load(Marshal.dump(before))
    expected.each do |s|
      s['localizations'].each do |l|
        l['screenshotSets'].each { |set| set['screenshots'].reject! { |r| removed_ids.include?(r['id']) } }
      end
    end
    raise Error, 'Verification mismatch: protected assets or metadata changed.' unless stable(expected) == stable(after)
  end

  # Keep a usable full-resolution PNG of each removed image. CDN rendering may
  # differ from the originally uploaded file, so retain the original metadata too.
  # No API token is sent to Apple's image CDN.
  def self.backup_images(before, deletions, output)
    image_dir = File.join(output, 'removed-screenshot-backups')
    Dir.mkdir(image_dir, 0700)
    assets = before.flat_map { |s| s['localizations'] }
                   .flat_map { |l| l['screenshotSets'] }
                   .flat_map { |set| set['screenshots'] }.to_h { |r| [r['id'], r] }
    backups = parallel_map(deletions) do |row|
      a = assets.fetch(row['id']).fetch('attributes').fetch('imageAsset')
      template = a.fetch('templateUrl')
      url = template.gsub('{w}', a.fetch('width').to_s).gsub('{h}', a.fetch('height').to_s).gsub('{f}', 'png')
      raise Error, 'Unexpected CDN image URL template.' if url.include?('{')
      uri = URI(url)
      unless uri.scheme == 'https' && uri.host.end_with?('.mzstatic.com') && uri.port == 443 && !uri.userinfo
        raise Error, 'Image backup URL is not an Apple image CDN.'
      end
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 20
      http.read_timeout = 30
      response = http.request(Net::HTTP::Get.new(uri))
      raise Error, "Image backup failed: HTTP #{response.code}" unless response.code.to_i == 200
      body = response.body
      unless body.bytesize.between?(24, 30_000_000) && body.start_with?("\x89PNG\r\n\x1a\n".b) &&
             body.byteslice(16, 8).unpack('NN').sort == row['dimensions']
        raise Error, "Image backup dimensions/format invalid for #{row['id']}"
      end
      name = "#{row['id']}.png"
      File.open(File.join(image_dir, name), File::WRONLY | File::CREAT | File::EXCL, 0600) { |f| f.binmode; f.write(body) }
      row.merge('backupFile' => "removed-screenshot-backups/#{name}", 'sha256' => Digest::SHA256.hexdigest(body), 'bytes' => body.bytesize)
    end
    save(output, 'image-backups.json', backups)
    puts "BACKED UP: #{backups.length} full-resolution PNGs; dimensions verified."
    STDOUT.flush
  end

  def self.main
    options = {}
    OptionParser.new do |p|
      p.on('--key-file PATH') { |v| options[:key_path] = v }
      p.on('--key-id ID') { |v| options[:key_id] = v }
      p.on('--issuer-id ID') { |v| options[:issuer_id] = v }
      p.on('--output PATH') { |v| options[:output] = File.expand_path(v) }
      p.on('--apply-from PATH') { |v| options[:apply_from] = File.expand_path(v) }
    end.parse!
    %i[key_path key_id issuer_id output].each { |k| raise Error, "Missing #{k}" unless options[k] }
    raise Error, 'Output must be new.' if File.exist?(options[:output])
    FileUtils.mkdir_p(options[:output], mode: 0700)
    File.open(File.join(options[:output], '.gitignore'), File::WRONLY | File::CREAT | File::EXCL, 0600) { |f| f.write("*\n!.gitignore\n") }
    c = Tempfile.create(['wake-screenshot-key', '.p8']) do |f|
      f.chmod(0600)
      f.write(File.binread(options[:key_path])); f.flush
      Client.new(key_path: f.path, key_id: options[:key_id], issuer_id: options[:issuer_id])
    end
    before = snapshot(c)
    save(options[:output], 'before.json', before)
    save(options[:output], 'inventory.json', inventory(before))
    deletions = plan(before)
    save(options[:output], 'plan.json', deletions)
    puts "PLAN: #{deletions.length} screenshots; #{deletions.group_by { |r| r['edition'] }.transform_values(&:length)}"
    return unless options[:apply_from]
    approved_before = JSON.parse(File.read(File.join(options[:apply_from], 'before.json')))
    approved_plan = JSON.parse(File.read(File.join(options[:apply_from], 'plan.json')))
    unless stable(before) == stable(approved_before) && deletions.sort_by { |r| r['id'] } == approved_plan.sort_by { |r| r['id'] }
      raise Error, 'Remote state changed from reviewed inventory; stopped.'
    end
    backup_images(before, deletions, options[:output])
    c.allowed_screenshot_ids = deletions.map { |p| p['id'] }
    completed = []
    begin
      TARGETS.each do |target|
        AppDescriptionSync.validate_version!(c, target)
        deletions.select { |p| p['versionId'] == target[3] }.group_by { |p| p['setId'] }.each do |set_id, rows|
          current = c.list("/v1/appScreenshotSets/#{set_id}/appScreenshots?limit=200")
          raise Error, 'Concurrent screenshot set change; stopped.' unless current.map { |r| r['id'] } == rows.map { |p| p['id'] }
          rows.each do |row|
            c.request('DELETE', "/v1/appScreenshots/#{row['id']}")
            completed << row
            puts "REMOVED #{completed.length}/#{deletions.length} #{row['edition']} #{row['locale']} #{row['fileName']}"
            STDOUT.flush
          end
        end
      end
      after = snapshot(c)
      save(options[:output], 'after.json', after)
      verify!(before, after, completed.map { |r| r['id'] })
      save(options[:output], 'verified.json', { 'removed' => completed.length, 'preservedPreviewsAndAllOtherAssetsAndMetadata' => true, 'specification' => SOURCE })
      puts "VERIFIED: #{completed.length} removed; previews, other screenshots, metadata, and macOS unchanged."
    ensure
      save(options[:output], 'completed.json', completed)
    end
  rescue Error, KeyError, OptionParser::ParseError => e
    warn "STOPPED: #{e.message}"
    exit 1
  end
end

ScreenshotCleanup.main if $PROGRAM_NAME == __FILE__
