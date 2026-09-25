#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative '../../Tools/AppStoreConnect/sync-app-descriptions'
require 'tmpdir'
require 'stringio'

def check(value, message)
  raise message unless value
  $checks += 1
end
def rejects(message)
  begin
    yield
  rescue AppDescriptionSync::Error
    $checks += 1
    return
  end
  raise message
end

class DescriptionFixture
  attr_accessor :allowed_ids, :state, :wrong_owner, :extra_locale, :concurrent, :fail_after
  attr_reader :writes
  def initialize
    @state = 'PREPARE_FOR_SUBMISSION'
    @writes = []
    @rows = AppDescriptionSync::TARGETS.to_h do |t|
      [t[3], AppDescriptionSync::LOCALES.map { |l| { 'id'=>"#{t[3]}-#{l}", 'type'=>'appStoreVersionLocalizations',
        'attributes'=>{ 'locale'=>l, 'description'=>'Previous text', 'keywords'=>'unchanged', 'whatsNew'=>'unchanged', 'supportUrl'=>'https://example.com' } } }]
    end
  end
  def request(method, path, body=nil)
    if method == 'PATCH'
      raise AppDescriptionSync::Error, 'Simulated uncertain write' if fail_after && writes.length >= fail_after
      data = body.fetch('data')
      raise 'Unexpected mutation' unless data['attributes'].keys == ['description'] && allowed_ids.include?(data['id'])
      row = @rows.values.flatten.find { |r| r['id'] == data['id'] }
      row['attributes'].merge!(data['attributes'])
      writes << body
      return { 'data'=>Marshal.load(Marshal.dump(row)) }
    end
    id = path.split('/').last
    result = case path
    when %r{\A/v1/apps/}
      t=AppDescriptionSync::TARGETS.find { |x| x[0]==id }
      { 'id'=>id, 'attributes'=>{ 'bundleId'=>t[1] } }
    when %r{\A/v1/appStoreVersions/}
      t=AppDescriptionSync::TARGETS.find { |x| x[3]==id }
      { 'id'=>id, 'attributes'=>{ 'versionString'=>'3.6.0', 'platform'=>t[2], 'appStoreState'=>state } }
    when %r{\A/v1/appStoreVersionLocalizations/}
      row=Marshal.load(Marshal.dump(@rows.values.flatten.find { |r| r['id']==id }))
      row['attributes']['description']='Concurrent edit' if concurrent
      row
    else
      raise "Unexpected path #{path}"
    end
    { 'data'=>result }
  end
  def list(path)
    if path.include?('/apps/')
      id=path.split('/')[3]
      return [] if wrong_owner
      return AppDescriptionSync::TARGETS.select { |t| t[0]==id }.map { |t| { 'id'=>t[3] } }
    end
    result=Marshal.load(Marshal.dump(@rows.fetch(path.split('/')[3])))
    result << { 'id'=>'extra', 'attributes'=>{ 'locale'=>'sl-SI' } } if extra_locale
    result
  end
end

$checks=0
texts=AppDescriptionSync.catalog
check(texts.length==39, 'Locale count')
texts.each do |locale, editions|
  editions.each do |edition, text|
    check(text.length<=4000, "Length #{locale}")
    check(text.scan('◆◆◆').length==8, "Sections #{locale}")
    counts=text.split('◆◆◆').drop(1).map { |s| s.scan(/^\d+\. /).length }
    check(counts==[4,4,4,4,4,3,edition=='standard' ? 4 : 2,0], "Missing approved items #{locale}/#{edition}")
    check(text.include?('SMB') && text.include?('WebDAV') && text.include?('FTP') && text.include?('Navidrome') && text.include?('Subsonic'), "Protocols #{locale}")
    check(text.include?('DSF') && text.include?('DFF') && text.include?('10'), "Formats/features #{locale}")
    check(text.include?('support@kakainc.com'), "Contact #{locale}")
    check(locale=='zh-Hans' || !text.match?(/维克|維克/), "Brand #{locale}")
    file=File.join(AppDescriptionSync::ROOT,'descriptions',edition,"#{locale}.txt")
    check(File.read(file).strip==text, "Rendered copy differs: #{file}")
  end
end
check(AppDescriptionSync.legal_language('pt-PT')=='en', 'Do not invent a Portuguese legal page')
check(AppDescriptionSync.legal_language('fr-CA')=='fr', 'Use available French legal page')
check(texts['en-GB']['standard'].include?('favourite'), 'British spelling')
check(texts['es-MX']['standard'].include?('computadora'), 'Mexican Spanish')
check(texts['fr-CA']['standard'].include?('infonuagiques'), 'Canadian French')

original=$stdout
$stdout=StringIO.new
begin
  Dir.mktmpdir('wake-description-tests') do |dir|
    c=DescriptionFixture.new
    AppDescriptionSync.sync(c,texts,File.join(dir,'dry'),false)
    check(c.writes.empty?, 'Dry-run wrote metadata')
    AppDescriptionSync.sync(c,texts,File.join(dir,'apply'),true)
    check(c.writes.length==156, 'Must update exactly 156 descriptions')
    check(File.exist?(File.join(dir,'apply','verified.json')), 'Missing readback')
    check((File.stat(File.join(dir,'apply','before.json')).mode & 077)==0, 'Backup permissions')
    AppDescriptionSync.sync(c,texts,File.join(dir,'repeat'),true)
    check(c.writes.length==156, 'Idempotent rerun wrote again')
    %i[state wrong_owner extra_locale concurrent fail_after].each do |failure|
      bad=DescriptionFixture.new
      bad.public_send("#{failure}=", failure==:state ? 'IN_REVIEW' : failure==:fail_after ? 1 : true)
      rejects("Failed to stop: #{failure}") { AppDescriptionSync.sync(bad,texts,File.join(dir,failure.to_s),true) }
      check(bad.writes.length==(failure==:fail_after ? 1 : 0), "Unexpected write count: #{failure}")
    end
  end
ensure
  $stdout=original
end

c=AppDescriptionSync::Client.allocate
c.allowed_ids=['allowed']
rejects('Allowed wrong endpoint') { c.request('PATCH','/v1/apps/allowed',{}) }
rejects('Allowed unknown localization') { c.request('PATCH','/v1/appStoreVersionLocalizations/unknown',{}) }
rejects('Allowed other metadata') { c.request('PATCH','/v1/appStoreVersionLocalizations/allowed', { 'data'=>{'type'=>'appStoreVersionLocalizations','id'=>'allowed','attributes'=>{'keywords'=>'bad'}} }) }
puts "PASS: #{$checks} assertions; 39 locales, 156 scoped writes, backups, readback, idempotence and failure safety."
