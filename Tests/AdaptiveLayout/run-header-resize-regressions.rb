#!/usr/bin/env ruby
require 'tmpdir'
root = File.expand_path('../..', __dir__)
source = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/View/PlayerMoreConfigCollectCell.swift'))
method = source[/    private func layoutSongHeader\(\) \{.*?^    \}/m]
abort 'Production header method was not found' unless method
queue_source = File.read(File.join(root, 'Mobie/Mobie/Business/PlayerModule/View/PlayerQueueCollectCell.swift'))
queue_method = queue_source[/    override func layoutSubviews\(\) \{.*?^    \}/m]
abort 'Production queue layout was not found' unless queue_method
Dir.mktmpdir('wake-player-header-') do |directory|
  path = File.join(directory, 'HeaderResizeProbe.swift')
  support = <<~SWIFT
    import UIKit
    final class HeaderResizeProbe: UICollectionViewCell {
      let tableView = UITableView(frame: .zero, style: .insetGrouped)
      let songHeader = UITableViewHeaderFooterView()
      let artwork = UIImageView()
      let songTitle = UILabel()
      let artistLabel = UILabel()
      override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(tableView)
        [artwork, songTitle, artistLabel].forEach { songHeader.contentView.addSubview($0) }
        songTitle.text = "Yesterday Once More"
        artistLabel.text = "Carpenters"
        tableView.tableHeaderView = songHeader
      }
      required init?(coder: NSCoder) { fatalError() }
    #{method.sub('private func', 'func')}
    }
    func kaka_IsMacOS() -> Bool { false }
    final class QueueHeaderResizeProbe: UICollectionViewCell {
      let tableView = UITableView(frame: .zero, style: .plain)
      let queueHeader = UITableViewHeaderFooterView()
      let artwork = UIImageView()
      let songTitle = UILabel()
      let artist = UILabel()
      let heading = UILabel()
      let modes = UIStackView()
      let bottomReservedHeight: CGFloat = 76
      override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(tableView)
        [artwork, songTitle, artist, heading, modes].forEach { queueHeader.contentView.addSubview($0) }
        tableView.tableHeaderView = queueHeader
      }
      required init?(coder: NSCoder) { fatalError() }
    #{queue_method}
    }
  SWIFT
  File.write(path, support)
  executable = File.join(directory, 'header-tests')
  sdk = IO.popen(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], &:read).strip
  target = "#{`uname -m`.strip}-apple-ios16.0-simulator"
  abort 'Compilation failed' unless system('xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-target', target, '-sdk', sdk,
    '-module-cache-path', File.join(directory, 'module-cache'), path,
    File.join(__dir__, 'HeaderResizeRegression.swift'), '-o', executable)
  abort 'Header resize regressions failed' unless system('xcrun', 'simctl', 'spawn', ARGV.fetch(0, 'booted'), executable)
end
