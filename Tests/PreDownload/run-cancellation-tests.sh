#!/bin/bash
set -euo pipefail
task_root="$(cd "$(dirname "$0")/../.." && pwd)"
task_build="$(mktemp -d /private/tmp/wake-download-cancel.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby -e 's=File.read(ARGV[0]); gate=s.split("// BEGIN DOWNLOAD COMMIT GATE",2).last.split("// END DOWNLOAD COMMIT GATE",2).first; File.write(ARGV[1], "import Foundation\n"+gate)' \
 "$task_root/Mobie/Mobie/Business/ImportModule/Controller/DownloadManager+Tasks.swift" "$task_build/Gate.swift"
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library -module-cache-path "$task_build/modules" \
 "$task_build/Gate.swift" "$task_root/Tests/PreDownload/DownloadCancellationTests.swift" -o "$task_build/check"
"$task_build/check"
