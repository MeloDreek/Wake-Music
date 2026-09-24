#!/bin/bash
# Creates only synthetic fixtures in a NEW directory below the requested parent.
set -euo pipefail

parent=${1:?Usage: bash generate-regression-fixtures.sh TEMP_PARENT}
ffmpeg=${FFMPEG:-/opt/homebrew/bin/ffmpeg}
if [[ ! -x "$ffmpeg" ]]; then
  ffmpeg=$(command -v ffmpeg || true)
fi
if [[ -z "$ffmpeg" || ! -x "$ffmpeg" ]]; then
  echo 'ffmpeg is required to generate synthetic regression fixtures.' >&2
  exit 1
fi

fixtures=$(mktemp -d "$parent/fixtures.XXXXXX")
encoders=$("$ffmpeg" -hide_banner -encoders 2>/dev/null)

has_encoder() {
  [[ "$encoders" =~ [[:space:]]$1[[:space:]] ]]
}

generate() {
  local extension=$1 codec=$2
  shift 2
  if ! has_encoder "$codec"; then
    echo "SKIP $extension: ffmpeg encoder $codec is unavailable" >&2
    return
  fi
  "$ffmpeg" -nostdin -v error -f lavfi \
    -i 'sine=frequency=440:sample_rate=44100:duration=1.25' \
    -map_metadata -1 -fflags +bitexact -flags:a +bitexact \
    -c:a "$codec" "$@" "$fixtures/synthetic.$extension"
  echo "Generated synthetic.$extension ($codec)" >&2
}

generate mp3 libmp3lame -id3v2_version 0 -write_id3v1 0
generate flac flac
generate m4a aac
generate wav pcm_s16le
generate aiff pcm_s16be
if has_encoder libvorbis; then
  generate ogg libvorbis
else
  generate ogg vorbis -strict -2 -ac 2
fi
generate opus libopus
generate wv wavpack
generate tta tta
generate asf wmav2

if ! compgen -G "$fixtures/synthetic.*" >/dev/null; then
  echo 'No audio fixtures could be generated.' >&2
  exit 1
fi
printf '%s\n' "$fixtures"
