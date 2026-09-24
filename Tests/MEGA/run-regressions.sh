#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_sdk="${MEGASDK_ROOT:-$task_root/LocalSDK/MEGASDK}"
if [ ! -f "$task_sdk/src/apple_natural_sort.h" ]; then
    echo "Shared MEGASDK not found: $task_sdk. Set MEGASDK_ROOT if it is stored elsewhere." >&2
    exit 1
fi
task_build="$(mktemp -d /private/tmp/wakemusic-mega-tests.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
task_sources=()
while IFS= read -r -d '' task_source; do task_sources+=("$task_source"); done < <(rg --files -0 -g '*.swift' "$task_root/Pods/SmartCodable/Sources/SmartCodable")
xcrun --sdk macosx swiftc -swift-version 5 -emit-library -emit-module -module-name SmartCodable \
  -module-cache-path "$task_build/modules" -emit-module-path "$task_build/SmartCodable.swiftmodule" \
  -o "$task_build/libSmartCodable.dylib" "${task_sources[@]}"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$task_build/modules" -I "$task_build" -L "$task_build" -lSmartCodable \
  -Xlinker -rpath -Xlinker "$task_build" \
  "$task_root/LocalSDK/AppGroupKit/Classes/Const/AudioExtension.swift" \
  "$task_root/LocalSDK/AppGroupKit/Classes/CoreData/CloudDrive/MEGADriveModel.swift" \
  "$task_root/Mobie/Mobie/Business/ConnectModule/Model/MEGAFileListStatus.swift" \
  "$task_root/Tests/MEGA/MEGARegression.swift" -o "$task_build/mega-regressions"
"$task_build/mega-regressions"
xcrun --sdk macosx clang++ -std=c++17 -framework CoreFoundation -I "$task_sdk/src" \
  "$task_root/Tests/MEGA/MEGANaturalSortRegression.cpp" -o "$task_build/mega-sort-regressions"
"$task_build/mega-sort-regressions"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$task_build/modules" \
  "$task_root/Mobie/Mobie/Base/Core/Extension/MEGASystemProxy.swift" \
  "$task_root/Tests/MEGA/MEGAProxyRegression.swift" -o "$task_build/mega-proxy-regressions"
"$task_build/mega-proxy-regressions"
