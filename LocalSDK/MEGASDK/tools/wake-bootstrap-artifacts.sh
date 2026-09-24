#!/bin/bash
set -euo pipefail
task_sdk="$(cd "$(dirname "$0")/.." && pwd)"
task_cache="${MEGA_DOWNLOAD_CACHE:-$task_sdk/.downloads}"
mkdir -p "$task_cache" "$task_sdk/.artifacts"
while read -r task_lib task_hash; do
    task_zip="$task_cache/wakemusic-mega-$task_lib.zip"
    task_actual=""
    if [ -f "$task_zip" ]; then task_actual="$(shasum -a 256 "$task_zip" | cut -d ' ' -f 1)"; fi
    if [ "$task_actual" != "$task_hash" ]; then
        curl --fail --location --continue-at - --connect-timeout 15 --max-time 3600 \
            "https://s3.g.s4.mega.io/dmlaaezwz52y37atz56mfvmrvltfagrltbgpr/xcframeworks-macos-support/$task_lib.xcframework.zip" -o "$task_zip"
    fi
    task_actual="$(shasum -a 256 "$task_zip" | cut -d ' ' -f 1)"
    if [ "$task_actual" != "$task_hash" ]; then
        echo "Checksum mismatch for $task_lib; refusing to install." >&2
        exit 1
    fi
    ditto -x -k "$task_zip" "$task_sdk/.artifacts"
    echo "Verified $task_lib"
done <<'MEGA_DEPENDENCIES'
libcryptopp f7483596a4a682fbdf38a2a0c919c6407bdbd8c4f3cef1877c105820ae9f9896
libcurl ab3c685d9c20bf22a8f63105bbe3410bf06edf10d3f164a59a81c5bb0a0e4dd3
libsodium edf385ce2b693f864a5879559c9e61c84d4209e62e3e6e37bcd01cd23c0c311c
libuv 97e387c71773766d0673634a3688550226b0ca5ea0ce0fb0c4a66a7e99ddb6a7
libmediainfo d6fa1c5feb6282057a9b4313e77dec9a4d40d5b4a49c62a6e209fb46951a351c
libzen 520bd9579d6174c7e4b2eb989b48429961e6bb10e057119db17f8967dfe9b5a2
MEGA_DEPENDENCIES
