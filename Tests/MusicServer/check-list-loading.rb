require 'pathname'
root = Pathname.new(__dir__).join('../..').realpath
browse = root.join('Mobie/Mobie/Business/MusicServerModule/UI/MusicServerBrowseViewController.swift').read
loading = root.join('Mobie/Mobie/Business/MusicServerModule/UI/MusicServerLoadingView.swift').read
checks = 0
assert = lambda { |condition, message| raise message unless condition; checks += 1 }
assert.call(browse.include?('case .songs: return .songs') && browse.include?('case .albums: return .albums'), 'Both library song and album lists expose search')
assert.call(browse.include?('return .search(query: query, kind: kind)'), 'Search requests the entire server, never filters only loaded pages')
assert.call(browse.include?('guard didCompleteInitialLoad, searchKind != nil'), 'Search waits until initial loading succeeds')
assert.call(browse.include?('searchTextField.isEnabled = false') && browse.include?('searchTextField.isEnabled = true'), 'Disabled search is visibly represented before first response')
assert.call(browse.include?('Task.sleep(nanoseconds: 300_000_000)'), 'Typing is debounced')
assert.call(browse.include?('self.generation == requestGeneration') && browse.include?('pendingSearch?.cancel()'), 'Navigation/new queries invalidate old results')
assert.call(browse.include?('guard nextQuery != query || searchPending'), 'Editing back during debounce restarts the pending query')
assert.call(browse.include?('indexPath.row >= items.count - 6'), 'Load following pages automatically near the visible end')
assert.call(browse.include?('self.nextOffset > offset'), 'Reject non-advancing pagination')
assert.call(!browse.include?('MusicServerStatusCell') && !browse.include?('showsStatusRow'), 'No loading/empty placeholder rows')
assert.call(browse.include?('loadingView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor)'), 'Full-screen loading respects the navigation and mini-player safe area')
assert.call(loading.include?('.lineScalePulseOutRapid') && loading.include?('NVActivityIndicatorView'), 'Use the same animation as MusicsViewController')
assert.call(loading.include?('case .failed') && loading.include?('retryButton'), 'Failed full-screen loading remains recoverable')
puts "List loading/search UI contract checks passed (#{checks}); live navigation/search validation is still required."
