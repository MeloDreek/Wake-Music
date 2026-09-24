# Safe metadata embedding regressions

Run on macOS with Xcode installed:

```sh
ruby Tests/MetadataEmbedding/run-regressions.rb
```

The runner compiles the actual `MusicTagEditor+Embed.swift` and
`MusicTagEditorOperation.swift`. Only imports are replaced by Foundation-based
test doubles for the app, image download/cache, recognition, and TagLib. This is
a deterministic test of the editor's write decisions and operation lifecycle,
not a substitute for the native TagLib file-format regressions or an app build.
No existing music is read, written, renamed, or downloaded. The rename check uses
a newly generated, non-audio disposable file. Builds use a fresh temporary
directory. `DEVELOPER_DIR` may select an installed Xcode toolchain.

Coverage includes stale model versus on-disk tags, fill-missing and overwrite,
blank text and integer bounds, catalog fallback protection, changes appearing
during artwork download, unreadable files and failed saves, explicit instrumental
fallback without replacing existing lyrics, persisted-model/cache refresh,
task cancellation before/during commit, queued/pre-enqueue cancellation, a
64-operation cancelled batch, exactly-once completion, path/bookmark updates,
and late recognition callbacks after cancellation. The runner also checks the
controller's generation guards for stale batch progress/completion and quota UI.
