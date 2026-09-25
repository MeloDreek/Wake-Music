#!/bin/bash
# Repair the vendored curl 8.1.2 Intel Catalyst slice without changing other slices.
# Usage: DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer bash tools/wake-rebuild-curl-catalyst.sh [curl-8.1.2.tar.xz]
set -euo pipefail
sdk_root="$(cd "$(dirname "$0")/.." && pwd)"
repair_dir="$(mktemp -d /private/tmp/wake-mega-curl.XXXXXX)"
curl_archive="${1:-$repair_dir/curl-8.1.2.tar.xz}"
if [ "$#" = 0 ]; then
  /usr/bin/curl --fail --location --retry 2 --connect-timeout 20 --max-time 600 \
    https://curl.se/download/curl-8.1.2.tar.xz --output "$curl_archive"
fi
expected_sha=31b1118eb8bfd43cd95d9a3f146f814ff874f6ed3999b29d94f4d1e7dbac5ef6
test "$(shasum -a 256 "$curl_archive" | awk '{print $1}')" = "$expected_sha"
tar -xf "$curl_archive" -C "$repair_dir"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
export CC="$(xcrun --find clang)"
export CFLAGS="-Os -target x86_64-apple-ios15.0-macabi -isysroot $sdk_path"
export CPPFLAGS="$CFLAGS -DNDEBUG"
export LDFLAGS="-target x86_64-apple-ios15.0-macabi -isysroot $sdk_path"
# Do not silently discover the build machine's Homebrew libraries.
export PKG_CONFIG=false
export PKG_CONFIG_LIBDIR="$repair_dir/no-pkg-config"
unset LIBRARY_PATH CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH SDKROOT || true
cd "$repair_dir/curl-8.1.2"
./configure --host=x86_64-apple-darwin --build="$(./config.guess)" \
  --prefix="$repair_dir/install" --enable-static --disable-shared \
  --with-secure-transport --without-openssl --with-zlib \
  --without-nghttp2 --without-nghttp3 --without-ngtcp2 --without-quiche \
  --without-libidn2 --without-libpsl --without-brotli --without-zstd \
  --without-libssh2 --without-libssh --without-librtmp --without-gssapi \
  --disable-manual --disable-ftp --disable-file --disable-ldap --disable-ldaps \
  --disable-rtsp --disable-dict --disable-telnet --disable-tftp --disable-pop3 \
  --disable-imap --disable-smtp --disable-gopher --disable-sspi --disable-smb --enable-ipv6
make -C lib -j"$(sysctl -n hw.ncpu)"
new_slice="$repair_dir/curl-8.1.2/lib/.libs/libcurl.a"
xcrun nm -u "$new_slice" > "$repair_dir/undefined-symbols.txt"
if grep -Eq ' U _(nghttp2_|idn2_)' "$repair_dir/undefined-symbols.txt"; then
  echo 'Unexpected unbundled dependency in rebuilt curl' >&2
  exit 1
fi
installed_library="$sdk_root/.artifacts/libcurl.xcframework/ios-arm64_x86_64-maccatalyst/libcurl.a"
cp "$installed_library" "$repair_dir/libcurl-original.a"
xcrun lipo "$installed_library" -replace x86_64 "$new_slice" -output "$repair_dir/libcurl-universal.a"
xcrun lipo "$repair_dir/libcurl-universal.a" -thin arm64 -output "$repair_dir/arm64-after.a"
xcrun lipo "$installed_library" -thin arm64 -output "$repair_dir/arm64-before.a"
cmp "$repair_dir/arm64-before.a" "$repair_dir/arm64-after.a"
xcrun lipo "$repair_dir/libcurl-universal.a" -thin x86_64 -output "$repair_dir/x86_64-after.a"
cmp "$new_slice" "$repair_dir/x86_64-after.a"
install -m 644 "$repair_dir/libcurl-universal.a" "$installed_library"
echo "Rebuilt Intel Catalyst curl; arm64 retained. Backup and build log inputs: $repair_dir"
