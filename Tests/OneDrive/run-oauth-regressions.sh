#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="$(mktemp -d /private/tmp/wakemusic-onedrive-oauth.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# Compile the production client directly. URLProtocol intercepts every request;
# no account, real credentials, Keychain item or remote service is accessed.
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$task_build/modules" \
  "$task_root/Mobie/Mobie/Base/Core/Extension/OneDriveOAuthClient.swift" \
  "$task_root/Tests/OneDrive/oauth-check.swift" \
  -o "$task_build/onedrive-oauth-regressions"
"$task_build/onedrive-oauth-regressions"
