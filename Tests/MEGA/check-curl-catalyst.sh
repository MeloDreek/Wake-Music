#!/bin/bash
set -euo pipefail
test_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_sdk="$(xcrun --sdk macosx --show-sdk-path)"
test_curl="$test_root/LocalSDK/MEGASDK/.artifacts/libcurl.xcframework/ios-arm64_x86_64-maccatalyst"
test_output="$(mktemp -d /private/tmp/wake-curl-link.XXXXXX)"
for test_arch in arm64 x86_64; do
    xcrun clang -target "$test_arch-apple-ios15.0-macabi" -isysroot "$test_sdk" \
        -I "$test_curl/Headers" "$test_root/Tests/MEGA/CurlCatalystLinkProbe.c" \
        -Xlinker -force_load -Xlinker "$test_curl/libcurl.a" \
        -framework Security -framework CoreFoundation -lz \
        -o "$test_output/curl-$test_arch"
    echo "PASS full archive linkage: $test_arch"
done
"$test_output/curl-arm64"
echo "Probes: $test_output"
