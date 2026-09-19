#!/bin/bash
set -euo pipefail
spectrum_root="$(cd "$(dirname "$0")/../.." && pwd)"
spectrum_temp="$(mktemp -d /private/tmp/wake-spectrum-cache.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby - "$spectrum_root" "$spectrum_temp" <<'RUBY'
root, output = ARGV
source = File.read(File.join(root, 'Mobie/Mobie/Base/Music/AudioSpectrumAnalyzer.swift'))
model = source.split('    struct Report {', 2).fetch(1).split('    enum Failure:', 2).first
cache = source.split('final class AudioSpectrumCache {', 2).fetch(1).split('/// 4096-sample Hann windows;', 2).first
File.write(File.join(output, 'Cache.swift'), "import Foundation\nimport CryptoKit\nimport Compression\nenum AudioSpectrumAnalyzer { struct Report {#{model}}\nfinal class AudioSpectrumCache {#{cache}")
RUBY
xcrun swiftc -parse-as-library -module-cache-path "$spectrum_temp/modules" "$spectrum_temp/Cache.swift" \
  "$spectrum_root/Tests/Spectrum/CacheTests.swift" -o "$spectrum_temp/test"
"$spectrum_temp/test" "$spectrum_temp"

# Run the real analyzer/cache wrapper too, not a substitute implementation.
ruby - "$spectrum_temp" <<'RUBY'
dir = ARGV.first
modules = %w[avutil avcodec avformat swresample].map { |name| "module Lib#{name} [system] { header \"/opt/homebrew/include/lib#{name}/#{name}.h\" export * }" }
File.write(File.join(dir, 'Shim.h'), "#include <errno.h>\n#include <libavutil/error.h>\nstatic inline int swift_AVERROR(int e) { return AVERROR(e); }\nstatic const int swift_AVERROR_EOF = AVERROR_EOF;\nstatic const int swift_AVERROR_INVALIDDATA = AVERROR_INVALIDDATA;\n")
modules << "module FFmpegKit { header \"#{dir}/Shim.h\" export * }"
File.write(File.join(dir, 'module.modulemap'), modules.join("\n"))
RUBY
xcrun swiftc -parse-as-library -module-cache-path "$spectrum_temp/modules" -I "$spectrum_temp" -I /opt/homebrew/include \
  -L /opt/homebrew/lib -lavformat -lavcodec -lavutil -lswresample \
  "$spectrum_root/Mobie/Mobie/Base/Music/AudioSpectrumAnalyzer.swift" "$spectrum_root/Tests/Spectrum/CacheIntegrationTests.swift" -o "$spectrum_temp/integration-test"
/opt/homebrew/bin/ffmpeg -v error -f lavfi -i 'sine=frequency=1000:duration=2:sample_rate=48000' -ac 2 "$spectrum_temp/tone.flac"
"$spectrum_temp/integration-test" "$spectrum_temp"
