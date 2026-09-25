#!/bin/bash
set -euo pipefail
design_root="$(cd "$(dirname "$0")/../.." && pwd)"
design_build="$(mktemp -d /private/tmp/wake-design-renderer.XXXXXX)"
design_artifacts="$design_root/outputs/AppStore-3.6.0-zh-Hans-v1"
design_input="${1:-$design_artifacts/design.html}"
design_output="${2:-$design_artifacts/final}"
design_preview="${3:-$design_artifacts/preview.png}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/kaka/Desktop/Xcode.app/Contents/Developer}"
design_sdk="$(xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-macosx13.0 \
  -sdk "$design_sdk" -module-cache-path "$design_build/modules" \
  "$design_root/Tools/AppStoreScreenshots/render-design.swift" \
  -framework AppKit -framework WebKit -o "$design_build/render-design"
if [[ "${DESIGN_RENDER_BUILD_ONLY:-0}" == "1" ]]; then
  printf '%s\n' "$design_build/render-design"
  exit 0
fi
"$design_build/render-design" "$design_input" "$design_output" "$design_preview"
