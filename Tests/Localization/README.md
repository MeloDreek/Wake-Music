# Legacy English-key localization review

## Scope

The September 2026 review covers all 625 English-word/sentence keys in
`Mobie/Mobie/System/Localizable.xcstrings`, across 42 language/region variants.
It does not rename lookup keys, edit application logic, or modify
`InfoPlist.xcstrings`. Namespaced keys such as `EQ.*`, `Queue.*`, `SMB.*`, and
`Guangya.*`, along with URL keys, are excluded. Existing accurate translations
are retained rather than changed just to produce a diff.

Review context comes from Swift call sites, including settings, playback,
metadata editing, file access, import, authentication, and purchase screens.
English display copy may intentionally differ from its legacy lookup key.
For example:

- `Rate` means playback speed, not a rating or a price.
- `Dislike` removes a song from favorites; it does not blacklist the song.
- `Subscribing` is an active subscription status, not a purchase in progress.
- `Clear All Cache` is used to clear saved file references, not audio files.
- `Super Lossless` labels the DSD/DSF/DFF format group.

Long descriptions were also checked against implementation. Notable corrections
include the power-saving switch (less frequent lyric updates, not 1,000 UI
refreshes per second), the distinction between a cloud account and its saved
connection, and lossless audio/metadata terminology. Prices, format arguments,
entitlements, and lookup keys are preserved.

## Validation

Run the catalog regression checks:

```sh
ruby Tests/Localization/check-legacy-catalog.rb
ruby Tests/MusicServer/run-localization-regressions.rb
ruby Tests/ImportLocalization/run-regressions.rb
```

The first test checks locale coverage, translation state, nonempty text,
invalid characters, positional printf arguments, and several important
context-sensitive translations. Source English can fall back to the key when
no explicit `en` translation is needed.

To check a revision against a pre-review snapshot, pass its path:

```sh
ruby Tests/Localization/check-legacy-catalog.rb --before /path/to/original.xcstrings
```

This additionally verifies that no keys or existing locales disappeared and
that excluded records and key metadata did not change.

Compile with Xcode's `xcstringstool`, using a temporary output directory:

```sh
localization_output=$(mktemp -d /private/tmp/wake-localization-compile.XXXXXX)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun xcstringstool compile \
  Mobie/Mobie/System/Localizable.xcstrings --output-directory "$localization_output"
ruby Tests/Localization/check-legacy-catalog.rb --compiled-directory "$localization_output"
```

The compiled check reads every generated language table and compares all 625
scoped keys with their expected display strings. This validates localization
build products; it is not a full application build or a visual layout test.
