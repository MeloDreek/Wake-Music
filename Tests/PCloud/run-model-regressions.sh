#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="$(mktemp -d /private/tmp/wakemusic-pcloud-tests.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

task_sources=()
while IFS= read -r -d '' task_source; do
  task_sources+=("$task_source")
done < <(rg --files -0 -g '*.swift' "$task_root/Pods/SmartCodable/Sources/SmartCodable")

xcrun --sdk macosx swiftc -swift-version 5 -emit-library -emit-module -module-name SmartCodable \
  -module-cache-path "$task_build/modules" \
  -emit-module-path "$task_build/SmartCodable.swiftmodule" \
  -o "$task_build/libSmartCodable.dylib" "${task_sources[@]}"

xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library \
  -module-cache-path "$task_build/modules" -I "$task_build" -L "$task_build" -lSmartCodable \
  -Xlinker -rpath -Xlinker "$task_build" \
  "$task_root/LocalSDK/AppGroupKit/Classes/Const/AudioExtension.swift" \
  "$task_root/LocalSDK/AppGroupKit/Classes/CoreData/CloudDrive/PCloudDriveModel.swift" \
  "$task_root/Tests/PCloud/PCloudModelRegression.swift" \
  -o "$task_build/pcloud-regressions"

"$task_build/pcloud-regressions"
