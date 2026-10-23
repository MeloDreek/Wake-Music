#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="$(mktemp -d /private/tmp/wakemusic-onedrive-platform.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# This is deliberately isolated from the full app and its keyboard SDK. These
# business-only modules preserve type signatures, not application behavior.
# All Apple frameworks, availability checks and final library linking are real.
for task_platform in catalyst ios; do
  task_output="$task_build/$task_platform"
  mkdir -p "$task_output"
  task_flags=()
  if [[ "$task_platform" == catalyst ]]; then
    task_sdk_name=macosx
    task_sdk="$(xcrun --sdk macosx --show-sdk-path)"
    task_target="arm64-apple-ios16.0-macabi"
    task_flags+=(-F "$task_sdk/System/iOSSupport/System/Library/Frameworks")
  else
    task_sdk_name=iphoneos
    task_sdk="$(xcrun --sdk iphoneos --show-sdk-path)"
    task_target="arm64-apple-ios16.0"
  fi
  task_flags+=(-swift-version 5 -parse-as-library -sdk "$task_sdk" -target "$task_target")
  task_flags+=(-module-cache-path "$task_output/modules")
  for task_module in AppGroupKit KakaFoundation KakaUIKit; do
    xcrun --sdk "$task_sdk_name" swiftc "${task_flags[@]}" -emit-library -emit-module -module-name "$task_module" \
      -emit-module-path "$task_output/$task_module.swiftmodule" \
      "$task_root/Tests/OneDrive/PlatformCompileStubs/$task_module.swift" \
      -o "$task_output/lib$task_module.dylib"
  done
  xcrun --sdk "$task_sdk_name" swiftc "${task_flags[@]}" -emit-library -emit-module -module-name OneDrivePlatformCompatibility \
    -emit-module-path "$task_output/OneDrivePlatformCompatibility.swiftmodule" \
    -I "$task_output" -L "$task_output" -lAppGroupKit -lKakaFoundation -lKakaUIKit \
    "$task_root/Mobie/Mobie/Base/Core/Extension/OneDriveOAuthClient.swift" \
    "$task_root/Mobie/Mobie/Base/Core/Extension/OneDriveOAuthManager.swift" \
    -o "$task_output/libOneDrivePlatformCompatibility.dylib"
  printf 'PASS: OneDrive production client/manager compiled and linked for %s (business stubs, real Apple SDK)\n' "$task_target"
done
printf 'Isolated compile artifacts: %s\n' "$task_build"
