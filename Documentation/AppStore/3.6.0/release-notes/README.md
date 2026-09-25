# 3.6.0 release notes

Localized from the user's supplied nine-point major-update list, using the same 39 ASC locales and four editable 3.6.0 targets as the [application descriptions](../README.md).

## Saved and verified

Completed **2026-09-25 08:37:30 UTC**: all **156 `whatsNew` values** were saved and read back successfully (39 locales each for Standard iOS, Standard macOS, Pro iOS and Pro macOS). All other localization attributes were unchanged. An independent check also confirmed all 156 descriptions still match the previously approved description catalog.

All four targets remain `PREPARE_FOR_SUBMISSION`. No review submission or release was performed. The longest release note is 818 characters. Offline checks passed 1,914 assertions, including the existing description-sync regressions.

Private `verified.json` SHA-256: `63e4a017f5a96685084aef527ba98c54b27da7627dbaab4edb43c664bef43a40`.

## Text files

- [Simplified Chinese — iOS](ios/zh-Hans.txt)
- [Simplified Chinese — macOS](mac_os/zh-Hans.txt)
- [US English — iOS](ios/en-US.txt)
- [US English — macOS](mac_os/en-US.txt)

Other locale files follow the same naming convention. Standard and Pro use the same release notes for a given platform. iOS has nine numbered items. macOS has eight: the iOS 27.1/iPhone Duo compatibility note is intentionally omitted, not replaced with an invented macOS feature.

The `◆◆◆` heading, numbered list and contact address are preserved. Grammar is polished without adding numerical recognition-rate claims. All eight new services/protocols are retained: pCloud, Box, MEGA, Yandex Disk, SMB, FTP, 123 and Guangya. ASC stores plain text; the contact email is not Markdown or a `mailto:` link.

`source.json` holds 34 base-language entries. English regional variants and Mexican Spanish use wording suitable for both regions; Canadian French has explicit local wording adjustments. Generated output contains 39 files per platform (78 files). No Chinese app branding is inserted into non-Simplified-Chinese locales.

## Generate and check

```sh
ruby Tools/AppStoreConnect/sync-release-notes.rb --render
ruby Tests/Purchase/check-release-notes.rb
```

Validation includes all services, support address, language coverage, item counts, platform-specific text, character limits and source/rendered consistency. Mock API tests cover 156 writes, no-op reruns, concurrent edits, wrong ownership, changed review state, unexpected locale sets and partial failures.

## Remote scope

Only `whatsNew` may be sent to `PATCH /v1/appStoreVersionLocalizations/{discovered-id}`. The release-note client rejects `description` and all other writable fields. The shared engine still pins app IDs, bundle IDs, version IDs, platform, version `3.6.0` and `PREPARE_FOR_SUBMISSION` state.

```sh
ruby Tools/AppStoreConnect/sync-release-notes.rb \
  --key-file /private/path/AuthKey.p8 \
  --key-id YOURKEYID1 \
  --issuer-id 00000000-0000-0000-0000-000000000000 \
  --output /private/path/new-release-notes-backup
```

Without `--apply`, this is read-only. Review the plan, then rerun with `--apply` and a new output directory. The script backs up all current localizations, checks for concurrent edits before each write, and re-reads every localization afterward. Every other attribute—including the descriptions just synchronized—is required to remain identical. No versions/locales are created, no submission is made, and uncertain writes are not blindly retried.

Local backup directory for this run: `outputs/asc-release-notes-3.6.0-20260925/`. The private key and JWT are not stored in backups or source. The original key is not changed; an owner-only staging copy is removed after loading.

Official API: [Modify an App Store version localization](https://developer.apple.com/documentation/appstoreconnectapi/patch-v1-appstoreversionlocalizations-_id_).
