# Wakemusic 3.6.0 App Store descriptions

Approved Chinese copy, localized for the **39 locales already present in all four App Store Connect 3.6.0 drafts**. This is application-description metadata, not release notes or in-app purchase metadata.

## Sync completed

**2026-09-25 08:20:48 UTC:** saved and read back all **156 descriptions** (39 locales × 4 edition/platform targets). All matched the generated files. Every other localization attribute was unchanged. All four versions remained `PREPARE_FOR_SUBMISSION`; nothing was submitted for review or released.

| Target | Saved and verified |
|---|---:|
| Standard · iOS | 39 / 39 |
| Standard · macOS | 39 / 39 |
| Pro · iOS | 39 / 39 |
| Pro · macOS | 39 / 39 |

Longest description: 3,722 characters (Canadian French, standard edition). Offline validation: 648 assertions passed. Application code was not modified; additions are limited to metadata, synchronization tooling, tests and documentation.

Private `verified.json` SHA-256: `4f571b51d901ab39def0eef2b3694e9bac0b1d395eca7688493e866c26d11107`. Backups are retained locally in the ignored directory listed below; the original key file was not modified, and the temporary key copy was removed.

## Ready-to-paste text

- [Standard edition — Simplified Chinese](descriptions/standard/zh-Hans.txt)
- [Pro edition — Simplified Chinese](descriptions/pro/zh-Hans.txt)
- [Standard edition — US English](descriptions/standard/en-US.txt)
- [Pro edition — US English](descriptions/pro/en-US.txt)
- All other locales use the same filename convention under `descriptions/standard/` and `descriptions/pro/`.

Each edition has 39 plain-text descriptions. Both platforms use the same edition-specific description.

## Editorial rules

- Preserve `◆◆◆` section headings; use numbered items, restarting at 1 in each section. Do not use `●`.
- Use **Wakemusic** in every locale other than Simplified Chinese, including Traditional Chinese.
- The Simplified Chinese standard description preserves the approved wording with numbering changed. Other locales may use shorter equivalent wording to meet Apple's 4,000-character limit.
- Pro includes premium features without another subscription. Do not show the standard edition's subscription sales copy in Pro descriptions. Third-party fees remain separate.
- Keep caveats about file/tag compatibility, third-party access and charges, and spectrum analysis not proving lossless provenance.
- No promised future platforms/features, invented discounts, guaranteed recognition rates or unlimited third-party traffic.
- English regional variants reuse a neutral base, with British/Australian spelling adjustments. Canadian French and Mexican Spanish apply explicit regional wording changes; they are not English fallbacks.

## Legal pages

Verified the site's published alternate-language links and fetched all 24 privacy/terms pages successfully (HTTP 200): English, Simplified Chinese, Traditional Chinese, Japanese, Korean, German, French, Spanish, Brazilian Portuguese, Italian, Russian and Arabic.

Matching regional locales use those pages. Other locales link explicitly to the existing English pages. Portuguese (Portugal) uses English because the site only advertises Brazilian Portuguese. Both editions use the existing Wakemusic legal pages; no nonexistent Pro-specific URL is invented. These are links within the descriptions; this workflow does not modify the separate ASC privacy-policy metadata field.

## Source and generation

`source/` contains 34 translated base files. Each contains the shared body and separate `===STANDARD===` / `===PRO===` purchase sections. The generator produces 39 locale variants per edition, replacing the legal URL markers.

```sh
ruby Tools/AppStoreConnect/sync-app-descriptions.rb --render
ruby Tests/Purchase/check-app-descriptions.rb
```

Validation covers character counts (including UTF-16 length), brand names, all eight sections, sequential numbering, required features, rendered/source consistency, legal locale mappings and region-specific wording. Generated files contain no template markers.

## Fixed remote targets

| Edition | App ID | Platform | Version ID |
|---|---|---|---|
| Standard | 6544783918 | IOS | 026e2727-cc20-4253-87a7-0f634417fcb6 |
| Standard | 6544783918 | MAC_OS | 0209638f-4c7e-4b5f-adee-4668e6694b03 |
| Pro | 6740429002 | IOS | def01ea4-4428-4a7c-93f5-65708ddce621 |
| Pro | 6740429002 | MAC_OS | d963eab9-b3c4-49fa-8ef4-c9578d16eccb |

Before planning and writing, verify the exact app ID/bundle ID, parent ownership, platform, version `3.6.0`, `PREPARE_FOR_SUBMISSION` state and expected locale set. Apple's inverse `/appStoreVersions/{id}/app` endpoint is not readable for this resource; ownership is verified through `/apps/{id}/appStoreVersions` instead.

## Sync and safety

```sh
ruby Tools/AppStoreConnect/sync-app-descriptions.rb \
  --key-file /private/path/AuthKey.p8 \
  --key-id YOURKEYID1 \
  --issuer-id 00000000-0000-0000-0000-000000000000 \
  --output /private/path/new-description-backup
```

The default is read-only. Inspect `before.json` and `plan.json`. Add `--apply` with a **new** output directory to update the descriptions. The script never creates versions or languages, never deletes metadata, and never submits for review.

The only writable endpoint is `PATCH /v1/appStoreVersionLocalizations/{discovered-id}`; the only writable attribute is `description`. Before each write, re-read the localization and stop on concurrent changes. After writing, re-read all 156 records and verify all other localization attributes remain unchanged and all four versions remain editable drafts. An identical repeat makes no writes. Uncertain writes are not blindly retried: reconcile with a new dry-run.

The private key is loaded from the user-specified file using a temporary owner-only copy, removed immediately after in-memory parsing. The original file is not modified. Private key content and JWTs are never written to logs, source, manifests or backups. Backup directory mode is 0700; JSON files are 0600.

Local backup destination for this run: `outputs/asc-descriptions-3.6.0-20260925/`. Keep it private and out of Git. A successful run writes `verified.json`; partial execution is recorded in `completed.json`.

## Official references

- [Platform version information: description limit and plain-text format](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [Modify an App Store version localization](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-appstoreversionlocalizations-_id_)
- [ASC locale shortcodes](https://developer.apple.com/documentation/appstoreconnectapi/managing-metadata-in-your-app-by-using-locale-shortcodes)

Saving these descriptions does not publish them. Review submission and release remain separate user-controlled steps.
