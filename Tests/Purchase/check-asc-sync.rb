require 'minitest/autorun'
require 'tmpdir'
require_relative '../../Tools/AppStoreConnect/sync-purchase-localizations'

class PurchaseASCSyncTest < Minitest::Test
  Sync = PurchaseLocalizationSync
  ROOT = File.expand_path('../..', __dir__)

  class FakeClient
    attr_reader :writes, :localizations

    def initialize
      @writes = []
      @products = Sync::PRODUCTS.each_with_index.map do |(key, (product_id, type)), i|
        { 'type' => type, 'id' => key == 'Monthly' ? '6813533933' : "100#{i}", 'attributes' => { 'productId' => product_id } }
      end
      # Weekly is present in the subscription group but must never be localized or changed.
      @products << { 'type' => 'subscriptions', 'id' => 'weekly', 'attributes' => { 'productId' => 'com.OfflineMusic.www.Weekly' } }
      @localizations = @products.each_with_object({}) do |product, result|
        type = product['type'] == 'subscriptions' ? 'subscriptionLocalizations' : 'inAppPurchaseLocalizations'
        result[product['id']] = [{ 'type' => type, 'id' => "local-#{product['id']}", 'attributes' => { 'locale' => 'en-US', 'name' => 'Old name', 'description' => 'Old description', 'state' => 'APPROVED' } }]
      end
    end

    def request(method, path, body = nil)
      return { 'data' => { 'type' => 'apps', 'id' => Sync::APP_ID, 'attributes' => { 'name' => 'Fixture App', 'bundleId' => 'com.example.fixture', 'sku' => 'FixtureSKU', 'primaryLocale' => 'en-US', 'subscriptionStatusUrl' => 'https://example.invalid/private-callback', 'subscriptionStatusUrlForSandbox' => 'https://example.invalid/private-sandbox-callback' } } } if method == 'GET'
      @writes << [method, path, Marshal.load(Marshal.dump(body))]
      data = body.fetch('data')
      if method == 'PATCH'
        found = @localizations.values.flatten.find { |l| l['id'] == data['id'] }
        found.fetch('attributes').merge!(data.fetch('attributes'))
      else
        parent = data.fetch('relationships').values.first.fetch('data').fetch('id')
        found = { 'type' => data['type'], 'id' => "created-#{@writes.length}", 'attributes' => data.fetch('attributes') }
        @localizations.fetch(parent) << found
      end
      { 'data' => found }
    end

    def list(path)
      case path
      when %r{/apps/\d+/subscriptionGroups} then [{ 'type' => 'subscriptionGroups', 'id' => 'group1' }]
      when %r{/subscriptionGroups/group1/subscriptions} then @products.select { |r| r['type'] == 'subscriptions' }
      when %r{/apps/\d+/inAppPurchasesV2} then @products.select { |r| r['type'] == 'inAppPurchases' }
      when %r{/(subscriptions|inAppPurchases)/([^/]+)/(subscriptionLocalizations|inAppPurchaseLocalizations)}
        raise 'Unexpected Weekly access' if Regexp.last_match(2) == 'weekly'
        Marshal.load(Marshal.dump(@localizations.fetch(Regexp.last_match(2))))
      else raise "Unexpected fixture path #{path}"
      end
    end
  end

  class FakeDraftClient < FakeClient
    attr_reader :versions, :draft_localizations, :legacy_localization_reads, :list_reads

    def initialize(catalog)
      super()
      @versions, @draft_localizations = {}, {}
      @legacy_localization_reads = 0
      @list_reads = []
      @products.each do |product|
        next if product['id'] == 'weekly'
        type = product['type'] == 'subscriptions' ? 'subscriptionVersions' : 'inAppPurchaseVersions'
        @versions[product['id']] = [{ 'type' => type, 'id' => "approved-#{product['id']}", 'attributes' => { 'state' => 'APPROVED', 'version' => 1 } }]
      end
      @localizations['6813533933'] = catalog.metadata.fetch('Monthly').map do |locale, text|
        { 'type' => 'subscriptionLocalizations', 'id' => "monthly-current-#{locale}", 'attributes' => text.merge('locale' => locale) }
      end
      @versions['6813533933'].first['attributes']['state'] = 'PREPARE_FOR_SUBMISSION'
      @versions.each do |parent, versions|
        @draft_localizations[versions.first['id']] = Marshal.load(Marshal.dump(@localizations.fetch(parent)))
      end
    end

    def list(path)
      @list_reads << path
      case path
      when %r{/(subscriptions|inAppPurchases)/([^/]+)/versions}
        return Marshal.load(Marshal.dump(@versions.fetch(Regexp.last_match(2))))
      when %r{/(subscriptionVersions|inAppPurchaseVersions)/([^/]+)/localizations}
        return Marshal.load(Marshal.dump(@draft_localizations.fetch(Regexp.last_match(2))))
      when %r{/(subscriptions|inAppPurchases)/([^/]+)/(subscriptionLocalizations|inAppPurchaseLocalizations)}
        # Deliberately model the actual post-migration bug: parent endpoint can
        # combine the same locale from multiple versions. DraftSync must not use it.
        @legacy_localization_reads += 1
        return @versions.fetch(Regexp.last_match(2)).flat_map { |v| @draft_localizations.fetch(v['id'], []) }
      end
      super
    end

    def request(method, path, body = nil)
      if method == 'GET' && path.match?(%r{/v1/(subscriptionVersions|inAppPurchaseVersions)/})
        return { 'data' => @versions.values.flatten.find { |v| v['id'] == path.split('/').last } }
      end
      if method == 'POST' && path.match?(%r{\A/v1/(subscriptionVersions|inAppPurchaseVersions)\z})
        @writes << [method, path, body]
        data = body.fetch('data')
        parent = data.fetch('relationships').values.first.fetch('data').fetch('id')
        version = { 'type' => data['type'], 'id' => "draft-#{parent}", 'attributes' => { 'state' => 'PREPARE_FOR_SUBMISSION', 'version' => 2 } }
        @versions.fetch(parent) << version
        # Model an API that auto-copies live localizations into the new version.
        @draft_localizations[version['id']] = Marshal.load(Marshal.dump(@localizations.fetch(parent))).each { |l| l['id'] = "draft-#{l['id']}" }
        return { 'data' => version }
      end
      if path.start_with?('/v2/')
        @writes << [method, path, Marshal.load(Marshal.dump(body))]
        data = body.fetch('data')
        if method == 'PATCH'
          found = @draft_localizations.values.flatten.find { |l| l['id'] == data['id'] }
          raise 'Attempt to mutate live metadata' unless found
          found.fetch('attributes').merge!(data.fetch('attributes'))
        else
          version_id = data.dig('relationships', 'version', 'data', 'id')
          found = { 'type' => data['type'], 'id' => "draft-created-#{@writes.length}", 'attributes' => data.fetch('attributes') }
          @draft_localizations.fetch(version_id) << found
        end
        return { 'data' => found }
      end
      super
    end
  end

  def catalog(locales = nil, products: nil)
    Sync::Catalog.new(File.join(ROOT, 'Mobie/Mobie/System/Localizable.xcstrings'), only_locales: locales, products: products)
  end

  def test_exact_locale_mapping_and_metadata_limits
    data = catalog
    assert_equal 4, data.metadata.length
    assert_equal 39, Sync::LOCALES.values.uniq.length
    assert_equal 40, Sync::SUPPORTED_ASC_LOCALES.uniq.length
    assert_equal({ 'en-CA' => 'en' }, Sync::ASC_FALLBACKS)
    assert_equal %w[en-IN es-US zh-HK], data.skipped
    assert_equal 'ar-SA', Sync::LOCALES.fetch('ar')
    assert_equal 'sl-SI', Sync::LOCALES.fetch('sl')
    data.metadata.each_value do |rows|
      assert_equal 40, rows.length
      assert_equal rows.fetch('en-US'), rows.fetch('en-CA')
      rows.each_value do |text|
        assert_operator text['name'].length, :<=, 30
        assert_operator text['description'].length, :<=, 45
      end
    end
    assert_raises(Sync::Error) { catalog(['zh-HK']) }
  end

  def test_dry_run_is_read_only_and_backup_precedes_apply
    Dir.mktmpdir('asc-sync-test-') do |dir|
      client = FakeClient.new
      run = Sync::Sync.new(client, catalog(%w[en-US zh-Hans]), dir)
      operations = run.discover
      assert_equal 8, operations.length
      assert_equal 4, operations.count { |op| op['action'] == 'update' }
      assert_equal 4, operations.count { |op| op['action'] == 'create' }
      assert_empty client.writes
      assert_equal 0o600, File.stat(File.join(dir, 'before.json')).mode & 0o777
      assert_equal 0o600, File.stat(File.join(dir, 'plan.json')).mode & 0o777
      snapshot = JSON.parse(File.read(File.join(dir, 'before.json')))
      assert_equal 4, snapshot.fetch('products').length
      assert_equal %w[bundleId name primaryLocale sku], snapshot.fetch('app').fetch('attributes').keys.sort
      refute_includes JSON.generate(snapshot), 'private-callback'
      refute_includes JSON.generate(snapshot), 'subscriptionStatusUrl'
      capture_io { run.apply }
      assert_equal 8, client.writes.length
      assert_equal 'verified', JSON.parse(File.read(File.join(dir, 'result.json')))['status']
      client.writes.each do |method, path, payload|
        assert_match(%r{\A/v1/(subscriptionLocalizations|inAppPurchaseLocalizations)}, path)
        allowed = method == 'PATCH' ? %w[description name] : %w[description locale name]
        assert_equal allowed, payload.fetch('data').fetch('attributes').keys.sort
        refute_includes JSON.generate(payload), 'Weekly'
      end
      assert_equal 'Old name', client.localizations.fetch('weekly').first.dig('attributes', 'name')
      # Reruns discover the completed values; no unnecessary writes.
      Dir.mktmpdir('asc-sync-rerun-') do |next_dir|
        rerun = Sync::Sync.new(client, catalog(%w[en-US zh-Hans]), next_dir)
        assert rerun.discover.all? { |op| op['action'] == 'unchanged' }
      end
    end
  end

  def test_canadian_english_is_an_explicit_update_or_create
    Dir.mktmpdir('asc-sync-canadian-') do |dir|
      client = FakeClient.new
      client.localizations.fetch('1001') << { 'type' => 'subscriptionLocalizations', 'id' => 'annual-canadian', 'attributes' => { 'locale' => 'en-CA', 'name' => 'Old Canadian name', 'description' => 'Old Canadian description' } }
      run = Sync::Sync.new(client, catalog(['en-CA']), dir)
      operations = run.discover
      assert_equal 4, operations.length
      assert_equal 'update', operations.find { |op| op['product'] == 'Annual' }['action']
      assert_equal 'create', operations.find { |op| op['product'] == 'Monthly' }['action']
      capture_io { run.apply }
      assert_equal 4, client.writes.length
    end
  end

  def test_scope_guard_refuses_price_or_review_writes_before_authentication
    client = Sync::Client.allocate
    assert_raises(Sync::Error) { client.request('POST', '/v1/inAppPurchaseSubmissions', {}) }
    assert_raises(Sync::Error) { client.request('PATCH', '/v2/inAppPurchases/123', {}) }
    assert_raises(Sync::Error) { client.request('GET', 'https://evil.example/steal') }
    assert_raises(Sync::Error) { client.request('GET', 'https://api.appstoreconnect.apple.com:444/v1/apps') }
    assert_raises(Sync::Error) { client.request('GET', 'https://user@api.appstoreconnect.apple.com/v1/apps') }
    assert_raises(Sync::Error) { client.validate_write!('PATCH', { 'data' => { 'type' => 'inAppPurchaseLocalizations', 'id' => 'abc', 'attributes' => { 'name' => 'Name', 'description' => 'Description', 'price' => 10 } } }) }
  end

  def test_es256_jwt_signature_without_external_gem
    Dir.mktmpdir('asc-sync-jwt-') do |dir|
      key = OpenSSL::PKey::EC.new('prime256v1').generate_key
      file = File.join(dir, 'test-only.p8')
      File.open(file, File::CREAT | File::WRONLY, 0o600) { |f| f.write(key.to_pem) }
      client = Sync::Client.new(key_path: file, key_id: 'TESTKEY123', issuer_id: '00000000-0000-0000-0000-000000000000')
      header, payload, signature = client.token.split('.')
      assert_equal 'ES256', JSON.parse(Base64.urlsafe_decode64(header))['alg']
      assert_equal 'appstoreconnect-v1', JSON.parse(Base64.urlsafe_decode64(payload))['aud']
      binary = Base64.urlsafe_decode64(signature)
      assert_equal 64, binary.bytesize
      integers = [binary[0, 32], binary[32, 32]].map { |value| OpenSSL::ASN1::Integer(OpenSSL::BN.new(value, 2)) }
      der = OpenSSL::ASN1::Sequence(integers).to_der
      assert key.dsa_verify_asn1(Digest::SHA256.digest("#{header}.#{payload}"), der)
      File.chmod(0o644, file)
      assert_raises(Sync::Error) { Sync::Client.new(key_path: file, key_id: 'TESTKEY123', issuer_id: '00000000-0000-0000-0000-000000000000') }
    end
  end

  def test_output_must_not_overwrite_prior_backup
    Dir.mktmpdir('asc-sync-existing-') do |dir|
      File.write(File.join(dir, 'previous.json'), '{}')
      assert_raises(Sync::Error) { Sync::Sync.new(FakeClient.new, catalog(['en-US']), dir) }
    end
  end

  def test_version_drafts_skip_current_monthly_preserve_live_metadata_and_never_submit
    data = catalog(%w[en-US zh-Hans])
    client = FakeDraftClient.new(data)
    live_before = Marshal.load(Marshal.dump(client.localizations))
    Dir.mktmpdir('asc-sync-draft-') do |dir|
      sync = Sync::DraftSync.new(client, data, dir)
      plan = sync.discover
      assert_equal 2, plan.count { |op| op['product'] == 'Monthly' && op['action'] == 'unchanged' }
      assert_empty client.writes
      disk_plan = JSON.parse(File.read(File.join(dir, 'plan.json')))
      assert_equal %w[Annual Lifetime FamilyLifetime], disk_plan['versionOperations'].map { |v| v['product'] }
      assert disk_plan['versionOperations'].all? { |v| v['action'] == 'createDraft' }
      capture_io { sync.apply }
      assert_equal live_before, client.localizations, 'Approved/live metadata must remain unchanged in draft mode'
      assert_equal 0, client.legacy_localization_reads
      assert_equal 3, client.writes.count { |method, path, _| method == 'POST' && path.end_with?('Versions') }
      # Auto-copied English is PATCHed; Chinese is POSTed, not duplicated.
      assert_equal 3, client.writes.count { |method, path, _| method == 'PATCH' && path.start_with?('/v2/') }
      assert_equal 3, client.writes.count { |method, path, _| method == 'POST' && path.start_with?('/v2/') }
      assert client.writes.none? { |_, path, _| path.match?(/review|price|[Ii]mages|[Ss]ubmission/) }
      report = JSON.parse(File.read(File.join(dir, 'result.json')))
      assert_equal 'draftsVerifiedNotSubmitted', report['status']
      assert_equal false, report['willSubmitForReview']
      assert report['versions'].all? { |v| v['state'] == 'PREPARE_FOR_SUBMISSION' }
      after = JSON.parse(File.read(File.join(dir, 'after.json')))
      assert_equal 'metadataDraft', after.dig('Monthly', 'target')
      assert_equal 'PREPARE_FOR_SUBMISSION', after.dig('Monthly', 'version', 'attributes', 'state')
      # Rerun reuses the same three drafts without new versions or metadata writes.
      writes_before = client.writes.length
      Dir.mktmpdir('asc-sync-draft-again-') do |next_dir|
        second = Sync::DraftSync.new(client, data, next_dir)
        assert second.discover.all? { |op| op['action'] == 'unchanged' }
        capture_io { second.apply }
        assert_equal writes_before, client.writes.length
        assert_equal 0, client.legacy_localization_reads
      end
    end
  end

  def test_draft_discovery_stops_for_review_or_ambiguous_drafts
    data = catalog(['en-US'])
    client = FakeDraftClient.new(data)
    client.versions.fetch('1001') << { 'type' => 'subscriptionVersions', 'id' => 'in-review', 'attributes' => { 'state' => 'IN_REVIEW' } }
    Dir.mktmpdir('asc-sync-review-') do |dir|
      assert_raises(Sync::Error) { Sync::DraftSync.new(client, data, dir).discover }
      assert_empty client.writes
    end
    client = FakeDraftClient.new(data)
    2.times { |n| client.versions.fetch('1001') << { 'type' => 'subscriptionVersions', 'id' => "duplicate-#{n}", 'attributes' => { 'state' => 'PREPARE_FOR_SUBMISSION' } } }
    Dir.mktmpdir('asc-sync-ambiguous-') do |dir|
      assert_raises(Sync::Error) { Sync::DraftSync.new(client, data, dir).discover }
      assert_empty client.writes
    end
  end

  def test_metadata_version_writes_require_explicit_mode_and_still_cannot_submit
    client = Sync::Client.allocate
    body = { 'data' => { 'type' => 'subscriptionVersions', 'relationships' => { 'subscription' => { 'data' => { 'type' => 'subscriptions', 'id' => 'annual' } } } } }
    assert_raises(Sync::Error) { client.request('POST', '/v1/subscriptionVersions', body) }
    assert_raises(Sync::Error) { client.validate_write!('POST', body) }
    client.instance_variable_set(:@metadata_draft, true)
    assert_nil client.validate_write!('POST', body)
    assert_raises(Sync::Error) { client.request('POST', '/v1/reviewSubmissions', {}) }
    assert_raises(Sync::Error) { client.request('PATCH', '/v1/subscriptionVersions/annual', {}) }
    assert_raises(Sync::Error) { client.request('POST', '/v2/subscriptionImages', {}) }
    invalid = Marshal.load(Marshal.dump(body))
    invalid['data']['attributes'] = { 'submitted' => true }
    assert_raises(Sync::Error) { client.validate_write!('POST', invalid) }
  end

  def test_existing_draft_extra_locale_wins_over_older_live_copy
    data = catalog(['en-US'])
    client = FakeDraftClient.new(data)
    draft = { 'type' => 'subscriptionVersions', 'id' => 'user-draft', 'attributes' => { 'state' => 'PREPARE_FOR_SUBMISSION' } }
    client.versions.fetch('1001') << draft
    client.localizations.fetch('1001') << { 'type' => 'subscriptionLocalizations', 'id' => 'live-extra', 'attributes' => { 'locale' => 'fr-CA', 'name' => 'Ancien nom', 'description' => 'Ancien texte' } }
    client.draft_localizations['user-draft'] = [{ 'type' => 'subscriptionLocalizations', 'id' => 'draft-extra', 'attributes' => { 'locale' => 'fr-CA', 'name' => 'Nouveau nom', 'description' => 'Nouveau texte' } }]
    Dir.mktmpdir('asc-sync-draft-extra-') do |dir|
      run = Sync::DraftSync.new(client, data, dir)
      operation = run.discover.find { |op| op['product'] == 'Annual' && op['locale'] == 'fr-CA' }
      assert_equal 'unchanged', operation['action']
      assert_equal 'Nouveau nom', operation.dig('after', 'name')
      capture_io { run.apply }
      assert client.writes.none? { |_, _, body| body.dig('data', 'id') == 'draft-extra' }
    end
  end

  def test_version_only_discovery_selects_highest_approved_and_reuses_timeout_created_draft
    data = catalog(['en-US'])
    client = FakeDraftClient.new(data)
    newest = { 'type' => 'subscriptionVersions', 'id' => 'annual-approved-v3', 'attributes' => { 'state' => 'APPROVED', 'version' => 3 } }
    client.versions.fetch('1001').unshift(newest)
    client.draft_localizations[newest['id']] = [{ 'type' => 'subscriptionLocalizations', 'id' => 'newest-approved-en', 'attributes' => { 'locale' => 'en-US', 'name' => 'Newest live title', 'description' => 'Newest live description' } }]
    recovered = { 'type' => 'inAppPurchaseVersions', 'id' => 'created-before-timeout', 'attributes' => { 'state' => 'PREPARE_FOR_SUBMISSION', 'version' => 2 } }
    client.versions.fetch('1002') << recovered
    client.draft_localizations[recovered['id']] = []
    Dir.mktmpdir('asc-sync-version-reconcile-') do |dir|
      run = Sync::DraftSync.new(client, data, dir)
      run.discover
      snapshot = JSON.parse(File.read(File.join(dir, 'before.json')))
      assert_equal 'annual-approved-v3', snapshot.dig('products', 'Annual', 'baselineVersion', 'id')
      assert_equal 'highestNumericApprovedVersion', snapshot.dig('products', 'Annual', 'baselineSelection')
      assert_equal 'Newest live title', snapshot.dig('products', 'Annual', 'localizations', 0, 'attributes', 'name')
      assert_equal 'onlyPrepareForSubmissionVersion', snapshot.dig('products', 'Monthly', 'baselineSelection')
      plan = JSON.parse(File.read(File.join(dir, 'plan.json')))
      recovered_operation = plan['versionOperations'].find { |op| op['product'] == 'Lifetime' }
      assert_equal 'reuseDraft', recovered_operation['action']
      assert_equal 'created-before-timeout', recovered_operation['versionId']
      assert_empty client.writes
      assert_equal 0, client.legacy_localization_reads
    end
  end

  def test_product_scope_is_strict_and_draft_flow_only_touches_selected_product
    assert_raises(Sync::Error) { catalog(nil, products: ['Weekly']) }
    assert_raises(Sync::Error) { catalog(nil, products: []) }
    assert_raises(Sync::Error) { catalog(nil, products: %w[Lifetime Lifetime]) }
    assert_raises(Sync::Error) { catalog(nil, products: ['lifetime198']) }
    data = catalog(%w[en-US zh-Hans], products: ['Lifetime'])
    assert_equal ['Lifetime'], data.metadata.keys
    client = FakeDraftClient.new(catalog(%w[en-US zh-Hans]))
    Dir.mktmpdir('asc-sync-product-scope-') do |dir|
      run = Sync::DraftSync.new(client, data, dir)
      assert_equal ['Lifetime'], run.discover.map { |op| op['product'] }.uniq
      assert_equal ['Lifetime'], run.snapshot.fetch('products').keys
      capture_io { run.apply }
      assert_equal ['Lifetime'], JSON.parse(File.read(File.join(dir, 'after.json'))).keys
      assert client.list_reads.none? { |path| path.include?('subscriptionGroups') || path.include?('/subscriptions/') }
      assert client.list_reads.none? { |path| path.include?('/1003/') || path.include?('approved-1003') || path.include?('draft-1003') }
      version_posts = client.writes.select { |method, path, _| method == 'POST' && path.end_with?('Versions') }
      assert_equal 1, version_posts.length
      assert_equal '1002', version_posts.first.last.dig('data', 'relationships', 'inAppPurchase', 'data', 'id')
      assert client.writes.none? { |_, _, body| JSON.generate(body).include?('1003') }
    end
  end

  def test_product_scope_also_applies_to_legacy_mode
    client = FakeClient.new
    Dir.mktmpdir('asc-sync-legacy-product-') do |dir|
      run = Sync::Sync.new(client, catalog(['en-US'], products: ['FamilyLifetime']), dir)
      assert_equal ['FamilyLifetime'], run.discover.map { |op| op['product'] }.uniq
      capture_io { run.apply }
      assert_equal 1, client.writes.length
      assert_equal '/v1/inAppPurchaseLocalizations/local-1003', client.writes.first[1]
      assert_equal ['FamilyLifetime'], JSON.parse(File.read(File.join(dir, 'after.json'))).keys
    end
  end
end
