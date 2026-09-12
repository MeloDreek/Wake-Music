#!/bin/bash
set -euo pipefail

task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="$(mktemp -d /private/tmp/wakemusic-guangya-tests.XXXXXX)"
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
  "$task_root/LocalSDK/AppGroupKit/Classes/CoreData/CloudDrive/GuangyaDriveModel.swift" \
  "$task_root/Mobie/Mobie/Base/Core/Extension/GuangyaDriveAPI.swift" \
  "$task_root/Mobie/Mobie/Business/ConnectModule/Model/GuangyaFileListStatus.swift" \
  "$task_root/Tests/Guangya/GuangyaRegression.swift" -o "$task_build/guangya-regressions"
"$task_build/guangya-regressions" "$task_root"
