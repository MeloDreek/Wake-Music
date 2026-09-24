#!/bin/bash
# Standalone macOS build; no CocoaPods, SwiftPM, CMake, or header maps required.
set -euo pipefail

kit_root=$(cd "$(dirname "$0")/.." && pwd)
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
sdk=$(xcrun --sdk macosx --show-sdk-path)
compiler=$(xcrun --sdk macosx --find clang++)
ffmpeg=${FFMPEG:-/opt/homebrew/bin/ffmpeg}
if [[ ! -x "$ffmpeg" ]]; then
  ffmpeg=$(command -v ffmpeg || true)
fi
if [[ -z "$ffmpeg" || ! -x "$ffmpeg" ]]; then
  echo 'ffmpeg is required to generate and validate synthetic fixtures.' >&2
  exit 1
fi
export FFMPEG="$ffmpeg"
build_root=$(mktemp -d "${TMPDIR:-/tmp}/WaketagLibKit-regression.XXXXXX")
echo "Regression artifacts: $build_root"
echo 'Artifacts are retained for inspection; tests only mutate temporary fixture copies.'

common=(-std=c++17 -g -O1 -fno-omit-frame-pointer -DTAGLIB_STATIC
  -DHAVE_ZLIB -isysroot "$sdk" -mmacosx-version-min=12.0)
if [[ ${SANITIZE:-1} != 0 ]]; then
  common+=(-fsanitize=address,undefined)
fi
includes=(-I "$kit_root/Classes/TagLibHeader")
while IFS= read -r directory; do
  includes+=(-I "$directory")
done < <(find "$kit_root/Classes/TagLib" -type d | LC_ALL=C sort)

objects=()
pids=()
jobs=${JOBS:-8}
if ! [[ "$jobs" =~ ^[1-9][0-9]*$ ]]; then
  echo 'JOBS must be a positive integer.' >&2
  exit 1
fi

wait_batch() {
  local failed=0 pid
  for pid in "${pids[@]}"; do
    wait "$pid" || failed=1
  done
  pids=()
  if [[ $failed != 0 ]]; then
    echo "Compilation failed. Artifacts retained at $build_root" >&2
    exit 1
  fi
}

index=0
while IFS= read -r -d '' source; do
  object="$build_root/taglib-$index.o"
  objects+=("$object")
  "$compiler" "${common[@]}" "${includes[@]}" -c "$source" -o "$object" &
  pids+=($!)
  index=$((index + 1))
  if [[ ${#pids[@]} -ge $jobs ]]; then
    wait_batch
  fi
done < <(find "$kit_root/Classes/TagLib" -name '*.cpp' -type f -print0)
if [[ ${#pids[@]} -gt 0 ]]; then
  wait_batch
fi

for source in "$kit_root"/Classes/TagLibHeader/*.mm "$kit_root/Tests/TaglibRegressionTests.mm"; do
  object="$build_root/wrapper-$index.o"
  objects+=("$object")
  "$compiler" "${common[@]}" "${includes[@]}" -fobjc-arc -fblocks \
    -c "$source" -o "$object"
  index=$((index + 1))
done

"$compiler" "${common[@]}" "${objects[@]}" -framework Foundation \
  -framework AppKit -framework ImageIO -lz -o "$build_root/taglib-regression"
fixtures=$(bash "$kit_root/scripts/generate-regression-fixtures.sh" "$build_root")
audio_files=("$fixtures"/synthetic.*)
audio_hashes=()
decoded_audio_hash() {
  "$ffmpeg" -nostdin -v error -i "$1" -map 0:a:0 -c:a pcm_s16le \
    -f hash -hash sha256 -
}
for audio in "${audio_files[@]}"; do
  audio_hashes+=("$(decoded_audio_hash "$audio")")
done
export ASAN_OPTIONS=${ASAN_OPTIONS:-detect_leaks=0:halt_on_error=1}
export UBSAN_OPTIONS=${UBSAN_OPTIONS:-halt_on_error=1:print_stacktrace=1}
"$build_root/taglib-regression" "$fixtures"
for ((index = 0; index < ${#audio_files[@]}; ++index)); do
  audio=${audio_files[index]}
  if [[ $(decoded_audio_hash "$audio") != "${audio_hashes[index]}" ]]; then
    echo "FAIL decoded audio changed: $audio" >&2
    exit 1
  fi
done
echo "PASS decoded audio unchanged in all ${#audio_files[@]} formats"

if [[ -n ${TAGLIB_TEST_DATA:-} ]]; then
  corpus=$(bash "$kit_root/scripts/prepare-upstream-fixtures.sh" "$TAGLIB_TEST_DATA" "$build_root")
  corpus_files=(empty10ms.dsf empty10ms.dff click.mpc mac-399.ape no-tags.mka)
  corpus_hashes=()
  for audio in "${corpus_files[@]}"; do
    if digest=$(decoded_audio_hash "$corpus/$audio" 2>"$build_root/decode-$audio.log"); then
      corpus_hashes+=("$digest")
    else
      corpus_hashes+=("")
      echo "SKIP decoded audio comparison: ffmpeg cannot decode $audio (see decode-$audio.log)"
    fi
  done
  "$build_root/taglib-regression" "$corpus" --upstream
  verified=0
  for ((index = 0; index < ${#corpus_files[@]}; ++index)); do
    if [[ -z ${corpus_hashes[index]} ]]; then continue; fi
    audio=${corpus_files[index]}
    if [[ $(decoded_audio_hash "$corpus/$audio") != "${corpus_hashes[index]}" ]]; then
      echo "FAIL decoded upstream audio changed: $audio" >&2
      exit 1
    fi
    verified=$((verified + 1))
  done
  echo "PASS decoded audio unchanged in $verified upstream fixtures"
fi
