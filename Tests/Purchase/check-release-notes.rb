#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative 'check-app-descriptions'
require_relative '../../Tools/AppStoreConnect/sync-release-notes'

texts=ReleaseNotesSync.catalog
check(texts.length==39,'Release-note locale count')
texts.each do |locale,platforms|
  platforms.each do |platform,text|
    count=platform=='IOS' ? 9 : 8
    check(text.scan(/^\d+\. /).length==count,"Item count: #{locale}/#{platform}")
    check(text.scan(/^(\d+)\. /).flatten.map(&:to_i)==(1..count).to_a,'Numbering')
    check(text.include?('iOS 27.1')==(platform=='IOS'),'Platform-specific feature')
    check(!text.match?(/维克|維克/),'No unintended Chinese brand in notes')
    %w[pCloud Box MEGA Yandex SMB FTP 123 Navidrome].each { |service| check(text.include?(service),"Missing service #{service}: #{locale}") }
    check(text.include?('Guangya') || %w[zh-Hans zh-Hant].include?(locale),'Guangya missing')
    check(text.include?('support@kakainc.com'),'Contact missing')
    check(text.encode('UTF-16LE').bytesize/2<=4000,'Length')
    file=File.join(ReleaseNotesSync::ROOT,platform.downcase,"#{locale}.txt")
    check(File.read(file).strip==text,'Stale generated release notes')
  end
end

original=$stdout
$stdout=StringIO.new
begin
  Dir.mktmpdir('wake-release-tests') do |dir|
    c=DescriptionFixture.new('whatsNew')
    AppDescriptionSync.sync(c,texts,File.join(dir,'dry'),false,field:'whatsNew',variant_index:2)
    check(c.writes.empty?,'Dry-run mutated metadata')
    AppDescriptionSync.sync(c,texts,File.join(dir,'apply'),true,field:'whatsNew',variant_index:2)
    check(c.writes.length==156,'Exactly 156 release notes must be saved')
    check(c.writes.all? { |w| w.dig('data','attributes').keys==['whatsNew'] },'Description/other fields modified')
    AppDescriptionSync.sync(c,texts,File.join(dir,'repeat'),true,field:'whatsNew',variant_index:2)
    check(c.writes.length==156,'Repeated writes')
    rejects('Field mismatch accepted') { AppDescriptionSync.sync(c,texts,File.join(dir,'wrong'),true) }
    %i[state wrong_owner extra_locale concurrent fail_after].each do |failure|
      bad=DescriptionFixture.new('whatsNew')
      bad.public_send("#{failure}=",failure==:state ? 'IN_REVIEW' : failure==:fail_after ? 1 : true)
      rejects("Did not stop #{failure}") { AppDescriptionSync.sync(bad,texts,File.join(dir,failure.to_s),true,field:'whatsNew',variant_index:2) }
      check(bad.writes.length==(failure==:fail_after ? 1 : 0),'Wrong failure write count')
    end
  end
ensure
  $stdout=original
end
c=ReleaseNotesSync::Client.allocate
c.allowed_ids=['known']
rejects('Release client changed description') { c.request('PATCH','/v1/appStoreVersionLocalizations/known',{'data'=>{'type'=>'appStoreVersionLocalizations','id'=>'known','attributes'=>{'description'=>'forbidden'}}}) }
rejects('Release client allowed submit') { c.request('POST','/v1/reviewSubmissions',{}) }
puts "PASS: #{$checks} total assertions; release notes only, platform variants and all 156 targets."
