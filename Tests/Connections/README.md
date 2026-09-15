# Remote connection selection tags

## Import authorization navigation regression (2026-09-15)

Run `ruby Tests/Connections/run-navigation-regressions.rb SIMULATOR_UDID` on an already-booted Apple Silicon iOS simulator. The runner compiles an isolated UIKit app with the **actual routing methods extracted from ImportViewController.swift**. Storage, providers, file lists, and the Mac sidebar are inert doubles: it does not sign in, touch Wake Music accounts, or make network requests.

The 38 assertions cover an unloaded Connections tab (using the app's `addChild` setup), duplicate success callbacks, full-screen Import, nested full-screen authorization, stale destination folders, Back returning to Connections, pushed server login, unrelated account reauthorization, a lazily created split-view destination, and ignoring a callback after Import is closed. The split-view case exercises the routing branch on iOS; it is **not** a native Mac Catalyst UI verification. The runner prints the report and retains its temporary build for inspection. Its isolated simulator bundle is `com.wakemusic.tests.import-navigation`.

Manual end-to-end checks with real authorization remain:

- Fresh launch → Music → Import → sign in: Connections is selected and Back from the file list returns there.
- Connections → existing folder → Import → different provider: only the newly authorized root list remains above Connections.
- Baidu / 115 modal login; SMB / WebDAV / Navidrome pushed login; MEGA's separately dismissed login; browser-based OAuth providers.
- Dropbox external-app return: Import handles the account once; legacy tab/sidebar notifications do not switch early.
- Cancel / failure stays in the authorization/import flow; reauthorization of an existing connection retains its original behavior.
- Mac Catalyst: first-ever Connections selection, then another import with an existing folder stack.

No provider credentials, OAuth scopes, localization text, or saved account schemas change in this navigation update.

`ImportTableViewCell` is shared by ImportViewController and ConnectListViewController's unconfigured-service list. Connected accounts keep their existing account cell. Local import methods have no tags.

The labels are informational, not buttons. VoiceOver reads the service and its tags as a single button. Semantic colors, leading/trailing constraints, Dynamic Type and wrapping support varying appearances, languages and widths. Measure after laying out the actual content width so a newly dequeued cell does not reserve one line per tag.

## Provider facts checked 2026-09-11

- Google: 15 GB free, shared across Google services. https://support.google.com/drive/answer/2375123
- Dropbox Basic: 2 GB free. https://help.dropbox.com/plans/dropbox-basic-faq
- OneDrive: 5 GB free, shared Microsoft account storage. https://support.microsoft.com/en-us/onedrive/microsoft-storage-faqs
- pCloud: unlock up to 10 GB free through required steps, not an unconditional signup grant. https://help.pcloud.com/article/referral-program
- Box Individual: 10 GB free; 250 MB maximum per uploaded file. https://blog.box.com/free-cloud-storage and https://support.box.com/hc/en-us/articles/360043697314-Understand-the-Maximum-File-Size-You-Can-Upload-to-Box
- Navidrome is a self-hosted music server, not free cloud storage. https://www.navidrome.org/

Revised product copy: direct cloud services show free storage only outside Chinese locales. Simplified and Traditional Chinese (including Hong Kong) additionally show “不限速” for Google Drive, Dropbox, OneDrive, pCloud and Box, following the product owner's requested positioning. This describes absence of a fixed transfer-rate cap, NOT unlimited traffic or a throughput guarantee. Provider account/API quotas still apply; for example Box documents bandwidth restrictions at https://support.box.com/hc/en-us/articles/360044194313-Understanding-Box-Bandwidth-Limits and pCloud describes speed behavior at https://help.pcloud.com/article/uploading-downloading-organizing . Revalidate this positioning before release.

Baidu's Chinese-only badge says “在线播放部分不限速” based on the product owner's observed audio-streaming behavior for some users, not a universal entitlement or download claim. Domestic capacity labels now explicitly show Baidu “最高免费2TB” / “Up to 2 TB free”, Aliyun “免费100GB” / “100 GB free”, and 115 “免费15GB” / “15 GB free” in all supported label languages. 115's free-account 15 GB allocation is listed at https://vip.115.com/ . Baidu's upper bound and Aliyun's 100 GB copy follow the product owner's supplied figures; a current unconditional new-account grant was not established from official documentation, so verify these two against current account onboarding before release. Baidu is deliberately phrased as an upper bound, not guaranteed initial capacity.

WebDAV includes “网盘”. The old generic-free-storage, no-server-setup and Box per-file-limit badges are no longer used in selection rows; Box's actual free-tier restriction above still applies. Provider quotas are not Wake Music entitlements. These hints do not imply the app can upload to each service.

## Checks

Verified 2026-09-11: Mobie Debug simulator build succeeded. Chinese Connect and Import pages were inspected in Simulator, including all cloud rows and untagged local rows. Fixed initial excess row height found during this check. English / larger text / dark mode remain manual follow-up checks, not claimed as visually verified.

- Build the Mobie simulator target.
- Open Connect with no configured accounts, then open Import; check service tags and the unchanged local-import rows.
- Scroll through all providers and back to check reuse and row sizing.
- Check both short Chinese and longer English labels, narrow widths, larger text and dark mode.
- Localization keys use the `ConnectionTag.` prefix. As of the 2026-09-15 localization cleanup, all 42 project locales are supplied; speed badges remain displayed only in Chinese according to the existing product rule. Run `ruby Tests/ImportLocalization/run-regressions.rb` to check coverage.
