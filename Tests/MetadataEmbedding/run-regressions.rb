#!/usr/bin/env ruby
# Compile the production editor/operation files, with only their imports replaced
# by lightweight SDK/network/tag-store doubles. Never open a real music file.
require 'tmpdir'
require 'open3'

root = File.expand_path('../..', __dir__)
production = %w[MusicTagEditor+Embed.swift MusicTagEditorOperation.swift].map do |name|
  File.join(root, 'Mobie/Mobie/Base/Core/Tools', name)
end
inputs = [File.join(__dir__, 'EmbeddingStubs.swift'), *production,
          File.join(__dir__, 'EmbeddingRegression.swift')]
source = inputs.map do |path|
  File.read(path).lines.reject { |line| line.match?(/^import (KakaFoundation|WaketagLibKit|Kingfisher|AppGroupKit)$/) }.join
end.join("\n")

# The production controller uses UUID generations for both queued progress and
# completion, and invalidates the generation before cancelling its operations.
ui = File.read(File.join(root, 'Mobie/Mobie/Business/MusicModule/Controller/MusicsViewController+Delegate.swift'))
abort 'Missing batch progress generation guard' unless ui.include?('self.batchEmbeddingGeneration == generation, self.isBatchEditing')
abort 'Missing batch completion generation guard' unless ui.include?('wSelf.batchEmbeddingGeneration == generation, wSelf.isBatchEditing')
abort 'Cancellation must invalidate generation before cancelling work' unless ui.match?(/self\.batchEmbeddingGeneration = nil\s+self\.isBatchEditing = false\s+self\.tagEditor\.cancelBatchEmbeddedQueue\(\)/)

env = {}
env['DEVELOPER_DIR'] = '/Applications/Xcode.app/Contents/Developer' if !ENV['DEVELOPER_DIR'] && File.directory?('/Applications/Xcode.app/Contents/Developer')
sdk, status = Open3.capture2(env, 'xcrun', '--sdk', 'macosx', '--show-sdk-path')
abort 'A macOS Xcode toolchain is required' unless status.success?
Dir.mktmpdir('waketag-embedding.') do |dir|
  binary = File.join(dir, 'embedding-regressions')
  out, err, compiled = Open3.capture3(env, 'xcrun', 'swiftc', '-sdk', sdk.strip,
    '-module-cache-path', File.join(dir, 'ModuleCache'), '-swift-version', '5',
    '-parse-as-library', '-o', binary, '-', stdin_data: source)
  print out
  warn err unless err.empty?
  abort 'Embedding regression compilation failed' unless compiled.success?
  success = system(env.merge('EMBEDDING_TEST_DIR' => dir), binary)
  abort 'Embedding regression checks failed' unless success
end
