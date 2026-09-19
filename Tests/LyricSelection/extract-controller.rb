source = File.read(ARGV.fetch(0))
signatures = [
  'func refreshDataAction()',
  'private func updateLyrics(_ lyrics: [LyricInfoModel])',
  'private func lyric(at indexPath: IndexPath)',
  'func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int)',
  'func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath)',
  'func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath)',
  'func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)'
]

# Compile the actual production methods against lightweight UIKit/network doubles.
# Fail if a method goes missing, instead of silently testing a copied implementation.
methods = signatures.map do |signature|
  first = source.index(signature) or abort "Missing method: #{signature}"
  opening = source.index('{', first) or abort "Missing body: #{signature}"
  depth = 1
  last = opening + 1
  while depth > 0 && last < source.length
    depth += 1 if source[last] == '{'
    depth -= 1 if source[last] == '}'
    last += 1
  end
  abort "Unclosed body: #{signature}" unless depth.zero?
  source[first...last]
end
request_id = source.lines.find { |line| line.include?('private var lyricRequestID =') }
abort 'Missing request generation state' unless request_id

File.write(ARGV.fetch(1), <<~SWIFT)
  import Foundation
  class SelectLyricViewController: LyricSelectionTestDependencies {
  #{request_id}
  #{methods.join("\n")}
  }
SWIFT
