#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="$(mktemp -d /private/tmp/wakemusic-pcloud-status.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# The real presentation state is platform-independent; UIKit is excluded on macOS.
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$task_build/modules" \
  "$task_root/Mobie/Mobie/Business/ConnectModule/Controller/PCloudFileListStatus.swift" \
  "$task_root/Tests/PCloud/PCloudStatusRegression.swift" \
  -o "$task_build/pcloud-status-regressions"

"$task_build/pcloud-status-regressions" "$task_root/Mobie/Mobie/System/Localizable.xcstrings"
