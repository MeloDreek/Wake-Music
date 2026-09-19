# Run real UIKit + Kingfisher against the production list-image loading methods.
# No app install, media modification, dependency build, or network access required.
require 'tmpdir'
root = File.expand_path('../..', __dir__)
products = ARGV[0] || '/Users/kaka/Library/Developer/Xcode/DerivedData/Wake_Music-frvusdpuuyvnudbjkrrkappwlabg/Build/Products/Debug-iphonesimulator'
abort 'Build the iOS simulator app first (Kingfisher.o is missing).' unless File.file?(File.join(products, 'Kingfisher.o'))
def extract(source, signature)
  start = source.index(signature) or raise "Missing #{signature}"
  opening = source.index('{', start)
  depth = 0
  source[opening..].each_char.with_index do |char, index|
    depth += 1 if char == '{'
    depth -= 1 if char == '}'
    return source[start..(opening + index)] if depth.zero?
  end
  raise 'Unbalanced production source'
end
cell = File.read(File.join(root, 'Mobie/Mobie/Business/MusicModule/View/MusicTableViewCell.swift'))
sandbox = File.read(File.join(root, 'LocalSDK/AppGroupKit/Classes/CoreManager/Sandbox/SandboxFileManager+Music.swift'))
cache = extract(cell, 'private static let artworkCache: ImageCache =') + '()'
# Isolate the probe cache from the application's cache; preserve its real limits/options.
cache = cache.sub('private ', '').sub('MusicListThumbnails.v2', 'MusicListThumbnails.Regression.' + Process.pid.to_s)
load_method = extract(cell, 'private func loadArtwork(').sub('private ', '')
revision = extract(sandbox, 'public static func revision(at')
probe = <<~SWIFT
  import Foundation
  import UIKit
  import Kingfisher
  func kaka_IsMacOS() -> Bool { false }
  extension Int { func ckValue() -> CGFloat { CGFloat(self) } }
  enum MusicArtworkCache { #{revision} }
  struct MusicItemModel {
      let url: URL
      let key: String
      func coverThumbnailURL() -> URL { url }
      func artworkCacheKey() -> String { key }
      func placeImage() -> UIImage { UIImage(systemName: "music.note")! }
  }
  @MainActor final class ProbeCell: UITableViewCell {
      let coverImgView = UIImageView()
      override var traitCollection: UITraitCollection { UITraitCollection(displayScale: 3) }
      #{cache}
      #{load_method}
  }
SWIFT
ENV['DEVELOPER_DIR'] ||= '/Applications/Xcode.app/Contents/Developer'
build = Dir.mktmpdir('wake-list-artwork-', '/private/tmp')
File.write(File.join(build, 'Production.swift'), probe)
sdk = IO.popen(['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-path'], &:read).strip
abort 'Simulator compile failed' unless system('xcrun', '--sdk', 'iphonesimulator', 'swiftc', '-parse-as-library',
  '-target', 'arm64-apple-ios16.0-simulator', '-sdk', sdk, '-I', products, '-module-cache-path', File.join(build, 'modules'),
  File.join(build, 'Production.swift'), File.join(__dir__, 'ListArtworkRegression.swift'),
  File.join(products, 'Kingfisher.o'), '-o', File.join(build, 'probe'))
abort 'List image regressions failed' unless system('xcrun', 'simctl', 'spawn', ENV.fetch('ARTWORK_SIMULATOR_UDID', 'booted'), File.join(build, 'probe'))
puts "Probe artifacts: #{build}"
