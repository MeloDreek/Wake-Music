#!/bin/bash
set -euo pipefail
spectrum_root="$(cd "$(dirname "$0")/../.." && pwd)"
spectrum_temp="$(mktemp -d /private/tmp/wake-spectrum-backend.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
test -f /opt/homebrew/include/libavcodec/avcodec.h
ruby - "$spectrum_temp" <<'RUBY'
dir = ARGV.first
modules = %w[avutil avcodec avformat swresample].map { |name| "module Lib#{name} [system] { header \"/opt/homebrew/include/lib#{name}/#{name}.h\" export * }" }
File.write(File.join(dir, 'Shim.h'), "#include <errno.h>\n#include <libavutil/error.h>\nstatic inline int swift_AVERROR(int e) { return AVERROR(e); }\nstatic const int swift_AVERROR_EOF = AVERROR_EOF;\nstatic const int swift_AVERROR_INVALIDDATA = AVERROR_INVALIDDATA;\n")
modules << "module FFmpegKit { header \"#{dir}/Shim.h\" export * }"
File.write(File.join(dir, 'module.modulemap'), modules.join("\n"))
File.write(File.join(dir, 'broken.flac'), 'invalid audio')
RUBY
xcrun swiftc -parse-as-library -module-cache-path "$spectrum_temp/modules" -I "$spectrum_temp" -I /opt/homebrew/include \
  -L /opt/homebrew/lib -lavformat -lavcodec -lavutil -lswresample \
  "$spectrum_root/Mobie/Mobie/Base/Music/AudioSpectrumAnalyzer.swift" "$spectrum_root/Tests/Spectrum/BackendTests.swift" -o "$spectrum_temp/test"
/opt/homebrew/bin/ffmpeg -v error -f lavfi -i 'sine=frequency=1000:duration=2:sample_rate=48000' -ac 2 "$spectrum_temp/tone.flac"
/opt/homebrew/bin/ffmpeg -v error -i "$spectrum_temp/tone.flac" "$spectrum_temp/tone.mp3"
/opt/homebrew/bin/ffmpeg -v error -f lavfi -i 'anullsrc=channel_layout=5.1:sample_rate=96000' -t 1 "$spectrum_temp/silence.wav"
/opt/homebrew/bin/ffmpeg -v error -f lavfi -i 'sine=frequency=1000:duration=4:sample_rate=48000' -ac 6 -c:a dca -strict -2 -f wav "$spectrum_temp/tone.dts"
ruby "$spectrum_root/Tests/Spectrum/MakeDamagedDTSFixtures.rb" "$spectrum_temp/tone.dts" "$spectrum_temp"
"$spectrum_temp/test" "$spectrum_temp/tone.flac"
"$spectrum_temp/test" "$spectrum_temp/tone.mp3"
"$spectrum_temp/test" "$spectrum_temp/silence.wav"
"$spectrum_temp/test" "$spectrum_temp/tone.dts" --expect-skipped=0
"$spectrum_temp/test" "$spectrum_temp/dts-isolated.dts" --expect-skipped=1 --expect-complete-timeline
"$spectrum_temp/test" "$spectrum_temp/dts-tail.dts" --expect-skipped=1
"$spectrum_temp/test" "$spectrum_temp/dts-repeated.dts" --fail
"$spectrum_temp/test" "$spectrum_temp/dts-many-isolated.dts" --fail
"$spectrum_temp/test" "$spectrum_temp/tone.flac" --cancel
"$spectrum_temp/test" "$spectrum_temp/broken.flac" --fail
"$spectrum_temp/test" "$spectrum_temp/absent.wav" --fail
for spectrum_file in "$@"; do
  "$spectrum_temp/test" "$spectrum_file"
  "$spectrum_temp/test" "$spectrum_file" --cancel-active
done
