# Import sections and media-library removal

Run the source/catalog regression check:

```sh
ruby Tests/ImportLocalization/run-regressions.rb
```

Pass an absolute path to a built `.app` as an optional argument to also inspect its Info.plist, localized permission tables, and compiled Local/Remote headings. Build `Mobie` and `Mobie_Pro` sequentially: they share the `Wakemusic.app` output path.

The import screen has two groups, Local and Remote. USB/Wi-Fi remain in Local on iOS and retain their existing Catalyst conditional. Remote combines server and cloud providers. The Apple Music media-library import, media-library authorization, artwork asset, enum case, and player override are retired. An old `ipod-library` last-play record is ignored during player restoration; this does not delete audio files. Shazam's Apple Music result links, ALAC/AVPlayer explanations, and MediaPlayer lock-screen controls are unrelated and remain.

The string catalogs cover the existing 42 locales. English source keys may omit an explicit `en` translation; URLs marked nontranslatable are excluded. New regional English, Spanish, French and Hong Kong entries reuse the appropriate base translation where applicable.

Before release, manually inspect Import on iOS and Mac Catalyst with English, Simplified/Traditional Chinese, RTL and larger text. This script checks catalog and source contracts, not visual layout or a live legacy-account migration.
