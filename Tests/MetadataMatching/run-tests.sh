#!/bin/bash
set -euo pipefail
metadata_root="$(cd "$(dirname "$0")/../.." && pwd)"
metadata_build="$(mktemp -d /private/tmp/wake-metadata-tests.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Extract the production Foundation-only actor, not a second test implementation.
ruby -e 's=File.read(ARGV[0]); core=s[/actor AppleCatalogMetadataService.*?(?=\nextension AudioFingerprintMatcher)/m]; abort "actor missing" unless core; File.write(ARGV[1], "import Foundation\n" + core)' \
  "$metadata_root/Mobie/Mobie/Base/Core/Tools/AppleCatalogMetadataService.swift" "$metadata_build/CatalogService.swift"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$metadata_build/modules" \
  "$metadata_root/Mobie/Mobie/Base/Core/Tools/CatalogMetadataMatcher.swift" \
  "$metadata_build/CatalogService.swift" "$metadata_root/Tests/MetadataMatching/CatalogMatchingTests.swift" -o "$metadata_build/catalog-tests"
"$metadata_build/catalog-tests" "$@"
printf 'Test artifacts: %s\n' "$metadata_build"
