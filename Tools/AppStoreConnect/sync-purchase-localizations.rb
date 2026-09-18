#!/usr/bin/env ruby
# frozen_string_literal: true

# Only localized name/description for the four explicitly allowlisted products.
# No third-party gems, no prices, no product settings, no review submission.
require 'base64'
require 'digest'
require 'json'
require 'net/http'
require 'openssl'
require 'optparse'
require 'time'
require 'uri'

module PurchaseLocalizationSync
  APP_ID = '6544783918'
  PRODUCTS = {
    'Monthly' => ['com.OfflineMusic.www.Monthly', 'subscriptions'],
    'Annual' => ['com.OfflineMusic.www.Annual', 'subscriptions'],
    'Lifetime' => ['com.OfflineMusic.www.lifetime198', 'inAppPurchases'],
    'FamilyLifetime' => ['com.OfflineMusic.www.lifetime298', 'inAppPurchases']
  }.freeze
  # Apple's official locale shortcode table, checked 2026-09-18:
  # https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes
  # No direct ASC locale exists for en-IN, es-US, or zh-HK. Keep these app-only.
  # Latin American Spanish maps explicitly to Apple's Spanish (Mexico) slot.
  LOCALES = {
    'ar' => 'ar-SA', 'ca' => 'ca', 'cs' => 'cs', 'da' => 'da', 'de' => 'de-DE',
    'el' => 'el', 'en' => 'en-US', 'en-AU' => 'en-AU', 'en-GB' => 'en-GB',
    'es' => 'es-ES', 'es-419' => 'es-MX', 'fi' => 'fi', 'fr' => 'fr-FR',
    'fr-CA' => 'fr-CA', 'he' => 'he', 'hi' => 'hi', 'hr' => 'hr', 'hu' => 'hu',
    'id' => 'id', 'it' => 'it', 'ja' => 'ja', 'ko' => 'ko', 'ms' => 'ms',
    'nb' => 'no', 'nl' => 'nl-NL', 'pl' => 'pl', 'pt-BR' => 'pt-BR',
    'pt-PT' => 'pt-PT', 'ro' => 'ro', 'ru' => 'ru', 'sk' => 'sk', 'sl' => 'sl-SI',
    'sv' => 'sv', 'th' => 'th', 'tr' => 'tr', 'uk' => 'uk', 'vi' => 'vi',
    'zh-Hans' => 'zh-Hans', 'zh-Hant' => 'zh-Hant'
  }.freeze
  # ASC already contains Canadian English for the existing products. Its official
  # en-CA slot intentionally reuses the app's reviewed neutral English copy;
  # do not leave older descriptions behind, or silently borrow another locale.
  ASC_FALLBACKS = { 'en-CA' => 'en' }.freeze
  SUPPORTED_ASC_LOCALES = (LOCALES.values + ASC_FALLBACKS.keys).freeze
  UNSUPPORTED_LOCALES = %w[en-IN es-US zh-HK].freeze
  LOCALIZATION_TYPES = %w[subscriptionLocalizations inAppPurchaseLocalizations].freeze
  VERSION_TYPES = %w[subscriptionVersions inAppPurchaseVersions].freeze

  class Error < StandardError; end

  class Catalog
    attr_reader :metadata, :skipped

    def initialize(path, only_locales: nil, products: nil)
      strings = JSON.parse(File.read(path)).fetch('strings')
      @metadata = {}
      selected_products = products || PRODUCTS.keys
      unless !selected_products.empty? && selected_products.uniq == selected_products && (selected_products - PRODUCTS.keys).empty?
        raise Error, 'Products must be a nonempty, unique subset of Monthly,Annual,Lifetime,FamilyLifetime.'
      end
      selected = only_locales || SUPPORTED_ASC_LOCALES
      unknown = selected - SUPPORTED_ASC_LOCALES
      raise Error, "Unsupported ASC locale selection: #{unknown.join(', ')}" unless unknown.empty?
      @skipped = UNSUPPORTED_LOCALES
      PRODUCTS.each_key do |product|
        next unless selected_products.include?(product)
        @metadata[product] = {}
        locale_pairs = LOCALES.to_a + ASC_FALLBACKS.map { |target, source| [source, target] }
        locale_pairs.each do |source, target|
          next unless selected.include?(target)
          values = %w[Title Description].map do |field|
            unit = strings.fetch("Purchase.#{product}.#{field}").fetch('localizations').fetch(source).fetch('stringUnit')
            value = unit.fetch('value')
            limit = field == 'Title' ? 30 : 45
            unless unit['state'] == 'translated' && value.is_a?(String) && value.length.between?(2, limit) && value == value.strip
              raise Error, "Invalid #{product}/#{source}/#{field}: must be translated, 2–#{limit} characters"
            end
            value
          end
          @metadata[product][target] = { 'name' => values[0], 'description' => values[1] }
        end
      end
    end
  end

  class Client
    ORIGIN = 'https://api.appstoreconnect.apple.com'

    def initialize(key_path:, key_id:, issuer_id:, metadata_draft: false)
      raise Error, 'Private key must be a regular file, accessible only to its owner (chmod 600).' unless File.file?(key_path) && (File.stat(key_path).mode & 0o077).zero?
      raise Error, 'Unexpected private key size.' if File.size(key_path) > 16_384
      @key = OpenSSL::PKey.read(File.binread(key_path))
      unless @key.is_a?(OpenSSL::PKey::EC) && @key.private? && @key.group.curve_name == 'prime256v1'
        raise Error, 'An App Store Connect P-256 private key is required.'
      end
      raise Error, 'Invalid Key ID.' unless key_id.match?(/\A[A-Z0-9]{10}\z/)
      raise Error, 'Invalid Issuer ID.' unless issuer_id.match?(/\A[0-9a-fA-F-]{36}\z/)
      @key_id, @issuer_id = key_id, issuer_id
      @metadata_draft = metadata_draft
    end

    def token
      now = Time.now.to_i
      if !@jwt || now >= @expires_at - 60
        @expires_at = now + 600
        encoded = [
          { alg: 'ES256', kid: @key_id, typ: 'JWT' },
          { iss: @issuer_id, iat: now - 5, exp: @expires_at, aud: 'appstoreconnect-v1' }
        ].map { |part| Base64.urlsafe_encode64(JSON.generate(part)).delete('=') }.join('.')
        der = @key.dsa_sign_asn1(Digest::SHA256.digest(encoded))
        raw = OpenSSL::ASN1.decode(der).value.map { |number| number.value.to_s(2).rjust(32, "\0") }.join
        @jwt = "#{encoded}.#{Base64.urlsafe_encode64(raw).delete('=')}"
      end
      @jwt
    end

    def request(method, path, body = nil)
      uri = URI(path.start_with?('https://') ? path : "#{ORIGIN}#{path}")
      unless uri.scheme == 'https' && uri.host == 'api.appstoreconnect.apple.com' && uri.port == 443 && !uri.userinfo && !uri.fragment
        raise Error, 'Refusing to send credentials outside the App Store Connect API.'
      end
      if method != 'GET'
        localization_write = %w[POST PATCH].include?(method) && uri.path.match?(%r{\A/v[12]/(subscriptionLocalizations|inAppPurchaseLocalizations)(/[A-Za-z0-9-]+)?\z})
        version_creation = @metadata_draft && method == 'POST' && uri.path.match?(%r{\A/v1/(subscriptionVersions|inAppPurchaseVersions)\z})
        unless (localization_write || version_creation) && !uri.query && (!uri.path.start_with?('/v2/') || @metadata_draft)
          raise Error, 'Write endpoint is not allowlisted.'
        end
        validate_write!(method, body, api_version: uri.path.split('/')[1])
      end
      attempts = 0
      begin
        attempts += 1
        klass = { 'GET' => Net::HTTP::Get, 'POST' => Net::HTTP::Post, 'PATCH' => Net::HTTP::Patch }.fetch(method)
        req = klass.new(uri)
        req['Authorization'] = "Bearer #{token}"
        req['Content-Type'] = 'application/json'
        req.body = JSON.generate(body) if body
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = 20
        # Creating a version can clone dozens of localizations on Apple's side.
        # Still never retry an ambiguous POST automatically if it times out.
        http.read_timeout = version_creation ? 60 : 30
        http.max_retries = 0 if http.respond_to?(:max_retries=)
        response = http.request(req)
        status = response.code.to_i
        if (status == 429 || (method == 'GET' && status.between?(500, 599))) && attempts < 4
          # A 429 explicitly rejects the request; do not retry ambiguous POST/PATCH 5xx responses.
          delay = response['Retry-After'].to_i
          sleep [[delay.positive? ? delay : 2**attempts, 10].min, 1].max
          raise RetryRequest
        end
        parsed = response.body.to_s.empty? ? {} : JSON.parse(response.body)
        unless status.between?(200, 299)
          details = Array(parsed['errors']).map { |e| [e['code'], e['title'], e['detail']].compact.join(': ') }.join('; ')
          details = details.gsub(@jwt.to_s, '[REDACTED]') unless @jwt.to_s.empty?
          raise Error, "HTTP #{status} #{method} #{uri.path}: #{details[0, 1500]}"
        end
        parsed
      rescue RetryRequest
        retry
      rescue JSON::ParserError
        raise Error, "Non-JSON response for #{method} #{uri.path}; no response body logged."
      rescue IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => e
        # Never retry an ambiguous mutation automatically; a later dry run reconciles actual state.
        raise Error, "Transport failure (#{e.class}) for #{method} #{uri.path}; rerun dry-run to reconcile."
      end
    end

    def validate_write!(method, body, api_version: 'v1')
      data = body.fetch('data')
      if VERSION_TYPES.include?(data['type'])
        expected_relation, expected_type = data['type'] == 'subscriptionVersions' ? %w[subscription subscriptions] : %w[inAppPurchase inAppPurchases]
        unless @metadata_draft && method == 'POST' && api_version == 'v1' && body.keys == ['data'] && data.keys.sort == %w[relationships type] && data.fetch('relationships').keys == [expected_relation] && data.dig('relationships', expected_relation, 'data', 'type') == expected_type
          raise Error, 'Only explicit creation of an unsubmitted metadata draft is allowed.'
        end
        return
      end
      raise Error, 'Unexpected write payload.' unless (body.keys - ['data']).empty? && LOCALIZATION_TYPES.include?(data['type'])
      allowed_data = method == 'POST' ? %w[type attributes relationships] : %w[type id attributes]
      raise Error, 'Unexpected resource write fields.' unless (data.keys - allowed_data).empty?
      allowed_attributes = method == 'POST' ? %w[name description locale] : %w[name description]
      raise Error, 'Only localized names/descriptions may be changed.' unless data.fetch('attributes').keys.sort == allowed_attributes.sort
      return unless method == 'POST'
      relationship = api_version == 'v2' ? 'version' : data['type'] == 'subscriptionLocalizations' ? 'subscription' : 'inAppPurchaseV2'
      raise Error, 'Unexpected localization relationship.' unless data.fetch('relationships').keys == [relationship]
      if api_version == 'v2'
        version_type = data['type'] == 'subscriptionLocalizations' ? 'subscriptionVersions' : 'inAppPurchaseVersions'
        raise Error, 'Unexpected metadata version relationship type.' unless @metadata_draft && data.dig('relationships', 'version', 'data', 'type') == version_type
      end
    end

    def list(path)
      records, seen = [], []
      while path
        raise Error, 'Repeated pagination link.' if seen.include?(path)
        seen << path
        page = request('GET', path)
        raise Error, 'Expected a resource list.' unless page['data'].is_a?(Array)
        records.concat(page['data'])
        path = page.dig('links', 'next')
      end
      records
    end

    class RetryRequest < StandardError; end
  end

  class Sync
    attr_reader :snapshot, :plan

    def initialize(client, catalog, output_dir)
      @client, @catalog, @output_dir = client, catalog, File.expand_path(output_dir)
      if File.exist?(@output_dir)
        unless File.directory?(@output_dir) && !File.symlink?(@output_dir) && (File.stat(@output_dir).mode & 0o077).zero? && Dir.children(@output_dir).empty?
          raise Error, 'Output directory must be new, or empty and owner-only (chmod 700).'
        end
      else
        Dir.mkdir(@output_dir, 0o700)
      end
    end

    def write_json(name, object)
      File.open(File.join(@output_dir, name), File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |f| f.write(JSON.pretty_generate(object) + "\n") }
    end

    def discover_resources
      app = @client.request('GET', "/v1/apps/#{APP_ID}").fetch('data')
      raise Error, 'App ID mismatch.' unless app['id'] == APP_ID && app['type'] == 'apps'
      needs_subscriptions = @catalog.metadata.keys.any? { |key| PRODUCTS.fetch(key)[1] == 'subscriptions' }
      needs_purchases = @catalog.metadata.keys.any? { |key| PRODUCTS.fetch(key)[1] == 'inAppPurchases' }
      groups = needs_subscriptions ? @client.list("/v1/apps/#{APP_ID}/subscriptionGroups?limit=200") : []
      subscriptions = groups.flat_map { |group| @client.list("/v1/subscriptionGroups/#{group.fetch('id')}/subscriptions?limit=200") }
      purchases = needs_purchases ? @client.list("/v1/apps/#{APP_ID}/inAppPurchasesV2?limit=200") : []
      # App resources can include unrelated service callback URLs. Do not retain
      # them in a metadata backup; these identifiers are enough to verify scope.
      app_summary = {
        'id' => app['id'], 'type' => app['type'],
        'attributes' => app.fetch('attributes', {}).slice('name', 'bundleId', 'sku', 'primaryLocale')
      }
      @snapshot = { 'app' => app_summary, 'capturedAt' => Time.now.utc.iso8601, 'products' => {} }
      @catalog.metadata.each_key do |key|
        product_id, type = PRODUCTS.fetch(key)
        all = type == 'subscriptions' ? subscriptions : purchases
        matches = all.select { |resource| resource.dig('attributes', 'productId') == product_id }
        raise Error, "Expected one exact #{product_id}, got #{matches.length}." unless matches.length == 1
        resource = matches.first
        raise Error, "Unexpected resource type for #{product_id}." unless resource['type'] == type
        if key == 'Monthly' && resource['id'] != '6813533933'
          raise Error, 'Monthly ID differs from the product verified in ASC; verify the app before proceeding.'
        end
        @snapshot['products'][key] = { 'resource' => resource }
      end
    end

    def discover
      discover_resources
      @snapshot.fetch('products').each do |key, info|
        resource = info.fetch('resource')
        product_id = PRODUCTS.fetch(key)[0]
        locals = @client.list(localizations_path(resource))
        expected_type = localization_type(resource)
        raise Error, "Unexpected localization type for #{product_id}." unless locals.all? { |l| l['type'] == expected_type }
        locales = locals.map { |l| l.dig('attributes', 'locale') }
        raise Error, "Duplicate localizations for #{product_id}." unless locales.uniq == locales
        info['localizations'] = locals
      end
      # Entire four-product snapshot is durable before any mutation is even planned.
      write_json('before.json', @snapshot)
      @plan = []
      @snapshot['products'].each do |key, info|
        by_locale = info['localizations'].each_with_object({}) { |l, index| index[l.dig('attributes', 'locale')] = l }
        @catalog.metadata.fetch(key).each do |locale, text|
          old = by_locale[locale]
          unchanged = old && text.all? { |field, value| old.dig('attributes', field) == value }
          @plan << { 'product' => key, 'productId' => PRODUCTS.fetch(key)[0], 'resourceId' => info['resource']['id'], 'resourceType' => info['resource']['type'],
                     'locale' => locale, 'action' => unchanged ? 'unchanged' : old ? 'update' : 'create', 'localizationId' => old && old['id'],
                     'before' => old && old['attributes'].slice('name', 'description'), 'after' => text }
        end
      end
      write_json('plan.json', { 'appId' => APP_ID, 'unsupportedAppLocales' => @catalog.skipped, 'explicitASCFallbacks' => ASC_FALLBACKS, 'operations' => @plan })
      @plan
    end

    def apply
      raise Error, 'discover must run first.' unless @plan && File.file?(File.join(@output_dir, 'before.json'))
      report = { 'completed' => [], 'status' => 'inProgress' }
      begin
        @plan.each do |operation|
          next if operation['action'] == 'unchanged'
          type = operation['resourceType'] == 'subscriptions' ? 'subscriptionLocalizations' : 'inAppPurchaseLocalizations'
          attributes = operation['after'].dup
          data = { 'type' => type, 'attributes' => attributes }
          if operation['action'] == 'update'
            data['id'] = operation.fetch('localizationId')
            response = @client.request('PATCH', "/v1/#{type}/#{data['id']}", { 'data' => data })
          else
            attributes['locale'] = operation['locale']
            relation = type == 'subscriptionLocalizations' ? 'subscription' : 'inAppPurchaseV2'
            data['relationships'] = { relation => { 'data' => { 'type' => operation['resourceType'], 'id' => operation['resourceId'] } } }
            response = @client.request('POST', "/v1/#{type}", { 'data' => data })
          end
          report['completed'] << { 'product' => operation['product'], 'locale' => operation['locale'], 'action' => operation['action'], 'id' => response.dig('data', 'id') }
          write_json('result.json', report)
          puts "#{operation['action'].upcase} #{operation['product']} #{operation['locale']}"
        end
        after = {}
        @snapshot.fetch('products').each do |key, info|
          localizations = @client.list(localizations_path(info['resource']))
          after[key] = localizations
          @catalog.metadata.fetch(key).each do |locale, expected|
            found = localizations.select { |l| l.dig('attributes', 'locale') == locale }
            unless found.length == 1 && expected.all? { |field, value| found.first.dig('attributes', field) == value }
              raise Error, "Read-back verification failed: #{key}/#{locale}."
            end
          end
        end
        write_json('after.json', after)
        report['status'] = 'verified'
      rescue StandardError => e
        report['status'] = 'stopped'
        report['error'] = e.message
        raise
      ensure
        write_json('result.json', report)
      end
      report
    end

    def localization_type(resource)
      resource['type'] == 'subscriptions' ? 'subscriptionLocalizations' : 'inAppPurchaseLocalizations'
    end

    def localizations_path(resource)
      if resource['type'] == 'subscriptions'
        "/v1/subscriptions/#{resource['id']}/subscriptionLocalizations?limit=200"
      else
        "/v2/inAppPurchases/#{resource['id']}/inAppPurchaseLocalizations?limit=200"
      end
    end
  end

  # Explicit version-based mode for metadata that Apple has made read-only once
  # ACTIVE. Never writes to an approved version and never creates a submission.
  class DraftSync < Sync
    IN_REVIEW = %w[READY_FOR_REVIEW WAITING_FOR_REVIEW IN_REVIEW].freeze

    def discover
      # Never read parent-level legacy localizations here: after migration Apple
      # may return the same locale from approved and draft versions together.
      discover_resources
      @plan, @drafts, @unchanged_versions = [], {}, {}
      @snapshot['metadataDrafts'] = {}
      @snapshot.fetch('products').each do |key, info|
        resource = info.fetch('resource')
        versions = @client.list(versions_path(resource))
        expected_type = version_type(resource)
        raise Error, "Unexpected metadata version type for #{key}." unless versions.all? { |v| v['type'] == expected_type }
        preparing = versions.select { |v| v.dig('attributes', 'state') == 'PREPARE_FOR_SUBMISSION' }
        raise Error, "Multiple editable drafts for #{key}; choose manually before syncing." if preparing.length > 1
        raise Error, "#{key} already has metadata in a review workflow; not modifying it." if versions.any? { |v| IN_REVIEW.include?(v.dig('attributes', 'state')) }
        draft = preparing.first
        approved = select_approved_version(key, versions)
        baseline = approved || draft
        raise Error, "No approved or editable metadata version for #{key}; inspect manually." unless baseline
        baseline_locals = @client.list(version_localizations_path(baseline))
        validate_localizations!(resource, baseline_locals)
        info['baselineVersion'] = baseline
        info['baselineSelection'] = approved ? 'highestNumericApprovedVersion' : 'onlyPrepareForSubmissionVersion'
        info['localizations'] = baseline_locals
        localizations = draft == baseline ? baseline_locals : draft ? @client.list(version_localizations_path(draft)) : []
        validate_localizations!(resource, localizations)
        @snapshot['metadataDrafts'][key] = { 'versions' => versions, 'selectedApproved' => approved, 'selectedDraft' => draft, 'localizations' => localizations }
        target = draft || approved
        target_locals = draft ? localizations : baseline_locals
        current = draft_operations(key, resource, target, target_locals, @catalog.metadata.fetch(key))
        if current.all? { |op| op['action'] == 'unchanged' }
          # Monthly's initial PREPARE version and an already-filled Annual draft
          # are both reusable, but neither should be represented as published.
          target_kind = draft ? 'metadataDraft' : 'approvedVersion'
          @unchanged_versions[key] = { 'version' => target, 'target' => target_kind }
          @plan.concat(current.map { |op| op.merge('target' => target_kind) })
          next
        end
        # Preserve any existing extra locales verbatim in a newly created draft.
        # They may not be in this app's catalog, and are never deleted.
        desired = info.fetch('localizations').each_with_object({}) do |l, values|
          values[l.dig('attributes', 'locale')] = l.fetch('attributes').slice('name', 'description')
        end
        # Extra languages in an existing draft may already contain deliberate
        # unpublished edits. Those take precedence over the older live copy.
        localizations.each do |localization|
          desired[localization.dig('attributes', 'locale')] = localization.fetch('attributes').slice('name', 'description')
        end
        desired.merge!(@catalog.metadata.fetch(key))
        @drafts[key] = { 'resource' => resource, 'version' => draft, 'desired' => desired }
        @plan.concat(draft_operations(key, resource, draft, localizations, desired))
      end
      write_json('before.json', @snapshot)
      write_json('plan.json', { 'appId' => APP_ID, 'mode' => 'metadata-draft', 'willSubmitForReview' => false,
                               'unsupportedAppLocales' => @catalog.skipped, 'explicitASCFallbacks' => ASC_FALLBACKS,
                               'versionOperations' => @drafts.map { |key, context| { 'product' => key, 'action' => context['version'] ? 'reuseDraft' : 'createDraft', 'versionId' => context.dig('version', 'id') } },
                               'alreadySynchronizedVersions' => @unchanged_versions,
                               'operations' => @plan })
      @plan
    end

    def apply
      raise Error, 'discover must run first.' unless @drafts && File.file?(File.join(@output_dir, 'before.json'))
      report = { 'mode' => 'metadata-draft', 'status' => 'inProgress', 'versions' => [], 'completed' => [], 'willSubmitForReview' => false }
      after = {}
      begin
        @drafts.each do |key, context|
          resource = context.fetch('resource')
          draft = context['version']
          if draft
            draft = @client.request('GET', "/v1/#{draft['type']}/#{draft['id']}").fetch('data')
          else
            type = version_type(resource)
            relation = resource['type'] == 'subscriptions' ? 'subscription' : 'inAppPurchase'
            body = { 'data' => { 'type' => type, 'relationships' => { relation => { 'data' => { 'type' => resource['type'], 'id' => resource['id'] } } } } }
            draft = @client.request('POST', "/v1/#{type}", body).fetch('data')
          end
          report['versions'] << { 'product' => key, 'type' => draft['type'], 'id' => draft['id'], 'state' => draft.dig('attributes', 'state') }
          write_json('result.json', report)
          validate_draft!(key, resource, draft)
          # Apple may copy existing metadata. Re-read; do not assume an empty draft.
          initial = @client.list(version_localizations_path(draft))
          validate_localizations!(resource, initial)
          write_json("draft-before-#{key}.json", { 'version' => draft, 'localizations' => initial })
          operations = draft_operations(key, resource, draft, initial, context.fetch('desired'))
          write_json("draft-plan-#{key}.json", operations)
          operations.each do |operation|
            next if operation['action'] == 'unchanged'
            type = localization_type(resource)
            data = { 'type' => type, 'attributes' => operation['after'].dup }
            if operation['action'] == 'update'
              data['id'] = operation.fetch('localizationId')
              response = @client.request('PATCH', "/v2/#{type}/#{data['id']}", { 'data' => data })
            else
              data['attributes']['locale'] = operation['locale']
              data['relationships'] = { 'version' => { 'data' => { 'type' => draft['type'], 'id' => draft['id'] } } }
              response = @client.request('POST', "/v2/#{type}", { 'data' => data })
            end
            report['completed'] << { 'product' => key, 'locale' => operation['locale'], 'action' => operation['action'], 'id' => response.dig('data', 'id'), 'versionId' => draft['id'] }
            write_json('result.json', report)
            puts "DRAFT_#{operation['action'].upcase} #{key} #{operation['locale']}"
          end
          verified = @client.list(version_localizations_path(draft))
          context.fetch('desired').each do |locale, expected|
            matches = verified.select { |l| l.dig('attributes', 'locale') == locale }
            unless matches.length == 1 && expected.all? { |field, value| matches.first.dig('attributes', field) == value }
              raise Error, "Draft read-back verification failed: #{key}/#{locale}."
            end
          end
          final_version = @client.request('GET', "/v1/#{draft['type']}/#{draft['id']}").fetch('data')
          validate_draft!(key, resource, final_version)
          after[key] = { 'version' => final_version, 'localizations' => verified }
        end
        # Verify skipped metadata through its exact version, never the mixed
        # parent endpoint. Preserve its state so draft != published is explicit.
        @unchanged_versions.each do |key, context|
          version = context.fetch('version')
          fresh_version = @client.request('GET', "/v1/#{version['type']}/#{version['id']}").fetch('data')
          unless fresh_version['id'] == version['id'] && fresh_version['type'] == version['type'] && fresh_version.dig('attributes', 'state') == version.dig('attributes', 'state')
            raise Error, "Skipped metadata version changed during sync: #{key}."
          end
          locals = @client.list(version_localizations_path(fresh_version))
          @catalog.metadata.fetch(key).each do |locale, expected|
            matches = locals.select { |l| l.dig('attributes', 'locale') == locale }
            raise Error, "Current-product verification failed: #{key}/#{locale}." unless matches.length == 1 && expected.all? { |field, value| matches.first.dig('attributes', field) == value }
          end
          after[key] = { 'target' => context['target'], 'version' => fresh_version, 'localizations' => locals }
        end
        write_json('after.json', after)
        report['status'] = 'draftsVerifiedNotSubmitted'
      rescue StandardError => e
        report['status'] = 'stopped'
        report['error'] = e.message
        raise
      ensure
        write_json('result.json', report)
      end
      report
    end

    def validate_draft!(key, resource, draft)
      unless draft['type'] == version_type(resource) && draft.dig('attributes', 'state') == 'PREPARE_FOR_SUBMISSION'
        raise Error, "#{key} metadata version is not an editable PREPARE_FOR_SUBMISSION draft."
      end
    end

    def select_approved_version(key, versions)
      approved = versions.select { |version| %w[APPROVED ACCEPTED].include?(version.dig('attributes', 'state')) }
      return nil if approved.empty?
      numbered = approved.map do |version|
        number = version.dig('attributes', 'version').to_s
        raise Error, "Invalid approved metadata version number for #{key}." unless number.match?(/\A\d+\z/)
        [number.to_i, version]
      end
      highest = numbered.map(&:first).max
      matches = numbered.select { |number, _| number == highest }
      raise Error, "Ambiguous highest approved version for #{key}." unless matches.length == 1
      matches.first.last
    end

    def validate_localizations!(resource, localizations)
      locales = localizations.map { |l| l.dig('attributes', 'locale') }
      unless locales.uniq == locales && localizations.all? { |l| l['type'] == localization_type(resource) }
        raise Error, 'Invalid or duplicate metadata draft localizations.'
      end
    end

    def draft_operations(key, resource, draft, localizations, desired)
      indexed = localizations.each_with_object({}) { |l, by_locale| by_locale[l.dig('attributes', 'locale')] = l }
      desired.map do |locale, text|
        old = indexed[locale]
        unchanged = old && text.all? { |field, value| old.dig('attributes', field) == value }
        { 'product' => key, 'productId' => PRODUCTS.fetch(key)[0], 'resourceId' => resource['id'], 'resourceType' => resource['type'],
          'target' => 'metadataDraft', 'versionId' => draft && draft['id'], 'locale' => locale,
          'action' => unchanged ? 'unchanged' : old ? 'update' : 'create', 'localizationId' => old && old['id'],
          'before' => old && old['attributes'].slice('name', 'description'), 'after' => text }
      end
    end

    def version_type(resource)
      resource['type'] == 'subscriptions' ? 'subscriptionVersions' : 'inAppPurchaseVersions'
    end

    def versions_path(resource)
      api_version = resource['type'] == 'subscriptions' ? 'v1' : 'v2'
      "/#{api_version}/#{resource['type']}/#{resource['id']}/versions?limit=200"
    end

    def version_localizations_path(version)
      "/v1/#{version['type']}/#{version['id']}/localizations?limit=200"
    end
  end

  def self.main(argv)
    options = { catalog: File.expand_path('../../Mobie/Mobie/System/Localizable.xcstrings', __dir__) }
    parser = OptionParser.new do |o|
      o.banner = 'Usage: ruby Tools/AppStoreConnect/sync-purchase-localizations.rb --key-file PATH --key-id ID --issuer-id UUID --output PRIVATE_DIR [--apply]'
      o.on('--key-file PATH') { |v| options[:key_path] = v }
      o.on('--key-id ID') { |v| options[:key_id] = v }
      o.on('--issuer-id UUID') { |v| options[:issuer_id] = v }
      o.on('--output PATH') { |v| options[:output] = v }
      o.on('--catalog PATH') { |v| options[:catalog] = v }
      o.on('--locales LIST', 'Optional comma-separated ASC locales; default 40 including en-CA English fallback') { |v| options[:locales] = v.split(',') }
      o.on('--products LIST', 'Optional exact subset: Monthly,Annual,Lifetime,FamilyLifetime; default all four') { |v| options[:products] = v.split(',') }
      o.on('--apply', 'Explicitly authorize only the planned localization POST/PATCH requests') { options[:apply] = true }
      o.on('--metadata-draft', 'Use or create unsubmitted editable metadata versions for ACTIVE products; dry-run unless --apply') { options[:metadata_draft] = true }
      o.on('--help') { puts o; return 0 }
    end
    parser.parse!(argv)
    raise Error, 'Unexpected trailing arguments.' unless argv.empty?
    %i[key_path key_id issuer_id output].each { |key| raise Error, "Missing --#{key.to_s.tr('_', '-')}" unless options[key] }
    catalog = Catalog.new(options[:catalog], only_locales: options[:locales], products: options[:products])
    client = Client.new(key_path: options[:key_path], key_id: options[:key_id], issuer_id: options[:issuer_id], metadata_draft: options[:metadata_draft])
    sync = (options[:metadata_draft] ? DraftSync : Sync).new(client, catalog, options[:output])
    plan = sync.discover
    puts "#{options[:apply] ? 'APPLY' : 'DRY-RUN'}: #{plan.group_by { |op| op['action'] }.map { |action, rows| "#{action}=#{rows.length}" }.join(', ')}"
    puts "Products in scope: #{catalog.metadata.keys.join(', ')}"
    puts "App-only locales (no direct ASC counterpart): #{catalog.skipped.join(', ')}"
    puts "Private snapshot and plan: #{File.expand_path(options[:output])}"
    if options[:apply]
      sync.apply
      puts(options[:metadata_draft] ? 'DRAFTS VERIFIED, NOT SUBMITTED: metadata is saved in editable drafts or already-current products; not yet approved/published.' : 'VERIFIED: all targeted names/descriptions match ASC. No prices, review submission, or Weekly changes.')
    else
      puts 'No remote writes performed. Review plan.json; rerun with --apply and a new private output directory to update.'
    end
    0
  rescue Error, OptionParser::ParseError, KeyError => e
    warn "STOPPED: #{e.message}"
    1
  end
end

exit PurchaseLocalizationSync.main(ARGV) if $PROGRAM_NAME == __FILE__
