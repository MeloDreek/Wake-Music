#!/usr/bin/env ruby
require 'tmpdir'
require 'open3'

root = File.expand_path('../..', __dir__)
production = File.read(File.join(root, 'Mobie/Mobie/Business/MusicModule/View/EmptyTableViewCell.swift'))
geometry = production[/enum EmptyContentLayout \{.*?\n\}/m] or abort 'Production sizing helper missing'
Dir.mktmpdir('wake-empty-layout-', '/private/tmp') do |output|
  source = File.join(output, 'EmptyContentLayout.swift')
  File.write(source, "import Foundation\n#{geometry}\n")
  executable = File.join(output, 'empty-layout-tests')
  sdk, status = Open3.capture2('xcrun', '--sdk', 'macosx', '--show-sdk-path')
  abort 'macOS SDK unavailable' unless status.success?
  compile = ['xcrun', 'swiftc', '-parse-as-library', '-sdk', sdk.strip,
             '-module-cache-path', File.join(output, 'modules'), source,
             File.join(__dir__, 'EmptyContentLayoutTests.swift'), '-o', executable]
  abort 'Compilation failed' unless system(*compile)
  abort 'Regression failed' unless system(executable)
end

{
  'Business/MusicModule/Controller/MusicsViewController+Data.swift' => 'EmptyTableViewCell.preferredHeight',
  'Business/ImportModule/Controller/DownloadViewController.swift' => 'EmptyTableViewCell.preferredHeight',
  'Business/CollectionModule/ArtistListViewController.swift' => 'EmptyCollectViewCell.preferredSize',
  'Business/CollectionModule/AlbumListViewController.swift' => 'EmptyCollectViewCell.preferredSize',
  'Business/CollectionModule/GenreListViewController.swift' => 'EmptyCollectViewCell.preferredSize'
}.each do |relative, helper|
  source = File.readlines(File.join(root, 'Mobie/Mobie', relative)).reject { |line| line.lstrip.start_with?('//') }.join
  abort "Missing viewport sizing: #{relative}" unless source.include?(helper)
  abort "Double-subtracted bars: #{relative}" if source.match?(/(?:view\.height|bounds\.height)\s*-\s*navHeight/)
  callback = source[/func scrollViewDidChangeAdjustedContentInset\(_ scrollView: UIScrollView\) \{.*?\n    \}/m] or abort "Missing inset invalidation: #{relative}"
  abort "Reentrant lazy-property access: #{relative}" if callback.include?('scrollView ===') || callback.include?('self.collectionView') || callback.include?('self.tableView')
  abort "Missing construction guard: #{relative}" unless callback.include?('superview != nil')
end
puts 'PASS_EMPTY_CONTENT_CALL_SITES 5 controllers'
