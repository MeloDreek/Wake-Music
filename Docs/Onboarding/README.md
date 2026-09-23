# Onboarding redesign

Four swipeable feature pages: supported formats, cloud/NAS connections, equalizer and audio fingerprinting. Non-Premium users of the ordinary app get a fifth monthly-offer page. Pro and existing Premium users get four pages.

The original cassette demo and its auto-play/style-reset logic are removed. Playback preferences are not changed by the new Welcome screen.

## Visual assets

Four alpha-transparent feature-page illustrations were generated using the built-in image_gen tool. Production assets are in `Mobie/Mobie/Base/Bundle/Reasource.bundle/Images/onboarding_*@3x.png`; final prompts are in [illustration-prompts.md](illustration-prompts.md). The paywall reuses the `vip_gift_crown` image and copy from PurchaseHeadCell.

- [Actual iOS 27 first-launch screenshot](first-page-ios27.png)
- [Monthly page UIKit preview](monthly-paywall-preview.png) — the price is fixture data, not live App Store pricing.

## Offer behavior

- Only the monthly product is recommended; never substitute an annual or lifetime product if monthly is unavailable.
- The CTA advertises a trial only when the product has a free introductory offer **and** RevenueCat confirms eligibility. It uses the actual duration, localized with `Free Trial for %d Days`.
- Trial billing copy discloses the subsequent localized monthly price and automatic renewal.
- Missing products show Retry; loading and purchasing are single-flight. Not Now, Restore Purchase and All Plans remain available. Pro makes no onboarding offer request.
- Legal links are native UITextView links, not manually estimated text hit areas.

## Verification

Both simulator schemes and ordinary Mac Catalyst compile. The isolated regression suite in `Tests/Onboarding` checks layout, RTL, entitlement routing and offer states without real purchases or saved-account changes.

The ordinary-app `UserInfoManager.isVIP()` currently returns `false` unconditionally as a testing override. This was intentionally left intact; restore the existing `isPremium()` check before release so purchased users are recognized correctly.
