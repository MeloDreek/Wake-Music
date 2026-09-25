# Welcome onboarding regression checks

Run `bash Tests/Onboarding/run-probe.sh` with a booted iOS simulator (or set `MUSIC_SERVER_SIMULATOR_UDID`).

For a native Apple Silicon Mac Catalyst probe (no simulator or installed-app preferences):
`ONBOARDING_PLATFORM=catalyst bash Tests/Onboarding/run-probe.sh`.
Both modes honor `DEVELOPER_DIR` when provided.

The probe compiles the production Welcome controller, cells, page model, offer flow and shared TagListView. Only application services, storefront responses and preferences are replaced by local fixtures. It never purchases, restores, sends analytics, plays audio or changes an installed app's preferences.

Checks:

- Four features in the requested order; optional fifth monthly offer; four pages for Pro and existing Premium users.
- Chinese, English, German and RTL Arabic at 320×568, 440×860 and 820×650.
- CTA outside scroll content, two genuine legal links, RTL page hit testing and final Get Started title.
- Continue action, repeated resizing of the same controller, viewport-sized pages, stale scroll completions versus user drags, and no forced dark appearance.
- Free-trial eligibility versus mere presence of an offer, no-offer/ineligible/unknown states, missing-product retry, pending and stale callbacks.
- Day/week and calendar-month durations, zero and overflowing values.

PNG renders are written only to the temporary test folder. Prices in these renders are fixtures, not live App Store pricing. Source UI starts no real StoreKit requests in this probe.

Full ordinary/Pro simulator builds and a full ordinary-app first-launch screenshot were also checked. The repository currently has an unconditional `return true` in the ordinary target's `UserInfoManager.isVIP()` (PurchargeStatus+Extension.swift). This pre-existing test override is deliberately preserved: it hides the fifth page in the installed ordinary debug app. Restore the real entitlement check there when testing the live monthly offer.
