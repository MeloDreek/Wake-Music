#!/usr/bin/env ruby
# frozen_string_literal: true

# Back up a previously captured ASC media inventory. This program has no ASC
# client or credentials: its only network operation is an unauthenticated GET
# to an allowlisted Apple CDN. It does not change or delete remote resources.
require 'json'
require 'optparse'
require 'fileutils'
require 'digest'
require 'net/http'
require 'uri'
require 'open3'
require 'zlib'
require 'thread'

module LegacyIOSMediaBackup
  class Error < StandardError; end
  PNG_SIGNATURE = "\x89PNG\r\n\x1a\n".b.freeze
  FFMPEG = '/opt/homebrew/bin/ffmpeg'
  FFPROBE = '/opt/homebrew/bin/ffprobe'

  def self.save(path, data)
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0600) do |f|
      f.write(JSON.pretty_generate(data) + "\n")
    end
  end

  def self.cdn_uri(url)
    uri = URI(url)
    host = uri.host.to_s.downcase
    unless uri.scheme == 'https' && uri.port == 443 && !uri.userinfo && !uri.fragment &&
           (host == 'mzstatic.com' || host.end_with?('.mzstatic.com') || host == 'apptrailers.itunes.apple.com')
      raise Error, "Refusing non-Apple-CDN URL: #{uri.host}"
    end
    uri
  rescue URI::InvalidURIError
    raise Error, 'Invalid CDN URL'
  end

  def self.get(url, limit: 100_000_000, redirects: 0)
    raise Error, 'Too many CDN redirects' if redirects > 5
    uri = cdn_uri(url)
    retries = 0
    begin
      http = Net::HTTP.new(uri.host, uri.port, nil) # Do not use environment proxies.
      http.use_ssl = true
      http.open_timeout = 25
      http.read_timeout = 60
      http.max_retries = 0
      body = +''.b
      result = http.request(Net::HTTP::Get.new(uri.request_uri)) do |response|
        if response.is_a?(Net::HTTPRedirection)
          target = URI.join(uri.to_s, response.fetch('location')).to_s
          cdn_uri(target) # Validate before following every redirect.
          return get(target, limit: limit, redirects: redirects + 1)
        end
        raise Error, "CDN HTTP #{response.code}" unless response.code.to_i == 200
        response.read_body do |chunk|
          body << chunk
          raise Error, 'CDN response exceeds size limit' if body.bytesize > limit
        end
      end
      raise Error, 'Empty CDN response' if body.empty?
      body
    rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
      retries += 1
      raise Error, "CDN GET failed (#{e.class})" if retries >= 3
      sleep(retries)
      retry
    end
  end

  # Verify PNG signature, all chunk checksums, IHDR dimensions, compressed image
  # bytes, and IEND so a truncated HTTP response cannot become a valid backup.
  def self.verify_png(path, expected)
    bytes = File.binread(path)
    raise Error, 'Not a PNG' unless bytes.start_with?(PNG_SIGNATURE)
    offset = 8
    first = true
    ended = false
    compressed = +''.b
    while offset + 12 <= bytes.bytesize
      size = bytes.byteslice(offset, 4).unpack1('N')
      type = bytes.byteslice(offset + 4, 4)
      data = bytes.byteslice(offset + 8, size)
      crc = bytes.byteslice(offset + 8 + size, 4)
      raise Error, 'Truncated PNG chunk' unless data && data.bytesize == size && crc && crc.bytesize == 4
      raise Error, 'PNG CRC mismatch' unless Zlib.crc32(type + data) == crc.unpack1('N')
      if first
        raise Error, 'PNG dimensions mismatch' unless type == 'IHDR' && size == 13 && data.unpack('NN') == expected
        first = false
      end
      compressed << data if type == 'IDAT'
      offset += size + 12
      if type == 'IEND'
        ended = true
        break
      end
    end
    raise Error, 'Incomplete PNG' unless ended && offset == bytes.bytesize && !compressed.empty?
    raise Error, 'Empty PNG image' if Zlib::Inflate.inflate(compressed).empty?
    expected
  rescue Zlib::Error => e
    raise Error, "Invalid PNG image data: #{e.class}"
  end

  def self.resources(snapshot)
    raise Error, 'Inventory must be an array' unless snapshot.is_a?(Array)
    snapshot.flat_map do |version|
      raise Error, 'Only iOS media inventories are supported' unless version.dig('target', 2) == 'IOS'
      version.fetch('localizations').flat_map do |locale|
        [['screenshotSets', 'screenshots', 'screenshotDisplayType'], ['previewSets', 'previews', 'previewType']].flat_map do |set_key, asset_key, display_key|
          locale.fetch(set_key).flat_map do |set|
            set.fetch(asset_key).each_with_index.map do |asset, index|
              {
                'resource' => asset, 'versionId' => version.fetch('version').fetch('id'),
                'edition' => version.fetch('target')[4], 'locale' => locale.dig('localization', 'attributes', 'locale'),
                'localizationId' => locale.fetch('localization').fetch('id'), 'setId' => set.fetch('resource').fetch('id'),
                'displayType' => set.dig('resource', 'attributes', display_key), 'index' => index
              }
            end
          end
        end
      end
    end
  end

  def self.unavailable_reason(row)
    resource = row.fetch('resource')
    a = resource.fetch('attributes')
    state = a.dig('assetDeliveryState', 'state')
    return "assetDeliveryState=#{state}" unless state == 'COMPLETE'
    if resource.fetch('type') == 'appScreenshots'
      image = a['imageAsset'] || {}
      return 'No complete image dimensions or CDN URL' unless image['width'].to_i.positive? && image['height'].to_i.positive? && image['templateUrl']
    elsif resource.fetch('type') == 'appPreviews'
      return 'No complete video CDN URL' unless a['videoUrl'] && a.dig('videoDeliveryState', 'state') == 'COMPLETE'
    else
      return 'Unsupported resource type'
    end
    nil
  end

  def self.group_key(row)
    r = row.fetch('resource')
    a = r.fetch('attributes')
    dimensions = r['type'] == 'appScreenshots' ? a.fetch('imageAsset').values_at('width', 'height') : []
    [r.fetch('type'), a['sourceFileChecksum'].to_s.empty? ? r.fetch('id') : a['sourceFileChecksum'], *dimensions].join(':')
  end

  def self.empty_unuploaded_placeholder?(row)
    resource = row.fetch('resource')
    a = resource.fetch('attributes')
    image = a['imageAsset'] || {}
    template = image['templateUrl'].to_s
    no_asset_url = template.empty? || template.match?(%r{\Ahttps://[a-z0-9-]+\.mzstatic\.com/image/thumb//\{w\}x\{h\}bb\.\{f\}\z})
    resource['type'] == 'appScreenshots' && a.dig('assetDeliveryState', 'state') == 'AWAITING_UPLOAD' &&
      image['width'] == 0 && image['height'] == 0 && a['sourceFileChecksum'].to_s.empty? && no_asset_url
  end

  def self.image_backup(row, root, key)
    a = row.fetch('resource').fetch('attributes').fetch('imageAsset')
    dimensions = a.values_at('width', 'height')
    url = a.fetch('templateUrl').gsub('{w}', dimensions[0].to_s).gsub('{h}', dimensions[1].to_s).gsub('{f}', 'png')
    raise Error, 'Unknown CDN image template placeholder' if url.include?('{')
    name = "images/#{Digest::SHA256.hexdigest(key)}.png"
    path = File.join(root, name)
    unless File.file?(path)
      body = get(url, limit: 40_000_000)
      File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0600) { |f| f.binmode; f.write(body) }
    end
    verify_png(path, dimensions)
    {
      'file' => name, 'sha256' => Digest::SHA256.file(path).hexdigest, 'bytes' => File.size(path),
      'dimensions' => dimensions, 'representation' => 'Apple CDN full-resolution PNG rendering; not the original uploaded file'
    }
  end

  # Copy every URI in the HLS dependency tree, validating each remote URL, and
  # rewrite playlists to local relative paths. ffmpeg never gets a network URL.
  class LocalHLS
    attr_reader :files

    def initialize(dir)
      @dir = dir
      @files = {}
      @active = {}
    end

    def copy(url, playlist: false)
      uri = LegacyIOSMediaBackup.cdn_uri(url)
      raise Error, 'HLS reference cycle' if @active[url]
      return @files[url] if @files.key?(url)
      raise Error, 'Too many HLS dependencies' if @files.length > 2000
      @active[url] = true
      playlist ||= uri.path.end_with?('.m3u8')
      extension = playlist ? '.m3u8' : File.extname(uri.path)
      extension = '.bin' unless extension.match?(/\A\.[a-zA-Z0-9]{1,8}\z/)
      name = Digest::SHA256.hexdigest(url) + extension
      content = LegacyIOSMediaBackup.get(url, limit: playlist ? 2_000_000 : 100_000_000)
      if playlist
        raise Error, 'Invalid HLS playlist header' unless content.start_with?('#EXTM3U')
        content = content.lines.map do |line|
          if line.start_with?('#EXT-X-KEY:') && !line.include?('METHOD=NONE')
            raise Error, 'Encrypted HLS is not supported for offline restoration'
          end
          line = line.gsub(/URI="([^"]+)"/) do
            target = URI.join(url, Regexp.last_match(1)).to_s
            "URI=\"#{copy(target)}\""
          end
          if !line.strip.empty? && !line.start_with?('#')
            target = URI.join(url, line.strip).to_s
            "#{copy(target)}\n"
          else
            line
          end
        end.join
      end
      path = File.join(@dir, name)
      if File.exist?(path)
        raise Error, 'Existing HLS dependency content differs' unless File.binread(path) == content
      else
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0600) { |f| f.binmode; f.write(content) }
      end
      @files[url] = name
      @active.delete(url)
      name
    end
  end

  def self.run_command(*args)
    out, err, status = Open3.capture3(*args)
    raise Error, "#{File.basename(args.first)} failed: #{err[-2500, 2500] || err}" unless status.success?
    out
  end

  def self.probe(path, hls: false)
    args = [FFPROBE, '-v', 'error', '-protocol_whitelist', 'file,crypto']
    args += ['-allowed_extensions', 'ALL'] if hls
    JSON.parse(run_command(*args, '-show_streams', '-show_format', '-show_programs', '-of', 'json', path))
  end

  def self.video_backup(row, root, key)
    a = row.fetch('resource').fetch('attributes')
    digest = Digest::SHA256.hexdigest(key)
    dir = File.join(root, 'hls', digest)
    FileUtils.mkdir_p(dir, mode: 0700)
    hls = LocalHLS.new(dir)
    master = File.join(dir, hls.copy(a.fetch('videoUrl'), playlist: true))
    info = probe(master, hls: true)
    best = info.fetch('streams').select { |s| s['codec_type'] == 'video' }
               .max_by { |s| [s['width'].to_i * s['height'].to_i, s['bit_rate'].to_i] }
    raise Error, 'HLS has no video stream' unless best
    program = info.fetch('programs', []).find { |p| p.fetch('streams', []).any? { |s| s['index'] == best['index'] } }
    audio = (program ? program.fetch('streams') : info.fetch('streams')).find { |s| s['codec_type'] == 'audio' }
    name = "videos/#{digest}.mp4"
    path = File.join(root, name)
    unless File.file?(path)
      args = [FFMPEG, '-nostdin', '-hide_banner', '-v', 'error', '-n', '-protocol_whitelist', 'file,crypto',
              '-allowed_extensions', 'ALL', '-i', master, '-map', "0:#{best.fetch('index')}"]
      args += ['-map', "0:#{audio.fetch('index')}"] if audio
      run_command(*args, '-c', 'copy', '-movflags', '+faststart', path)
    end
    File.chmod(0600, path)
    final = probe(path)
    stream = final.fetch('streams').find { |s| s['codec_type'] == 'video' }
    raise Error, 'Offline MP4 has no video' unless stream
    dimensions = stream.values_at('width', 'height')
    raise Error, 'Offline MP4 dimensions changed' unless dimensions == best.values_at('width', 'height')
    duration = final.fetch('format').fetch('duration').to_f
    source_duration = info.fetch('format').fetch('duration').to_f
    raise Error, 'Offline MP4 duration mismatch' unless duration.positive? && source_duration.positive? && (duration - source_duration).abs < 1.0
    # Decode the complete MP4 locally; a readable header alone is not sufficient.
    run_command(FFMPEG, '-nostdin', '-hide_banner', '-v', 'error', '-xerror', '-protocol_whitelist', 'file,crypto',
                '-i', path, '-f', 'null', '-')
    {
      'file' => name, 'sha256' => Digest::SHA256.file(path).hexdigest, 'bytes' => File.size(path),
      'dimensions' => dimensions, 'durationSeconds' => duration, 'hlsDurationSeconds' => source_duration,
      'previewImageDimensions' => a.fetch('previewImage', {}).values_at('width', 'height'),
      'hlsFiles' => hls.files.length, 'representation' => 'Highest-resolution Apple CDN HLS rendition remuxed to independently playable MP4; not the original uploaded file'
    }
  end

  def self.main
    options = { workers: 6 }
    OptionParser.new do |p|
      p.on('--before PATH') { |v| options[:before] = File.expand_path(v) }
      p.on('--output PATH') { |v| options[:output] = File.expand_path(v) }
      p.on('--workers COUNT', Integer) { |v| options[:workers] = v }
    end.parse!
    raise Error, '--before and --output are required' unless options[:before] && options[:output]
    raise Error, 'Workers must be between 1 and 12' unless options[:workers].between?(1, 12)
    root = options.fetch(:output)
    raise Error, 'Refusing symlink output directory' if File.symlink?(root)
    raise Error, 'A complete manifest already exists; use a new output directory' if File.exist?(File.join(root, 'manifest.json'))
    File.umask(0077)
    FileUtils.mkdir_p(root, mode: 0700)
    %w[images videos hls metadata-only].each { |name| FileUtils.mkdir_p(File.join(root, name), mode: 0700) }
    source = File.binread(options.fetch(:before))
    snapshot_path = File.join(root, 'before.json')
    if File.exist?(snapshot_path)
      raise Error, 'Cannot resume using a different inventory' unless File.binread(snapshot_path) == source
    else
      File.open(snapshot_path, File::WRONLY | File::CREAT | File::EXCL, 0600) { |f| f.write(source) }
    end
    rows = resources(JSON.parse(source))
    raise Error, 'Duplicate resource identity in inventory' unless rows.map { |r| r['resource'].values_at('type', 'id') }.uniq.length == rows.length
    placeholders, media_rows = rows.partition { |row| empty_unuploaded_placeholder?(row) }
    unbacked, available = media_rows.partition { |row| unavailable_reason(row) }
    groups = available.group_by { |row| group_key(row) }
    puts "INVENTORY #{rows.length} resources; #{groups.length} unique complete assets; #{placeholders.length} empty unuploaded placeholders; #{unbacked.length} other unavailable"
    STDOUT.flush
    queue = Queue.new
    groups.each { |key, group| queue << [key, group] }
    results = {}
    errors = []
    mutex = Mutex.new
    threads = Array.new([options.fetch(:workers), groups.length].min) do
      Thread.new do
        loop do
          item = queue.pop(true) rescue nil
          break unless item
          key, group = item
          begin
            row = group.first
            result = row['resource']['type'] == 'appScreenshots' ? image_backup(row, root, key) : video_backup(row, root, key)
            mutex.synchronize do
              results[key] = result
              if results.length % 20 == 0 || row['resource']['type'] == 'appPreviews'
                puts "BACKED UP #{results.length}/#{groups.length} unique assets (#{row['resource']['type']})"
                STDOUT.flush
              end
            end
          rescue StandardError => e
            mutex.synchronize { errors << { 'ids' => group.map { |r| r['resource']['id'] }, 'error' => "#{e.class}: #{e.message}" } }
          end
        end
      end
    end
    threads.each(&:join)
    unless errors.empty?
      path = File.join(root, "errors-#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}.json")
      save(path, errors)
      raise Error, "#{errors.length} unique media backups failed; see #{path}. No manifest was generated."
    end
    details = available.map do |row|
      resource = row.fetch('resource')
      row.reject { |k, _| k == 'resource' }.merge('type' => resource.fetch('type'), 'id' => resource.fetch('id'),
          'fileName' => resource.dig('attributes', 'fileName'), 'sourceFileChecksum' => resource.dig('attributes', 'sourceFileChecksum'),
          'previewFrameTimeCode' => resource.dig('attributes', 'previewFrameTimeCode'), 'backupKind' => 'media').merge(results.fetch(group_key(row)))
    end
    placeholders.each do |row|
      resource = row.fetch('resource')
      name = "metadata-only/#{Digest::SHA256.hexdigest(resource.fetch('id'))}.json"
      path = File.join(root, name)
      # Keep the resource itself byte-for-byte equivalent as parsed JSON. The
      # manifest and details carry the explicit metadata-only classification.
      save(path, resource)
      details << row.reject { |k, _| k == 'resource' }.merge(
        'type' => resource.fetch('type'), 'id' => resource.fetch('id'), 'file' => name,
        'sha256' => Digest::SHA256.file(path).hexdigest, 'bytes' => File.size(path),
        'backupKind' => 'metadata-only-unuploaded', 'representation' => 'Empty unuploaded placeholder metadata only; no image bytes exist in ASC')
    end
    save(File.join(root, 'backup-details.json'), details)
    save(File.join(root, 'unbacked-assets.json'), unbacked.map { |r| r.merge('reason' => unavailable_reason(r)) })
    manifest = { 'version' => 1, 'baseDir' => root, 'assets' => details.map { |r| r.slice('type', 'id', 'file', 'sha256', 'backupKind') } }
    save(File.join(root, 'manifest.json'), manifest)
    summary = {
      'inventoryResources' => rows.length, 'backedUpResources' => details.length,
      'backedUpByType' => details.group_by { |r| r['type'] }.transform_values(&:length),
      'backedUpByKind' => details.group_by { |r| r['backupKind'] }.transform_values(&:length),
      'unavailableResources' => unbacked.length, 'uniqueMediaFiles' => results.length,
      'uniqueMediaBytes' => results.values.sum { |r| r.fetch('bytes') },
      'sourceInventorySha256' => Digest::SHA256.hexdigest(source),
      'manifestSha256' => Digest::SHA256.file(File.join(root, 'manifest.json')).hexdigest,
      'recoverability' => 'Complete assets have verified full-resolution PNGs or offline-playable MP4s and original inventory metadata. CDN representations are not byte-identical originals. Video CDN renditions may be lower resolution than the upload and do not guarantee original-specification restoration. metadata-only-unuploaded entries preserve empty unuploaded placeholder metadata only, never original screenshot bytes. Other unavailable assets are not backed up and must not be deleted using this manifest.'
    }
    save(File.join(root, 'summary.json'), summary)
    puts JSON.pretty_generate(summary)
    exit(2) unless unbacked.empty?
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    LegacyIOSMediaBackup.main
  rescue LegacyIOSMediaBackup::Error => e
    warn "BACKUP FAILED: #{e.message}"
    exit 1
  end
end
