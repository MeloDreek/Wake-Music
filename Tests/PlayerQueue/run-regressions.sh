#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="$(mktemp -d /private/tmp/wakemusic-queue-tests.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -module-cache-path "$task_build/modules" -parse-as-library \
  "$task_root/Mobie/Mobie/Base/Music/PlaybackQueue.swift" \
  "$task_root/Tests/PlayerQueue/QueueRegression.swift" -o "$task_build/queue-regression"
"$task_build/queue-regression"
