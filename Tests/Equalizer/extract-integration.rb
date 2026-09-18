# Extract the production methods, without copying their logic into the test.
# Dependencies are small deterministic test doubles in IntegrationTests.swift.
root, output = ARGV
raise "usage: extract-integration.rb repo-root output-file" unless root && output

def method_source(source, name, label: nil)
  suffix = label ? "\\(#{Regexp.escape(label)}:" : ""
  declaration = source.match(/^\s*(?:@MainActor\s+)?(?:(?:public|private|open)\s+)?func #{Regexp.escape(name)}\b#{suffix}/)
  raise "Missing production method #{name}" unless declaration
  start = declaration.begin(0)
  opening = source.index("{", declaration.end(0))
  depth = 0
  finish = nil
  source[opening..].each_char.with_index do |character, offset|
    depth += 1 if character == "{"
    depth -= 1 if character == "}"
    if depth == 0
      finish = opening + offset
      break
    end
  end
  raise "Unbalanced production method #{name}" unless finish
  source[start..finish]
end

music = File.join(root, "Mobie/Mobie/Base/Music")
store = File.read(File.join(music, "PlayerEqualizerStore.swift"))
store = store.lines.reject { |line| line.start_with?("import ") }.join
equalizer = File.read(File.join(music, "KakaMusicPlayer+Equalizer.swift"))
playback = File.read(File.join(music, "KakaMusicPlayer+Play.swift"))
methods = %w[equalizerSettingsDidChange reloadCurrentEngineForEqualizer].map { |name| method_source(equalizer, name) }
methods += %w[retirePlayback seek pause].map { |name| method_source(playback, name) }
delegate = File.read(File.join(music, "KakaMusicPlayer+Delegate.swift"))
readiness = method_source(delegate, "playerController", label: "state")
# The remainder schedules unrelated cover/lyric/pre-download work. Preserve the
# entire real readiness, pause-intent, and end-state control flow before it.
boundary = "        if state != .bufferFinished { return }"
raise "Readiness boundary changed; inspect extraction" unless readiness.include?(boundary)
methods << readiness.split(boundary, 2).first + "\n    }\n"
File.write(output, "import Foundation\nimport Combine\n" + store + "\n@MainActor extension KakaMusicPlayer {\n" + methods.join("\n") + "\n}\n")
