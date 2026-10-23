#!/usr/bin/env ruby
# Failed tag writes must show save-error guidance, not request an App Store review.
# Successful writes retain their existing system review behavior.
require 'pathname'

root = Pathname.new(__dir__).join('../..').realpath
source = root.join('Mobie/Mobie/Business/MusicModule/Controller/AudioMatchTagViewController.swift').read
checks = 0
check = lambda do |condition, message|
  raise message unless condition
  checks += 1
end

method = lambda do |name|
  start = source.index(/\bfunc #{Regexp.escape(name)}\(/)
  raise "Missing production method #{name}" unless start
  opening = source.index('{', start)
  depth = 0
  ending = nil
  source[opening..].each_char.with_index(opening) do |char, index|
    depth += 1 if char == '{'
    depth -= 1 if char == '}'
    if depth.zero?
      ending = index
      break
    end
  end
  raise "Unclosed production method #{name}" unless ending
  source[start..ending]
end

auto_writes = %w[
  auto_editArtworkAction auto_editTitleAction auto_editArtistAction
  auto_editAlbumAction auto_editYearAction auto_editGenreAction
  auto_editTrackNumberAction
]
(auto_writes + %w[auto_editLyricAction manual_editLyricAction]).each do |name|
  body = method.call(name)
  # These methods each perform one write and branch on its Boolean result.
  failure_branches = body.scan(/\}\s*else\s*\{\s*((?:self|wSelf)\.guide\w+\(\)\s*(?:return\s*)?)\}/).flatten
  check.call(failure_branches.length == 1, "#{name}: exercise exactly one write-failure branch")
  check.call(failure_branches.first.include?('.guideEmmbedFailed()'), "#{name}: failed writes show the existing error guidance")
  check.call(!failure_branches.first.include?('guideFiveStarRating'), "#{name}: failed writes never ask for a rating")
  check.call(body.include?('"Embedded Success".localStr()'), "#{name}: preserve successful-write feedback")
  if auto_writes.include?(name)
    check.call(body.include?('perform(#selector(guideFiveStarRating), with: nil, afterDelay: 2)'), "#{name}: retain the existing successful-write system review request")
  end
end

error_guidance = method.call('guideEmmbedFailed')
check.call(error_guidance.include?('"Unable to Save".localStr()'), 'Use the localized save-error title')
check.call(error_guidance.include?('"FAQ".localStr()') && error_guidance.include?('"Send Report".localStr()'), 'Retain the existing FAQ and support actions')
check.call(!error_guidance.include?('requestReview') && !error_guidance.include?('guideFiveStarRating'), 'Error guidance has no indirect review request')
check.call(method.call('guideFiveStarRating').include?('AppStore.requestReview(in: windowScene)'), 'Keep the ordinary system review implementation')

puts "#{checks} tag-write failure feedback checks passed"
