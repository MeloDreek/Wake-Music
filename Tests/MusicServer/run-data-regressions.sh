#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h:h}"
test_dir=$(mktemp -d /private/tmp/wakemusic-server-data.XXXXXX)
trap 'rm -f "$test_dir/data-tests"; rmdir "$test_dir"' EXIT
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc \
  -module-cache-path /private/tmp/wake-server-data-modules \
  "$project_root/Mobie/Mobie/Business/MusicServerModule/Data/MusicServerWire.swift" \
  "$project_root/Tests/MusicServer/DataRegression.swift" \
  -o "$test_dir/data-tests"
"$test_dir/data-tests"
