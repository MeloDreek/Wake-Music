#!/usr/bin/env ruby
require 'tmpdir'
require 'open3'
require 'json'
root = File.expand_path('../..', __dir__)
build = Dir.mktmpdir('wake-empty-cell-', '/private/tmp')
snapkit = Dir[File.join(root, 'Pods/SnapKit/Sources/*.swift')]
abort 'Run pod install first (SnapKit source is needed)' if snapkit.empty?
asset = File.join(root, 'Mobie/Mobie/System/Assets.xcassets/Other/empty_music.imageset/empty_music@3x.png')
cells = %w[EmptyTableViewCell EmptyCollectViewCell].map do |name|
  source = File.readlines(File.join(root, "Mobie/Mobie/Business/MusicModule/View/#{name}.swift")).reject { |line| line.start_with?('import ') }.join
  source = "import UIKit\n" + source.gsub('UIImage(named: "empty_music")', "UIImage(contentsOfFile: #{JSON.generate(asset)})")
  path = File.join(build, "#{name}.swift")
  File.write(path, source)
  path
end
inset_probes = {
  'Musics' => ['MusicModule/Controller/MusicsViewController+Data.swift', 'tableView', 'UITableView', 'UITableViewDelegate'],
  'Download' => ['ImportModule/Controller/DownloadViewController.swift', 'tableView', 'UITableView', 'UITableViewDelegate'],
  'Artist' => ['CollectionModule/ArtistListViewController.swift', 'collectionView', 'UICollectionView', 'UICollectionViewDelegate'],
  'Album' => ['CollectionModule/AlbumListViewController.swift', 'collectionView', 'UICollectionView', 'UICollectionViewDelegate'],
  'Genre' => ['CollectionModule/GenreListViewController.swift', 'collectionView', 'UICollectionView', 'UICollectionViewDelegate']
}.map do |name, (path, property, type, delegate)|
  source = File.read(File.join(root, 'Mobie/Mobie/Business', path))
  callback = source[/func scrollViewDidChangeAdjustedContentInset\(_ scrollView: UIScrollView\) \{.*?\n    \}/m] or abort "Inset callback missing: #{path}"
  initializer = type == 'UITableView' ? 'UITableView(frame: .zero, style: .insetGrouped)' : 'UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())'
  <<~SWIFT
    class #{name}InsetProbe: UIViewController, #{delegate}, InsetInitializationProbe {
      var initializationCount = 0
      var isNoneMusic = true
      var dataArray: [Int] = []
      lazy var #{property}: #{type} = {
        initializationCount += 1
        let scroll = #{initializer}
        scroll.delegate = self
        scroll.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 80, right: 0)
        // Reproduce UIKit invoking this callback before the lazy initializer returns.
        scrollViewDidChangeAdjustedContentInset(scroll)
        return scroll
      }()
      override func viewDidLoad() { super.viewDidLoad(); view.addSubview(#{property}) }
      #{callback}
    }
  SWIFT
end.join("\n")
inset_path = File.join(build, 'InsetProbes.swift')
File.write(inset_path, "import UIKit\n" + inset_probes)
sdk, status = Open3.capture2('xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path')
abort 'Simulator SDK unavailable' unless status.success?
executable = File.join(build, 'empty-cell-probe')
compile = ['xcrun', 'swiftc', '-parse-as-library', '-swift-version', '5', '-target', 'arm64-apple-ios16.0-simulator',
           '-sdk', sdk.strip, '-module-cache-path', File.join(build, 'modules'), *snapkit, *cells, inset_path,
           File.join(__dir__, 'EmptyCellProbe.swift'), '-o', executable]
abort 'Probe compilation failed' unless system(*compile)
puts "PROBE_EXECUTABLE=#{executable}"
exit if ARGV.include?('--build-only')
abort 'UIKit regression failed' unless system('xcrun', 'simctl', 'spawn', ENV.fetch('LAYOUT_SIMULATOR_UDID', 'booted'), executable)
