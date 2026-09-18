#!/bin/bash
set -euo pipefail
purchase_root="$(cd "$(dirname "$0")/../.." && pwd)"
purchase_build="$(mktemp -d /private/tmp/wake-purchase-layout.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby - "$purchase_root" "$purchase_build" <<'RUBY'
root, output = ARGV
cell = File.read(File.join(root, 'Mobie/Mobie/Business/OtherModule/ProfileModule/View/PurchasePriceCell.swift'))
cell = cell.gsub(/^import .*\n/, '').sub('class PurchasePriceCell:', 'private class PurchasePriceCell:')
probe = File.read(File.join(root, 'Tests/Purchase/PriceCellLayoutProbe.swift'))
File.write(File.join(output, 'PriceCellProbe.swift'), probe + "\n" + cell)
RUBY
purchase_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
xcrun swiftc -parse-as-library -swift-version 5 -target arm64-apple-ios16.0-simulator -sdk "$purchase_sdk" \
  -module-cache-path "$purchase_build/modules" "$purchase_build/PriceCellProbe.swift" -o "$purchase_build/probe"
# Example: bash Tests/Purchase/run-price-cell-layout.sh --render /private/tmp/purchase-cells.png
# Without an explicit destination this remains an assertion-only probe.
if [[ "${1:-}" == "--render" && -n "${2:-}" ]]; then
  xcrun simctl spawn "${PURCHASE_SIMULATOR_UDID:-booted}" "$purchase_build/probe" --render "$2"
elif [[ -n "${PURCHASE_LAYOUT_RENDER_PATH:-}" ]]; then
  xcrun simctl spawn "${PURCHASE_SIMULATOR_UDID:-booted}" "$purchase_build/probe" --render "$PURCHASE_LAYOUT_RENDER_PATH"
else
  xcrun simctl spawn "${PURCHASE_SIMULATOR_UDID:-booted}" "$purchase_build/probe"
fi
