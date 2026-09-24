#!/usr/bin/env ruby
# Offline regression tests for the actual PCM conversion and lyric selection code.
# No credentials, Shazam queries, catalog requests or user audio are involved.
# --file checks existing audio read-only. Compressed files need access to macOS's
# system codec service; a restricted test runner can otherwise report Core Audio fmt?.
require 'tmpdir'
require 'open3'
require 'optparse'

files = []
print_source = false
OptionParser.new do |options|
  options.banner = 'Usage: ruby scripts/test-audio-fingerprint-core.rb [--file PATH ...]'
  options.on('--file PATH', 'Prepare a signature from an existing local file, read-only; repeatable') { |path| files << File.expand_path(path) }
  options.on('--print-source', 'Print the generated Swift harness without running it') { print_source = true }
end.parse!
abort "Unexpected arguments: #{ARGV.join(' ')}" unless ARGV.empty?
files.each { |path| abort "Not a regular file: #{path}" unless File.file?(path) }

root = File.expand_path('..', __dir__)
source = File.read(File.join(root, 'Mobie/Mobie/Base/Core/Tools/AudioFingerprintMatcher.swift'))
conversion = source[/    private func makeSignatures\(.*?(?=    private func isActive)/m]
scoring = source[/    private static func normalized\(.*\n(?=})/m]
abort 'Could not locate fingerprint implementation' unless conversion && scoring
conversion = conversion.sub('private func', 'func')
scoring = scoring.gsub('private static func', 'static func')

swift = <<~SWIFT
  import Foundation
  import AVFoundation
  import ShazamKit
  enum KakaError: Error { case custom(String), youhaveCanceled }
  extension String { func localStr() -> String { self } }
  struct AudioFingerprintModel {
      var title: String?; var artist: String?; var album: String?; var duration: TimeInterval?
  }
  struct LRCLibLyricModel {
      var name = ""; var trackName = ""; var artistName = ""; var albumName = ""
      var duration: TimeInterval?; var syncedLyrics: String?; var plainLyrics: String?
  }
  final class Matcher {
      let formatError = "format"
  #{conversion}
  #{scoring}
  }
  var assertions = 0
  func check(_ condition: @autoclosure () -> Bool, _ label: String) {
      precondition(condition(), label)
      assertions += 1
  }
  let temporary = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
  if CommandLine.arguments.count > 2 {
      let matcher = Matcher()
      var failures = 0
      for path in CommandLine.arguments.dropFirst(2) {
          do {
              let url = URL(fileURLWithPath: path)
              let file = try AVAudioFile(forReading: url)
              let duration = Double(file.length) / file.processingFormat.sampleRate
              let signatures = try matcher.makeSignatures(url: url, minimumDuration: 3, maximumDuration: 12, isCancelled: { false })
              let lengths = signatures.map { String(format: "%.3f", $0.duration) }.joined(separator: ", ")
              print("PASS \\(url.lastPathComponent): source \\(Int(file.processingFormat.sampleRate)) Hz / \\(file.processingFormat.channelCount) ch / \\(String(format: "%.3f", duration))s; \\(signatures.count) signatures [\\(lengths)]s")
          } catch {
              failures += 1
              print("UNSUPPORTED/FAILED \\(URL(fileURLWithPath: path).lastPathComponent): \\(error)")
          }
      }
      print("Read-only signature preparation: \\(CommandLine.arguments.count - 2 - failures) passed, \\(failures) unsupported/failed. No recognition requests sent.")
      exit(failures == 0 ? 0 : 1)
  }
  func fixture(_ name: String, rate: Double, channels: AVAudioChannelCount, duration: Double,
               silenceUntil: Double = 0) throws -> URL {
      let url = temporary.appendingPathComponent(name + ".caf")
      let format: AVAudioFormat
      if channels == 6 {
          format = AVAudioFormat(standardFormatWithSampleRate: rate,
              channelLayout: AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_MPEG_5_1_A)!)
      } else {
          format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
      }
      let file = try AVAudioFile(forWriting: url, settings: format.settings)
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
      var frame = 0
      let count = Int(rate * duration)
      while frame < count {
          buffer.frameLength = AVAudioFrameCount(min(4096, count - frame))
          for channel in 0..<Int(channels) {
              let data = buffer.floatChannelData![channel]
              for index in 0..<Int(buffer.frameLength) {
                  let time = Double(frame + index) / rate
                  data[index] = time < silenceUntil ? 0 : Float(0.25 * sin(2 * .pi * 440 * time)
                      + 0.1 * sin(2 * .pi * 997 * time))
              }
          }
          try file.write(from: buffer)
          frame += Int(buffer.frameLength)
      }
      return url
  }
  let matcher = Matcher()
  let cases: [(Double, AVAudioChannelCount)] = [(8000, 1), (22050, 1), (44100, 1), (48000, 2), (96000, 2), (192000, 6)]
  for (rate, channels) in cases {
      let file = try fixture("rate-\\(Int(rate))-\\(channels)", rate: rate, channels: channels, duration: 12)
      let signatures = try matcher.makeSignatures(url: file, minimumDuration: 3, maximumDuration: 12, isCancelled: { false })
      check(signatures.count == 1, "one 12-second signature")
      check(abs(signatures[0].duration - 12) < 0.05, "sample rate conversion must preserve actual duration")
      check(!signatures[0].dataRepresentation.isEmpty, "signature data")
      print("PASS PCM \\(Int(rate)) Hz / \\(channels) channels: \\(signatures[0].duration)s")
  }
  let short = try fixture("short", rate: 48000, channels: 2, duration: 5)
  let shortSignatures = try matcher.makeSignatures(url: short, minimumDuration: 3, maximumDuration: 12, isCancelled: { false })
  check(shortSignatures.count == 1 && abs(shortSignatures[0].duration - 5) < 0.05, "short files are not padded by repeated input")
  let intro = try fixture("silent-intro", rate: 44100, channels: 1, duration: 60, silenceUntil: 25)
  let introSignatures = try matcher.makeSignatures(url: intro, minimumDuration: 3, maximumDuration: 12, isCancelled: { false })
  check(introSignatures.count == 1, "silent first window skipped, audible middle retained")
  let silent = try fixture("silent", rate: 44100, channels: 1, duration: 12, silenceUntil: 12)
  do {
      _ = try matcher.makeSignatures(url: silent, minimumDuration: 3, maximumDuration: 12, isCancelled: { false })
      fatalError("silence must not produce a matching request")
  } catch { assertions += 1 }
  let tiny = try fixture("too-short", rate: 44100, channels: 1, duration: 1)
  do {
      _ = try matcher.makeSignatures(url: tiny, minimumDuration: 3, maximumDuration: 12, isCancelled: { false })
      fatalError("insufficient audio accepted")
  } catch { assertions += 1 }
  do {
      _ = try matcher.makeSignatures(url: short, minimumDuration: 3, maximumDuration: 12, isCancelled: { true })
      fatalError("cancellation ignored")
  } catch KakaError.youhaveCanceled { assertions += 1 }
  let remote = URL(string: "https://example.com/audio.mp3")!
  do {
      _ = try matcher.makeSignatures(url: remote, minimumDuration: 3, maximumDuration: 12, isCancelled: { false })
      fatalError("remote URL should not be decoded here")
  } catch { assertions += 1 }
  var target = AudioFingerprintModel(title: "Don't Stop", artist: "Artist", album: "Album", duration: 200)
  var lyric = LRCLibLyricModel(name: "Don’t Stop", trackName: "Don’t Stop", artistName: "ARTIST", albumName: "Album", duration: 200, syncedLyrics: nil, plainLyrics: "Correct words")
  check(Matcher.lyricMatchScore(lyric, target: target) != nil, "punctuation and case normalization")
  lyric.trackName = "Different Song"; lyric.syncedLyrics = "[00:01]Wrong words"
  check(Matcher.lyricMatchScore(lyric, target: target) == nil, "timed wrong-title lyrics rejected")
  lyric.trackName = "Don't Stop"; lyric.artistName = "Cover Artist"
  check(Matcher.lyricMatchScore(lyric, target: target) == nil, "wrong performer rejected")
  lyric.artistName = "Artist"; lyric.duration = 220
  check(Matcher.lyricMatchScore(lyric, target: target) == nil, "wrong recording duration rejected")
  lyric.duration = 205
  check(Matcher.lyricMatchScore(lyric, target: target) == nil, "misaligned synchronized lyrics rejected")
  lyric.syncedLyrics = nil
  check(Matcher.lyricMatchScore(lyric, target: target) != nil, "plain lyric duration tolerance")
  lyric.plainLyrics = "  "; lyric.syncedLyrics = "  "
  check(Matcher.lyricMatchScore(lyric, target: target) == nil, "blank response rejected")
  lyric.plainLyrics = "Words"; lyric.duration = 200; lyric.trackName = "Don't Stop (Live)"
  check(Matcher.lyricMatchScore(lyric, target: target) == nil, "version identity retained")
  target.artist = ""
  check(Matcher.lyricMatchScore(lyric, target: target) == nil, "unknown artist not auto embedded")
  print("PASS: \\(assertions) offline fingerprint/lyric assertions")
SWIFT

if print_source
  puts swift
  exit
end

Dir.mktmpdir('wakemusic-fingerprint-') do |temporary|
  binary = File.join(temporary, 'fingerprint-tests')
  command = ['xcrun', 'swiftc', '-swift-version', '5', '-module-cache-path', File.join(temporary, 'modules'),
             '-framework', 'AVFoundation', '-framework', 'ShazamKit', '-o', binary, '-']
  output, status = Open3.capture2e(*command, stdin_data: swift)
  abort output unless status.success?
  puts output unless output.empty?
  system(binary, temporary, *files) || abort('Fingerprint regression tests failed')
end
