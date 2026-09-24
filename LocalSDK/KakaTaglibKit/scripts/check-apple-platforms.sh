#!/bin/bash
set -euo pipefail

PACKAGE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

BUILD_ROOT="${BUILD_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/WaketagLibKit-platforms.XXXXXX")}"
JOBS="${JOBS:-4}"
WORKSPACE="$BUILD_ROOT/WaketagLibKit.xcworkspace"
mkdir -p "$WORKSPACE"

# Escape the checkout path so spaces, non-ASCII text, and XML metacharacters work.
/usr/bin/ruby -rcgi -e '
  package_root, workspace_path = ARGV
  File.write(File.join(workspace_path, "contents.xcworkspacedata"),
    %(<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0">\n<FileRef location="absolute:#{CGI.escapeHTML(package_root)}"/>\n</Workspace>\n))
' "$PACKAGE_ROOT" "$WORKSPACE"

build_platform() {
    local label="$1" destination="$2" sdk="$3"
    local log="$BUILD_ROOT/$label.log"
    printf 'Building %s...\n' "$label"
    if ! xcodebuild -workspace "$WORKSPACE" -scheme WaketagLibKit \
        -destination "$destination" -sdk "$sdk" \
        -derivedDataPath "$BUILD_ROOT/matrix-$label" -jobs "$JOBS" \
        CODE_SIGNING_ALLOWED=NO build -quiet > "$log" 2>&1; then
        tail -n 80 "$log"
        printf 'FAILED: %s. Full log: %s\n' "$label" "$log" >&2
        return 1
    fi
    printf 'PASS: %s\n' "$label"
}

build_platform macOS 'generic/platform=macOS' macosx
build_platform iOS 'generic/platform=iOS' iphoneos
build_platform Catalyst 'generic/platform=macOS,variant=Mac Catalyst' macosx
build_platform tvOS 'generic/platform=tvOS' appletvos
build_platform watchOS 'generic/platform=watchOS' watchos
printf 'All five platform builds passed. Logs and artifacts: %s\n' "$BUILD_ROOT"
