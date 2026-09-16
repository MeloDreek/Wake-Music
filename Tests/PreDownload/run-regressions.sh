#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="$(mktemp -d /private/tmp/wakemusic-predownload-tests.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# Compile the production helper unchanged, without requiring UIKit on the host.
ruby -e 'source=File.read(ARGV[0]); helper=source.split("public enum PreDownloadedAudioFile {",2).last.split("\nextension SandboxFileManager {",2).first; File.write(ARGV[1], "import Foundation\nimport Darwin\npublic enum PreDownloadedAudioFile {"+helper)' \
 "$task_root/LocalSDK/AppGroupKit/Classes/CoreManager/Sandbox/SandboxFileManager+Music.swift" "$task_build/PreDownloadedAudioFile.swift"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$task_build/modules" \
 "$task_build/PreDownloadedAudioFile.swift" "$task_root/Tests/PreDownload/PreDownloadRegression.swift" -o "$task_build/regressions"
"$task_build/regressions"
