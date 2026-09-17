# Optional read-only integration smoke test. Credentials are read from the two
# developer-owned DEBUG fixtures, kept in memory, and never printed or persisted.
require 'uri'
require 'json'
require 'digest'
require 'securerandom'
require 'open3'

root = File.expand_path('../..', __dir__)
source = File.read(File.join(root, 'Mobie/Mobie/Business/ImportModule/Controller/AuthNavidromeController.swift'))
fixtures = source.scan(/hostUrl: "([^"]+)"[^\n]*username: "([^"]+)", password: "([^"]+)"/)
raise 'Expected two DEBUG fixtures' unless fixtures.size == 2

def request(url, body = nil)
  # Keep signed URLs and login bodies off the process command line. curl uses
  # the normal system TLS validation; no redirects or certificate bypasses.
  config = ["url = #{JSON.generate(url.to_s)}", 'write-out = "\n%{http_code}"']
  if body
    config += ['request = "POST"', 'header = "Content-Type: application/json"', "data = #{JSON.generate(JSON.generate(body))}"]
  end
  output, _, status = Open3.capture3('curl', '--silent', '--show-error', '--connect-timeout', '12', '--max-time', '40', '--max-filesize', '4194304', '--config', '-', stdin_data: config.join("\n"))
  raise 'Transport failed' unless status.success?
  bytes, _, code = output.rpartition("\n")
  raise "HTTP #{code.to_i}" unless code.to_i.between?(200, 299)
  raise 'Response too large' if bytes.bytesize > 4 * 1024 * 1024
  JSON.parse(bytes)
end

fixtures.each_with_index do |(host, username, password), index|
  next if ENV['MUSIC_SERVER_SMOKE_ACCOUNT'] && ENV['MUSIC_SERVER_SMOKE_ACCOUNT'].to_i != index + 1
  begin
    base = host.sub(%r{/+$}, '')
    login = request(URI(base + '/auth/login'), {username: username, password: password})
    salt = login['subsonicSalt'] || SecureRandom.hex(12)
    token = login['subsonicToken'] || Digest::MD5.hexdigest(password + salt)
    auth = {u: username, t: token, s: salt, v: '1.16.1', c: 'WakeMusicSmoke', f: 'json'}
    checked = 0
    matches = 0
    %w[love 周].each do |query|
      %w[song artist album].each do |kind|
        previous = []
        [0, 2].each do |offset|
          params = auth.merge(query: query, songCount: 0, artistCount: 0, albumCount: 0)
          params[(kind + 'Count').to_sym] = 2
          params[(kind + 'Offset').to_sym] = offset
          url = URI(base + '/rest/search3')
          url.query = URI.encode_www_form(params)
          response = request(url).fetch('subsonic-response')
          raise 'Search API rejected request' unless response['status'] == 'ok'
          result = response['searchResult3'] || {}
          rows = result[kind] || []
          matches += rows.count
          raise 'Page exceeds requested limit' if rows.length > 2
          ids = rows.map { |row| row.fetch('id') }
          raise 'Pages overlap' unless (previous & ids).empty?
          previous += ids
          (%w[song artist album] - [kind]).each do |other|
            raise 'Unrequested category returned' unless (result[other] || []).empty?
          end
          checked += 1
        end
      end
    end
    raise 'Positive search fixture returned no matches' if matches.zero?
    url = URI(base + '/rest/search3')
    url.query = URI.encode_www_form(auth.merge(query: "wakemusic-no-result-#{SecureRandom.hex(16)}", songCount: 2, artistCount: 2, albumCount: 2))
    response = request(url).fetch('subsonic-response')
    raise 'Empty-query test rejected' unless response['status'] == 'ok'
    raise 'Expected no matches' unless %w[song artist album].all? { |kind| (response.fetch('searchResult3', {})[kind] || []).empty? }
    puts "Account #{index + 1}: #{checked} bounded search pages + no-match query passed"
  rescue StandardError => error
    # Exception messages can contain URLs or response bodies; print only class.
    abort "Account #{index + 1}: failed (#{error.class})"
  end
end
