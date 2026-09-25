#!/bin/bash
set -euo pipefail
lyric_root="$(cd "$(dirname "$0")/../.." && pwd)"
lyric_cache="$(mktemp -d /private/tmp/wake-lyric-ai-tests.XXXXXX)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Users/kaka/Desktop/Xcode.app/Contents/Developer}"
# Compile the real Foundation-only provider block, not a duplicate test model.
ruby -e '
  root = ARGV.fetch(0)
  source = File.read(File.join(root, "Mobie/Mobie/Business/MusicModule/Controller/LyricEditorViewController.swift"))
  model = source[/^enum LyricAIProvider:.*?(?=^private final class LyricAISearchCell)/m]
  abort "Missing production provider model" unless model
  puts "import Foundation"
  puts model
  puts File.read(File.join(root, "Tests/LyricAI/regressions.swift"))
' "$lyric_root" | xcrun swift -module-cache-path "$lyric_cache" - "$lyric_root"
