#!/usr/bin/env ruby
# frozen_string_literal: true

# Fully offline regression tests: synthetic data, local backups, no P8/ASC access.
require 'minitest/autorun'
require 'tmpdir'
require_relative '../../Tools/AppStoreConnect/remove-legacy-ios-media'

class LegacyIOSMediaCleanupTest < Minitest::Test
  Cleanup = LegacyIOSMediaCleanup

  def clone(value)
    Marshal.load(Marshal.dump(value))
  end

  def resource(type, id, attrs)
    { 'type' => type, 'id' => id, 'attributes' => attrs }
  end

  def image(id, state: 'COMPLETE')
    resource('appScreenshots', id, 'fileName' => "#{id}.png", 'fileSize' => 100,
             'sourceFileChecksum' => "checksum-#{id}",
             'imageAsset' => { 'templateUrl' => 'https://example.invalid/{w}x{h}.{f}', 'width' => 1284, 'height' => 2778 },
             'assetDeliveryState' => { 'state' => state })
  end

  def fixture
    [{ 'target' => Cleanup::TARGET_ARRAY.dup,
       'version' => resource('appStoreVersions', Cleanup::TARGET['versionId'],
                             'versionString' => '3.6.0', 'platform' => 'IOS', 'appStoreState' => 'DEVELOPER_REJECTED', 'copyright' => 'original'),
       'localizations' => ResubmissionReleaseNotesSync::LOCALES.each_with_index.map do |locale, i|
         { 'localization' => resource('appStoreVersionLocalizations', "loc-#{i}",
                                     'locale' => locale, 'description' => 'unchanged description', 'supportUrl' => 'https://example.invalid/support'),
           'screenshotSets' => [
             { 'resource' => resource('appScreenshotSets', "old-#{i}", 'screenshotDisplayType' => 'APP_IPHONE_65'),
               'screenshots' => [image("old-#{i}-a"), image("old-#{i}-b")] },
             { 'resource' => resource('appScreenshotSets', "new-#{i}", 'screenshotDisplayType' => 'APP_IPHONE_61'),
               'screenshots' => [image("new-#{i}-a"), image("new-#{i}-b")] },
             { 'resource' => resource('appScreenshotSets', "ipad-#{i}", 'screenshotDisplayType' => 'APP_IPAD_PRO_3GEN_129'),
               'screenshots' => [image("ipad-#{i}-a")] }
           ],
           'previewSets' => [
             { 'resource' => resource('appPreviewSets', "preview-#{i}", 'previewType' => 'IPHONE_65'),
               'previews' => [resource('appPreviews', "video-#{i}", 'fileName' => 'video.mp4', 'fileSize' => 123,
                                      'sourceFileChecksum' => 'original-video', 'videoUrl' => 'https://example.invalid/video.m3u8',
                                      'previewFrameTimeCode' => '00:00:05:01', 'videoDeliveryState' => { 'state' => 'COMPLETE' })] }
           ] }
       end }]
  end

  def plan_for(before, ids)
    Cleanup.index(before)['assets'].values.map do |ctx|
      a = ctx['asset']
      next unless ids.include?(a['id'])
      a.slice('type', 'id').merge('localizationId' => ctx['localizationId'], 'setId' => ctx['resource']['id'])
    end.compact
  end

  def remove_from(snapshot, ids)
    snapshot.first['localizations'].each do |loc|
      %w[screenshotSets previewSets].each do |group|
        loc[group].each do |set|
          children = group == 'screenshotSets' ? 'screenshots' : 'previews'
          set[children].reject! { |a| ids.include?(a['id']) }
        end
      end
    end
    snapshot
  end

  def backup_manifest(root, plan)
    dir = File.join(root, 'backups')
    Dir.mkdir(dir) unless File.directory?(dir)
    { 'version' => 1, 'baseDir' => dir,
      'assets' => plan.map do |row|
        name = "#{row['id']}.bin"
        # Test-only synthetic payload, never used by the real account workflow.
        File.binwrite(File.join(dir, name), "backup-#{row['id']}")
        row.slice('type', 'id').merge('file' => name, 'sha256' => Digest::SHA256.file(File.join(dir, name)).hexdigest)
      end }
  end

  class FakeClient
    attr_reader :snapshot, :deletes, :calls
    attr_accessor :before_request, :fail_delete_number, :mutate_then_fail

    def initialize(snapshot)
      @snapshot = Marshal.load(Marshal.dump(snapshot))
      @deletes, @calls = [], []
    end

    def allow_plan!(plan)
      @allowed = plan.map { |row| LegacyIOSMediaCleanup.key(row) }.to_set
    end

    def value_copy(value)
      Marshal.load(Marshal.dump(value))
    end

    def idx
      LegacyIOSMediaCleanup.index(@snapshot)
    end

    def request(method, path, body = nil)
      @calls << [method, path]
      @before_request&.call(self, method, path)
      if method == 'GET'
        result = case path
                 when "/v1/apps/#{LegacyIOSMediaCleanup::TARGET['appId']}"
                   { 'type' => 'apps', 'id' => LegacyIOSMediaCleanup::TARGET['appId'],
                     'attributes' => { 'bundleId' => LegacyIOSMediaCleanup::TARGET['bundleId'] } }
                 when "/v1/appStoreVersions/#{LegacyIOSMediaCleanup::TARGET['versionId']}"
                   @snapshot.first['version']
                 when %r{\A/v1/appStoreVersionLocalizations/([A-Za-z0-9-]+)\z}
                   idx['localizations'].fetch(Regexp.last_match(1))
                 when %r{\A/v1/(appScreenshots|appPreviews)/([A-Za-z0-9-]+)\z}
                   idx['assets'].fetch([Regexp.last_match(1), Regexp.last_match(2)]).fetch('asset')
                 else raise "Unexpected fake GET: #{path}"
                 end
        return { 'data' => value_copy(result) }
      end
      match = path.match(%r{\A/v1/(appScreenshots|appPreviews)/([A-Za-z0-9-]+)\z})
      raise 'Unallowlisted fake mutation' unless method == 'DELETE' && body.nil? && match && @allowed.include?([match[1], match[2]])
      k = [match[1], match[2]]
      @deletes << k
      fail_now = @fail_delete_number == @deletes.length
      idx['assets'].fetch(k)['assets'].reject! { |a| [a['type'], a['id']] == k } if !fail_now || @mutate_then_fail
      raise LegacyIOSMediaCleanup::Error, 'Uncertain fake delete failure' if fail_now
      {}
    end

    def list(path)
      @calls << ['GET', path]
      @before_request&.call(self, 'GET', path)
      result = case path
               when "/v1/apps/#{LegacyIOSMediaCleanup::TARGET['appId']}/appStoreVersions?limit=200"
                 [@snapshot.first['version']]
               when "/v1/appStoreVersions/#{LegacyIOSMediaCleanup::TARGET['versionId']}/appStoreVersionLocalizations?limit=200"
                 @snapshot.first['localizations'].map { |l| l['localization'] }
               when %r{\A/v1/appStoreVersionLocalizations/([A-Za-z0-9-]+)/(appScreenshotSets|appPreviewSets)\?limit=200\z}
                 loc_id, set_type = Regexp.last_match(1), Regexp.last_match(2)
                 idx['sets'].select { |k, v| k.first == set_type && v['localizationId'] == loc_id }.values.map { |s| s['resource'] }
               when %r{\A/v1/(appScreenshotSets|appPreviewSets)/([A-Za-z0-9-]+)/(appScreenshots|appPreviews)\?limit=200\z}
                 idx['sets'].fetch([Regexp.last_match(1), Regexp.last_match(2)]).fetch('assets')
               else raise "Unexpected fake list: #{path}"
               end
      value_copy(result)
    end
  end

  def test_plan_accepts_iphone_dimensions_and_both_types_but_rejects_ipad
    b = fixture
    plan = plan_for(b, %w[old-0-a new-0-a video-0])
    assert_equal 3, Cleanup.validate_plan!(b, plan).length
    assert_raises(Cleanup::Error) { Cleanup.validate_plan!(b, plan_for(b, ['ipad-0-a'])) }
    bad = clone(plan)
    bad.first['localizationId'] = 'loc-1'
    assert_raises(Cleanup::Error) { Cleanup.validate_plan!(b, bad) }
    bad = clone(plan)
    bad.first['setId'] = 'new-0'
    assert_raises(Cleanup::Error) { Cleanup.validate_plan!(b, bad) }
    assert_raises(Cleanup::Error) { Cleanup.validate_plan!(b, plan + [plan.first]) }
  end

  def test_rejects_other_apps_platforms_versions_and_live_states
    b = fixture
    plan = plan_for(b, ['old-0-a'])
    [0, 1, 2, 3, 4].each do |position|
      changed = clone(b)
      changed.first['target'][position] = 'other'
      assert_raises(Cleanup::Error) { Cleanup.validate_plan!(changed, plan) }
    end
    changed = clone(b)
    changed.first['version']['attributes']['appStoreState'] = 'READY_FOR_SALE'
    assert_raises(Cleanup::Error) { Cleanup.validate_plan!(changed, plan) }
    assert_raises(Cleanup::Error) { Cleanup.validate_plan!(b + b, plan) }
  end

  def test_missing_duplicate_and_forged_plan_ids_are_rejected
    b = fixture
    plan = plan_for(b, ['old-0-a'])
    %w[id localizationId setId type].each do |field|
      bad = clone(plan)
      bad.first.delete(field)
      assert_raises(Cleanup::Error) { Cleanup.validate_plan!(b, bad) }
    end
    plan.first['id'] = 'old-0-a?other=1'
    assert_raises(Cleanup::Error) { Cleanup.validate_plan!(b, plan) }
  end

  def test_delete_client_denies_all_unplanned_and_non_media_mutations_without_network
    client = Cleanup::Client.allocate
    client.allow_plan!([{ 'type' => 'appScreenshots', 'id' => 'planned' }])
    [ ['DELETE', '/v1/appScreenshots/other', nil], ['DELETE', '/v1/appPreviews/planned', nil],
      ['DELETE', '/v1/appScreenshotSets/planned', nil], ['DELETE', '/v1/appPreviewSets/planned', nil],
      ['DELETE', '/v1/appScreenshots/planned?x=1', nil], ['DELETE', '/v1/appScreenshots/planned', {}],
      ['POST', '/v1/appStoreVersionSubmissions', {}], ['PATCH', '/v1/appStoreVersionLocalizations/planned', {}]
    ].each { |args| assert_raises(Cleanup::Error) { client.request(*args) } }
  end

  def test_backups_must_all_exist_have_correct_hash_and_be_contained
    plan = plan_for(fixture, %w[old-0-a video-0])
    Dir.mktmpdir('legacy-media-tests-') do |dir|
      m = backup_manifest(dir, plan)
      assert_equal 2, Cleanup.verify_backups!(m, plan).length
      missing = clone(m)
      missing['assets'].pop
      assert_raises(Cleanup::Error) { Cleanup.verify_backups!(missing, plan) }
      bad = clone(m)
      bad['assets'].first['sha256'] = '0' * 64
      assert_raises(Cleanup::Error) { Cleanup.verify_backups!(bad, plan) }
      duplicate = clone(m)
      duplicate['assets'] << duplicate['assets'].first
      assert_raises(Cleanup::Error) { Cleanup.verify_backups!(duplicate, plan) }
      outside = File.join(dir, 'outside.bin')
      File.binwrite(outside, 'outside')
      bad = clone(m)
      bad['assets'].first['file'] = '../outside.bin'
      bad['assets'].first['sha256'] = Digest::SHA256.file(outside).hexdigest
      assert_raises(Cleanup::Error) { Cleanup.verify_backups!(bad, plan) }
      File.symlink(outside, File.join(m['baseDir'], 'escaped.bin'))
      bad['assets'].first['file'] = 'escaped.bin'
      assert_raises(Cleanup::Error) { Cleanup.verify_backups!(bad, plan) }
    end
  end

  def test_verification_preserves_unplanned_order_and_records_concurrent_61_uploads
    b = fixture
    plan = plan_for(b, %w[old-0-a video-0])
    after = remove_from(clone(b), plan.map { |p| p['id'] })
    after.first['localizations'].first['screenshotSets'][1]['screenshots'].insert(1, image('new-concurrent'))
    changes = Cleanup.verify!(b, after, plan)
    assert_equal ['new-concurrent'], changes['new61Assets'].map { |a| a['id'] }
    assert_equal 3, after.first['localizations'].first['screenshotSets'].length
    wrong_order = clone(after)
    wrong_order.first['localizations'].first['screenshotSets'][1]['screenshots'].reverse!
    assert_raises(Cleanup::Error) { Cleanup.verify!(b, wrong_order, plan) }
    missing = remove_from(clone(after), ['ipad-0-a'])
    assert_raises(Cleanup::Error) { Cleanup.verify!(b, missing, plan) }
    assert_raises(Cleanup::Error) { Cleanup.verify!(b, b, plan) }
  end

  def test_transport_urls_may_change_but_metadata_urls_may_not
    b, after = fixture, fixture
    after.first['localizations'].first['previewSets'].first['previews'].first['attributes']['videoUrl'] = 'https://example.invalid/new-signature'
    Cleanup.verify!(b, after, [])
    after.first['localizations'].first['localization']['attributes']['supportUrl'] = 'https://example.invalid/changed'
    assert_raises(Cleanup::Error) { Cleanup.verify!(b, after, []) }
  end

  def test_only_unfinished_61_images_may_finish_processing
    b = fixture
    asset = b.first['localizations'].first['screenshotSets'][1]['screenshots'].first
    asset['attributes']['assetDeliveryState']['state'] = 'UPLOAD_COMPLETE'
    asset['attributes']['imageAsset'] = nil
    after = clone(b)
    a = after.first['localizations'].first['screenshotSets'][1]['screenshots'].first
    a['attributes']['assetDeliveryState']['state'] = 'COMPLETE'
    a['attributes']['imageAsset'] = { 'width' => 1206, 'height' => 2622 }
    assert_equal [['appScreenshots', 'new-0-a']], Cleanup.verify!(b, after, [])['completed61Processing']
    a['attributes']['fileName'] = 'changed.png'
    assert_raises(Cleanup::Error) { Cleanup.verify!(b, after, []) }
  end

  def test_dry_run_is_offline_and_does_not_need_a_key_or_backup
    b = fixture
    plan = plan_for(b, ['video-0'])
    Dir.mktmpdir('legacy-media-tests-') do |dir|
      output = File.join(dir, 'dry')
      capture_io { Cleanup.run(nil, before: b, plan: plan, manifest: nil, output: output) }
      assert_equal [], JSON.parse(File.read(File.join(output, 'completed.json')))
      assert File.file?(File.join(output, 'plan.json'))
    end
  end

  def test_apply_deletes_only_plan_and_persists_each_completion
    b = fixture
    plan = plan_for(b, %w[old-0-a new-0-a video-0])
    client = FakeClient.new(b)
    Dir.mktmpdir('legacy-media-tests-') do |dir|
      output = File.join(dir, 'apply')
      m = backup_manifest(dir, plan)
      capture_io { Cleanup.run(client, before: b, plan: plan, manifest: m, output: output, apply: true) }
      assert_equal plan.map { |p| Cleanup.key(p) }.sort, client.deletes.sort
      assert_equal 3, JSON.parse(File.read(File.join(output, 'completed.json'))).length
      assert_equal [], JSON.parse(File.read(File.join(output, 'pending.json')))
      assert JSON.parse(File.read(File.join(output, 'verified.json')))['notSubmitted']
      assert_equal Cleanup.index(b)['sets'].keys.sort, Cleanup.index(client.snapshot)['sets'].keys.sort
    end
  end

  def test_missing_backup_blocks_before_any_network_request
    b = fixture
    plan = plan_for(b, ['video-0'])
    client = FakeClient.new(b)
    Dir.mktmpdir('legacy-media-tests-') do |dir|
      assert_raises(Cleanup::Error) { Cleanup.run(client, before: b, plan: plan, manifest: nil, output: File.join(dir, 'apply'), apply: true) }
      assert_empty client.calls
    end
  end

  def test_uncertain_delete_is_not_retried_and_pending_record_survives
    b = fixture
    plan = plan_for(b, %w[old-0-a old-0-b video-0])
    client = FakeClient.new(b)
    client.fail_delete_number = 2
    client.mutate_then_fail = true
    Dir.mktmpdir('legacy-media-tests-') do |dir|
      output = File.join(dir, 'apply')
      capture_io do
        assert_raises(Cleanup::Error) { Cleanup.run(client, before: b, plan: plan, manifest: backup_manifest(dir, plan), output: output, apply: true) }
      end
      assert_equal 2, client.deletes.length
      assert_equal 1, JSON.parse(File.read(File.join(output, 'completed.json'))).length
      assert_equal 'old-0-b', JSON.parse(File.read(File.join(output, 'pending.json'))).first['id']
      assert File.file?(File.join(output, 'uncertain.json'))
      refute File.exist?(File.join(output, 'verified.json'))
    end
  end

  def test_version_or_resource_change_stops_before_next_delete
    [:version, :asset, :locale].each do |kind|
      b = fixture
      plan = plan_for(b, %w[old-0-a old-0-b])
      client = FakeClient.new(b)
      client.before_request = lambda do |c, _method, _path|
        next unless c.deletes.length == 1
        case kind
        when :version then c.snapshot.first['version']['attributes']['copyright'] = 'changed'
        when :asset then Cleanup.index(c.snapshot)['assets'][['appScreenshots', 'old-0-b']]['asset']['attributes']['fileName'] = 'changed.png'
        when :locale then c.snapshot.first['localizations'].first['localization']['attributes']['description'] = 'changed'
        end
      end
      Dir.mktmpdir('legacy-media-tests-') do |dir|
        capture_io do
          assert_raises(Cleanup::Error) { Cleanup.run(client, before: b, plan: plan, manifest: backup_manifest(dir, plan), output: File.join(dir, 'apply'), apply: true) }
        end
        assert_equal 1, client.deletes.length
      end
    end
  end

  def test_empty_placeholder_exception_requires_exact_metadata_backup_and_no_uploaded_content
    b = fixture
    asset = b.first['localizations'].first['screenshotSets'].first['screenshots'].first
    asset['attributes']['sourceFileChecksum'] = nil
    asset['attributes']['assetDeliveryState']['state'] = 'AWAITING_UPLOAD'
    asset['attributes']['imageAsset'] = {
      'width' => 0, 'height' => 0,
      'templateUrl' => 'https://is1-ssl.mzstatic.com/image/thumb//{w}x{h}bb.{f}'
    }
    assert Cleanup.empty_upload?(asset)
    plan = plan_for(b, ['old-0-a'])
    Dir.mktmpdir('legacy-media-tests-') do |dir|
      m = backup_manifest(dir, plan)
      record = m['assets'].first
      record['backupKind'] = 'metadata-only-unuploaded'
      path = File.join(m['baseDir'], record['file'])
      File.write(path, JSON.pretty_generate(asset))
      record['sha256'] = Digest::SHA256.file(path).hexdigest
      assert_equal 1, Cleanup.verify_backups!(m, plan, before: b).length
      changed = clone(b)
      changed_asset = changed.first['localizations'].first['screenshotSets'].first['screenshots'].first
      changed_asset['attributes']['imageAsset']['templateUrl'] = 'https://is1-ssl.mzstatic.com/image/thumb/real-asset/{w}x{h}bb.{f}'
      refute Cleanup.empty_upload?(changed_asset)
      assert_raises(Cleanup::Error) { Cleanup.verify_backups!(m, plan, before: changed) }
      client = FakeClient.new(b)
      checks = 0
      client.before_request = lambda do |c, method, requested|
        next unless method == 'GET' && requested == '/v1/appScreenshots/old-0-a'
        checks += 1
        live = Cleanup.index(c.snapshot)['assets'][['appScreenshots', 'old-0-a']]['asset']
        live['attributes']['assetDeliveryState']['state'] = 'COMPLETE'
        live['attributes']['imageAsset'] = { 'width' => 1206, 'height' => 2622, 'templateUrl' => 'https://example.invalid/real' }
      end
      capture_io do
        assert_raises(Cleanup::Error) { Cleanup.run(client, before: b, plan: plan, manifest: m, output: File.join(dir, 'apply'), apply: true) }
      end
      assert_equal 1, checks
      assert_empty client.deletes
    end
  end

  def test_four_workers_keep_exact_scope_and_lossless_journals
    b = fixture
    ids = (0..3).flat_map { |i| ["old-#{i}-a", "old-#{i}-b", "new-#{i}-a", "video-#{i}"] }
    plan = plan_for(b, ids)
    client = FakeClient.new(b)
    Dir.mktmpdir('legacy-media-tests-') do |dir|
      output = File.join(dir, 'parallel')
      capture_io do
        Cleanup.run(client, before: b, plan: plan, manifest: backup_manifest(dir, plan), output: output, apply: true, workers: 4)
      end
      assert_equal plan.map { |r| Cleanup.key(r) }.sort, client.deletes.sort
      completed = JSON.parse(File.read(File.join(output, 'completed.json')))
      assert_equal plan.length, completed.length
      assert_equal completed.length, completed.map { |r| Cleanup.key(r) }.uniq.length
      assert_equal [], JSON.parse(File.read(File.join(output, 'pending.json')))
      assert JSON.parse(File.read(File.join(output, 'verified.json')))['plannedIdsAbsent']
    end
  end

  def test_phone_clear_rejects_subset_and_any_concurrent_61_assets_or_processing
    b = fixture
    subset = plan_for(b, ['old-0-a'])
    Dir.mktmpdir('legacy-media-tests-') do |dir|
      assert_raises(Cleanup::Error) { Cleanup.run(nil, before: b, plan: subset, manifest: nil, output: File.join(dir, 'out'), require_phone_empty: true) }
    end
    after = clone(b)
    after.first['localizations'].first['screenshotSets'][1]['screenshots'] << image('concurrent-61')
    assert_raises(Cleanup::Error) { Cleanup.verify!(b, after, [], require_phone_empty: true) }
    b.first['localizations'].first['screenshotSets'][1]['screenshots'].first['attributes']['assetDeliveryState']['state'] = 'UPLOAD_COMPLETE'
    after = clone(b)
    after.first['localizations'].first['screenshotSets'][1]['screenshots'].first['attributes']['assetDeliveryState']['state'] = 'COMPLETE'
    assert_raises(Cleanup::Error) { Cleanup.verify!(b, after, [], require_phone_empty: true) }
  end

  def test_phone_clear_success_keeps_all_sets_and_ipad_assets
    b = fixture
    ids = Cleanup.index(b)['assets'].select { |_k, ctx| Cleanup.phone?(ctx) }.keys.map(&:last)
    plan = plan_for(b, ids)
    after = remove_from(clone(b), ids)
    assert_empty Cleanup.verify!(b, after, plan, require_phone_empty: true)['new61Assets']
    assert_equal 39, Cleanup.index(after)['assets'].length
    assert Cleanup.index(after)['assets'].values.all? { |ctx| ctx['displayType'] == 'APP_IPAD_PRO_3GEN_129' }
    assert_equal Cleanup.index(b)['sets'].keys.sort, Cleanup.index(after)['sets'].keys.sort
  end
end
