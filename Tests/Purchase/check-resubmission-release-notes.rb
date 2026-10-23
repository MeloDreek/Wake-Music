#!/usr/bin/env ruby
# frozen_string_literal: true

# Completely offline. No real ASC account, network, private key, or shipping
# project data is read or mutated. The fixture rejects every unrelated endpoint.
require 'tmpdir'
require 'stringio'
require_relative '../../Tools/AppStoreConnect/sync-resubmission-release-notes'

module ResubmissionReleaseNotesTests
  Sync = ResubmissionReleaseNotesSync
  class Fixture
    attr_accessor :allowed_ids, :app, :version, :rows, :wrong_owner, :concurrent,
                  :state_after_first, :fail_on_patch, :change_other_on_readback,
                  :change_catalog, :version_changed
    attr_reader :writes, :attempts, :requests

    def initialize
      @app = { 'id' => Sync::TARGET['appId'], 'type' => 'apps',
               'attributes' => { 'bundleId' => Sync::TARGET['bundleId'], 'name' => 'Wakemusic' } }
      @version = { 'id' => Sync::TARGET['versionId'], 'type' => 'appStoreVersions',
                   'attributes' => { 'platform' => 'IOS', 'versionString' => '3.6.0',
                                     'appStoreState' => 'READY_FOR_REVIEW', 'releaseType' => 'MANUAL' } }
      @rows = Sync::LOCALES.each_with_index.map do |locale, index|
        { 'id' => "locale-#{index}", 'type' => 'appStoreVersionLocalizations',
          'attributes' => { 'locale' => locale, 'whatsNew' => 'Old release notes.',
                            'description' => "Keep this description: #{locale}", 'keywords' => 'music,offline',
                            'promotionalText' => 'Offline music.', 'marketingUrl' => 'https://example.com',
                            'supportUrl' => 'https://example.com/support' } }
      end
      @writes = []
      @attempts = 0
      @requests = []
    end

    def metadata_field
      'whatsNew'
    end

    def copy(value)
      Marshal.load(Marshal.dump(value))
    end

    def list(path)
      @requests << ['GET', path]
      case path
      when "/v1/apps/#{Sync::TARGET['appId']}/appStoreVersions?limit=200"
        wrong_owner ? [] : [copy(version)]
      when "/v1/appStoreVersions/#{Sync::TARGET['versionId']}/appStoreVersionLocalizations?limit=200"
        values = copy(rows)
        values.first['attributes']['description'] = 'Unexpected external edit' if change_other_on_readback && !writes.empty?
        values
      else
        raise Sync::Error, "Unexpected fixture list endpoint: #{path}"
      end
    end

    def request(method, path, body = nil)
      @requests << [method, path]
      if method == 'GET'
        case path
        when "/v1/apps/#{Sync::TARGET['appId']}"
          return { 'data' => copy(app) }
        when "/v1/appStoreVersions/#{Sync::TARGET['versionId']}"
          value = copy(version)
          value['attributes']['appStoreState'] = 'IN_REVIEW' if state_after_first && !writes.empty?
          value['attributes']['releaseType'] = 'AFTER_APPROVAL' if version_changed && !writes.empty?
          return { 'data' => value }
        else
          id = path.delete_prefix('/v1/appStoreVersionLocalizations/')
          row = rows.find { |item| item['id'] == id }
          raise Sync::Error, "Unexpected fixture GET: #{path}" unless row
          value = copy(row)
          value['attributes']['description'] = 'Concurrent metadata edit' if concurrent
          change_catalog.call if change_catalog
          return { 'data' => value }
        end
      end
      data = body.fetch('data')
      unless method == 'PATCH' && allowed_ids.include?(data['id']) &&
             path == "/v1/appStoreVersionLocalizations/#{data['id']}" && body.keys == ['data'] &&
             data.keys.sort == %w[attributes id type] && data['type'] == 'appStoreVersionLocalizations' &&
             data['attributes'].keys == ['whatsNew']
        raise Sync::Error, 'Fixture rejected non-whatsNew write.'
      end
      @attempts += 1
      raise Sync::Error, 'Uncertain PATCH transport failure' if fail_on_patch == @attempts
      row = rows.find { |item| item['id'] == data['id'] }
      row['attributes'].merge!(data['attributes'])
      writes << copy(body)
      { 'data' => copy(row) }
    end
  end

  class << self
    def check(condition, message)
      @checks = (@checks || 0) + 1
      raise message unless condition
    end

    def rejects(message)
      begin
        yield
      rescue Sync::Error
        check(true, message)
        return
      end
      check(false, message)
    end

    def write_catalog(path, texts)
      File.write(path, JSON.generate(texts), mode: 'w', perm: 0600)
    end

    def sync(fixture, dir, name, path, apply = true)
      Sync.sync(fixture, catalog_path: path, output: File.join(dir, name), apply: apply)
    end

    def run
      original_stdout = $stdout
      $stdout = StringIO.new
      Dir.mktmpdir('release-resubmission-tests-') do |dir|
        path = File.join(dir, 'catalog.json')
        texts = Sync::LOCALES.to_h { |locale| [locale, "◆◆◆ Major Update\n\n1. Updated music playback.\n2. Improved recognition.\n\n#{locale}: support@kakainc.com"] }
        write_catalog(path, texts)
        catalog, fingerprint = Sync.load_catalog(path)
        check(catalog.length == 39, 'Exactly 39 locales')
        check(catalog.frozen? && catalog.values.all?(&:frozen?), 'Plan text must be immutable')
        check(fingerprint['sha256'] == Digest::SHA256.file(path).hexdigest, 'Catalog fingerprint')

        # --validate must not touch even a nonexistent credential path or output.
        output = File.join(dir, 'no-validation-output')
        Sync.main(['--validate', '--catalog', path, '--key-file', '/does/not/exist.p8', '--output', output])
        check(!File.exist?(output), 'Offline validate unexpectedly wrote output')

        fixture = Fixture.new
        original_rows = fixture.copy(fixture.rows)
        sync(fixture, dir, 'dry', path, false)
        check(fixture.writes.empty?, 'Dry-run performed writes')
        check(!File.exist?(File.join(dir, 'dry', 'verified.json')), 'Dry-run claimed verified writes')
        sync(fixture, dir, 'apply', path)
        check(fixture.writes.length == 39, 'Only one target / exactly 39 writes')
        check(fixture.writes.all? { |write| write.dig('data', 'attributes').keys == ['whatsNew'] }, 'Unexpected changed fields')
        check(fixture.rows.each_with_index.all? { |row, i| row['attributes'].reject { |k, _| k == 'whatsNew' } == original_rows[i]['attributes'].reject { |k, _| k == 'whatsNew' } }, 'Other locale metadata changed')
        check(fixture.requests.select { |method, _| method != 'GET' }.all? { |method, endpoint| method == 'PATCH' && endpoint.start_with?('/v1/appStoreVersionLocalizations/') }, 'Unexpected write endpoint')
        check(fixture.allowed_ids.empty?, 'Write capability not revoked after sync')
        %w[before.json catalog.json plan.json completed.json verified.json].each do |filename|
          file = File.join(dir, 'apply', filename)
          check(File.file?(file) && (File.stat(file).mode & 0777) == 0600, "Backup file absent/insecure: #{filename}")
        end
        check((File.stat(File.join(dir, 'apply')).mode & 0777) == 0700, 'Output directory permissions')
        completed = JSON.parse(File.read(File.join(dir, 'apply', 'completed.json')))
        check(completed.size == 39 && completed.all? { |row| row['versionId'] == Sync::TARGET['versionId'] }, 'Completed scope')
        sync(fixture, dir, 'repeat', path)
        check(fixture.writes.length == 39, 'Identical rerun must be idempotent')
        rejects('Existing backup must not be overwritten') { sync(fixture, dir, 'apply', path) }

        bad_cases = {
          'wrong-app' => ->(f) { f.app['id'] = '6740429002' },
          'wrong-bundle' => ->(f) { f.app['attributes']['bundleId'] = 'com.OfflineMusic.www.pro' },
          'wrong-owner' => ->(f) { f.wrong_owner = true },
          'wrong-platform' => ->(f) { f.version['attributes']['platform'] = 'MAC_OS' },
          'wrong-version-id' => ->(f) { f.version['id'] = 'another-version' },
          'wrong-version-string' => ->(f) { f.version['attributes']['versionString'] = '3.6.1' },
          'wrong-resource-type' => ->(f) { f.rows.first['type'] = 'appInfoLocalizations' },
          'extra-locale' => ->(f) { f.rows << f.copy(f.rows.first).merge('id' => 'extra') },
          'missing-locale' => ->(f) { f.rows.pop },
          'duplicate-id' => ->(f) { f.rows.last['id'] = f.rows.first['id'] },
          'concurrent-description' => ->(f) { f.concurrent = true }
        }
        %w[IN_REVIEW WAITING_FOR_REVIEW READY_FOR_SALE PENDING_DEVELOPER_RELEASE PROCESSING_FOR_APP_STORE].each do |state|
          bad_cases["state-#{state}"] = ->(f) { f.version['attributes']['appStoreState'] = state }
        end
        bad_cases.each do |name, configure|
          bad = Fixture.new
          configure.call(bad)
          rejects("Failed to stop #{name}") { sync(bad, dir, name, path) }
          check(bad.writes.empty?, "Wrote despite #{name}")
        end
        Sync::EDITABLE_STATES.each do |state|
          allowed = Fixture.new
          allowed.version['attributes']['appStoreState'] = state
          sync(allowed, dir, "editable-#{state}", path, false)
          check(allowed.writes.empty?, "Dry-run in allowed #{state}")
        end
        withdrawn = Fixture.new
        withdrawn.version['attributes']['appStoreState'] = 'DEVELOPER_REJECTED'
        sync(withdrawn, dir, 'withdrawn-apply', path)
        check(withdrawn.writes.size == 39, 'Withdrawn version allows only its 39 localized release-note updates')
        check(withdrawn.version['attributes']['appStoreState'] == 'DEVELOPER_REJECTED', 'Withdrawn version must remain withdrawn')

        { 'mid-review' => :state_after_first, 'mid-version-metadata' => :version_changed }.each do |name, setting|
          bad = Fixture.new
          bad.public_send("#{setting}=", true)
          rejects("Failed to stop #{name}") { sync(bad, dir, name, path) }
          check(bad.writes.length == 1, 'Version must be rechecked before each write')
          check(JSON.parse(File.read(File.join(dir, name, 'completed.json'))).length == 1, 'Progress backup after partial sync')
        end
        uncertain = Fixture.new
        uncertain.fail_on_patch = 2
        rejects('Uncertain PATCH must stop') { sync(uncertain, dir, 'uncertain', path) }
        check(uncertain.attempts == 2 && uncertain.writes.size == 1, 'Uncertain PATCH was retried')
        check(!File.exist?(File.join(dir, 'uncertain', 'verified.json')), 'Failed run falsely verified')
        check(uncertain.allowed_ids.empty?, 'Write capability leaked after failure')
        mismatch = Fixture.new
        mismatch.change_other_on_readback = true
        rejects('Readback must compare every metadata field') { sync(mismatch, dir, 'mismatch', path) }
        check(!File.exist?(File.join(dir, 'mismatch', 'verified.json')), 'Other-field mismatch falsely verified')
        mutated = Fixture.new
        mutated.change_catalog = -> { File.open(path, 'a') { |file| file.write("\n") } }
        rejects('Source hash must be rechecked immediately before PATCH') { sync(mutated, dir, 'mutated-source', path) }
        check(mutated.writes.empty?, 'Changed local source allowed writes')
        write_catalog(path, texts)

        invalid = texts.dup
        invalid.delete('en-US')
        write_catalog(path, invalid)
        rejects('Missing locale accepted') { Sync.load_catalog(path) }
        invalid['unknown-Lang'] = 'Unexpected locale'
        write_catalog(path, invalid)
        rejects('Unknown locale accepted') { Sync.load_catalog(path) }
        File.write(path, JSON.generate(texts).sub('"ar-SA":', '"en-US":"Duplicate","ar-SA":'))
        rejects('Duplicate JSON locale accepted') { Sync.load_catalog(path) }
        [nil, 23, '', ' x', "x\n", 'a' * 4001, '😀' * 2001, '<b>hello</b>', '[link](https://example.com)',
         '![image](image.png)', '```code```', '**bold**', '# Heading', '{{UNRESOLVED}}', "a\r\nb", "a\u0000b", "a\tb"].each do |value|
          write_catalog(path, texts.merge('en-US' => value))
          rejects("Invalid text accepted: #{value.inspect[0, 45]}") { Sync.load_catalog(path) }
        end
        ['x' * 4000, '😀' * 2000, "◆◆◆ Update\n\n1. Good plain text."].each do |value|
          write_catalog(path, texts.merge('en-US' => value))
          check(Sync.load_catalog(path).first['en-US'] == value, 'Valid UTF-16 boundary/plain text rejected')
        end
      end

      # Invoke the real client's preflight guard. All requests are invalid and
      # must be rejected before any network or key/token access is attempted.
      client = Sync::Client.allocate
      client.allowed_ids = ['known']
      base = { 'data' => { 'type' => 'appStoreVersionLocalizations', 'id' => 'known', 'attributes' => { 'whatsNew' => 'Allowed text' } } }
      [
        ['POST', '/v1/reviewSubmissions', {}], ['PATCH', '/v1/appStoreVersions/version', {}],
        ['DELETE', '/v1/appStoreVersionLocalizations/known', nil],
        ['PATCH', '/v1/appStoreVersionLocalizations/known', nil],
        ['PATCH', '/v1/appStoreVersionLocalizations/unknown', base],
        ['PATCH', '/v1/appStoreVersionLocalizations/known', { 'data' => base['data'].merge('attributes' => { 'description' => 'Not permitted' }) }],
        ['PATCH', '/v1/appStoreVersionLocalizations/known', { 'data' => base['data'].merge('attributes' => { 'whatsNew' => 'Text', 'promotionalText' => 'No' }) }],
        ['PATCH', '/v1/appStoreVersionLocalizations/known', { 'data' => base['data'].merge('relationships' => {}) }],
        ['PATCH', '/v1/appStoreVersionLocalizations/known', { 'data' => base['data'].merge('attributes' => { 'whatsNew' => '😀' * 2001 }) }]
      ].each do |method, path, body|
        rejects('Production write guard accepted forbidden request') { client.request(method, path, body) }
      end
      check(Sync::Client < ReleaseNotesSync::Client, 'Must reuse the no-retry whatsNew-only client')
      check(Sync::TARGET['appId'] == '6544783918' && Sync::TARGET['platform'] == 'IOS', 'Unexpected target scope')
    ensure
      $stdout = original_stdout
    end

    def main
      run
      puts "PASS: #{@checks} offline assertions; one allowlisted version, 39 locales, no review/state/other-field mutations."
    end
  end
end

ResubmissionReleaseNotesTests.main if $PROGRAM_NAME == __FILE__
