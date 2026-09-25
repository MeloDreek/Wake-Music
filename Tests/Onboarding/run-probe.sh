#!/bin/bash
set -euo pipefail
onboarding_root="$(cd "$(dirname "$0")/../.." && pwd)"
onboarding_temp="$(mktemp -d /private/tmp/wake-onboarding-probe.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ruby - "$onboarding_root" "$onboarding_temp" <<'RUBY'
root, output = ARGV
paths = Dir[File.join(root, 'Mobie/Mobie/Business/OtherModule/LoginModule/Welcome*.swift')]
paths += Dir[File.join(root, 'LocalSDK/KakaUIKit/Classes/CustomUI/TagListView/*.swift')]
paths.each do |path|
  source = File.read(path).lines.reject { |line| line.start_with?('import ') && !['import UIKit', 'import Foundation', 'import SafariServices'].include?(line.strip) }.join
  File.write(File.join(output, File.basename(path)), source)
end
%w[ProbeSupport.swift OnboardingProbe.swift].each { |name| File.write(File.join(output, name), File.read(File.join(root, 'Tests/Onboarding', name))) }
RUBY
onboarding_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
target=arm64-apple-ios16.0-simulator
platform_flags=(-sdk "$onboarding_sdk")
if [ "${ONBOARDING_PLATFORM:-simulator}" = catalyst ]; then
  onboarding_sdk="$(xcrun --sdk macosx --show-sdk-path)"
  target=arm64-apple-ios16.0-macabi
  platform_flags=(-sdk "$onboarding_sdk" -F "$onboarding_sdk/System/iOSSupport/System/Library/Frameworks" -I "$onboarding_sdk/System/iOSSupport/usr/include" -L "$onboarding_sdk/System/iOSSupport/usr/lib")
fi
for variant in regular pro; do
  flags=(-D ONBOARDING_PROBE)
  if [ "$variant" = pro ]; then flags+=(-D Target_Mobie_Pro); fi
  xcrun swiftc -parse-as-library -swift-version 5 "${flags[@]}" "${platform_flags[@]}" -target "$target" \
    -module-cache-path "$onboarding_temp/modules" "$onboarding_temp/"*.swift -o "$onboarding_temp/test-$variant"
  if [ "${ONBOARDING_PLATFORM:-simulator}" = catalyst ]; then
    ONBOARDING_ROOT="$onboarding_root" ONBOARDING_OUTPUT="$onboarding_temp" "$onboarding_temp/test-$variant"
  else
    SIMCTL_CHILD_ONBOARDING_ROOT="$onboarding_root" SIMCTL_CHILD_ONBOARDING_OUTPUT="$onboarding_temp" \
    xcrun simctl spawn "${MUSIC_SERVER_SIMULATOR_UDID:-booted}" "$onboarding_temp/test-$variant"
  fi
done
echo "Onboarding renders: $onboarding_temp"
