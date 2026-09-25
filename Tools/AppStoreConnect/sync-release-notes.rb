#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative 'sync-app-descriptions'

module ReleaseNotesSync
  Error = AppDescriptionSync::Error
  ROOT = File.join(AppDescriptionSync::ROOT, 'release-notes')

  class Client < AppDescriptionSync::Client
    def metadata_field
      'whatsNew'
    end
  end

  def self.catalog
    source = JSON.parse(File.read(File.join(ROOT, 'source.json'), encoding:'UTF-8'))
    expected_sources = AppDescriptionSync::LOCALES.map { |l| AppDescriptionSync::ALIASES.fetch(l,l) }.uniq.sort
    raise Error, 'Unexpected source language set' unless source.keys.sort == expected_sources
    AppDescriptionSync::LOCALES.to_h do |locale|
      value = source.fetch(AppDescriptionSync::ALIASES.fetch(locale,locale))
      raise Error, "Invalid release notes: #{locale}" unless value.keys.sort == %w[contact heading ios items] && value['items'].length == 8
      variants = %w[IOS MAC_OS].to_h do |platform|
        items = (platform == 'IOS' ? [value.fetch('ios')] : []) + value.fetch('items')
        text = "◆◆◆ #{value.fetch('heading')}\n\n" + items.each_with_index.map { |v,i| "#{i+1}. #{v}" }.join("\n") + "\n\n" + value.fetch('contact')
        text = text.gsub("l'app.", "l'application.").gsub('services cloud', 'services infonuagiques') if locale == 'fr-CA'
        units = text.encode('UTF-16LE').bytesize / 2
        raise Error, "Invalid text length/markers: #{locale}" unless units.between?(150,4000) && !text.match?(/\{\{|●|mailto:|\]\(/)
        raise Error, "Contact missing: #{locale}" unless text.include?('support@kakainc.com')
        raise Error, "Wrong brand: #{locale}" if locale != 'zh-Hans' && text.match?(/维克|維克/)
        raise Error, 'iOS note on Mac' if platform == 'MAC_OS' && text.match?(/iOS 27\.1|iPhone Duo/)
        [platform,text]
      end
      [locale,variants]
    end
  end

  def self.main
    opts={}
    OptionParser.new do |p|
      p.on('--key-file PATH') { |v| opts[:key_path]=v }
      p.on('--key-id ID') { |v| opts[:key_id]=v }
      p.on('--issuer-id ID') { |v| opts[:issuer_id]=v }
      p.on('--output PATH') { |v| opts[:output]=v }
      p.on('--apply') { opts[:apply]=true }
      p.on('--validate') { opts[:validate]=true }
      p.on('--render') { opts[:render]=true }
    end.parse!
    raise Error, 'Unexpected arguments' unless ARGV.empty?
    texts=catalog
    puts "Validated #{texts.length} locales / 2 platforms. Max #{texts.values.flat_map(&:values).map(&:length).max} characters."
    if opts[:render]
      texts.each do |locale,variants|
        variants.each do |platform,text|
          folder=File.join(ROOT,platform.downcase)
          FileUtils.mkdir_p(folder)
          File.write(File.join(folder,"#{locale}.txt"),text+"\n")
        end
      end
    end
    return if opts[:validate] || opts[:render]
    %i[key_path key_id issuer_id output].each { |k| raise Error, "Missing #{k}" unless opts[k] }
    raise Error, 'Unexpected key size' unless File.size(opts[:key_path]).between?(100,16_384)
    c=Tempfile.create(['wake-release-notes-key','.p8']) do |f|
      f.chmod(0600)
      f.write(File.binread(opts[:key_path])); f.flush
      Client.new(key_path:f.path,key_id:opts[:key_id],issuer_id:opts[:issuer_id])
    end
    AppDescriptionSync.sync(c,texts,opts[:output],opts[:apply],field:'whatsNew',variant_index:2)
  rescue Error, KeyError, OptionParser::ParseError => e
    warn "STOPPED: #{e.message}"
    exit 1
  end
end

ReleaseNotesSync.main if $PROGRAM_NAME == __FILE__
