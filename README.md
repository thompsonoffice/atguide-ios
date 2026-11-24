# ATGuide for iPhone

A native SwiftUI iPhone app (iOS 17+) of ATGuide 2.0, the assistive-technology encyclopedia by Hunter Thompson. Fully offline, VoiceOver-first, no data collection.

- Content: ATGuide 2.0 release candidate (research date November 13, 2026): 437 devices, software and voices; 104 companies; 23 categories; 28 operating-system histories; 102 trivia facts. Exported from `ATGuide 2.0.zip` → `ATGuide/index.html` with `tools/export_data.py`.
- Planned listing: App Store, $5.99, seller Hunter Thompson (individual account), category Reference, privacy label **Data Not Collected**.

## Features

- **Browse** by category (23 categories), by company, by year (timeline), operating-system history and trivia.
- **Full-text search** across names, specs, history, features, descriptions, ports and requirements. Every word must match; case and accents are ignored; name matches rank first. Result counts are spoken after typing pauses.
- **Favorites** for devices, companies and OS histories, saved on the device.
- **Recently viewed** (last 25), on the Browse tab and under Favorites and More.
- **Compare** 2 or 3 devices: each fact is a heading followed by one line per device, with a "Show only differences" switch.
- **Settings**: text size (follow iPhone setting, or any of 12 Dynamic Type sizes up to Accessibility 5), and clearing recents, comparison or favorites.
- **Share as TXT** for any entry, About screen, and an in-app privacy policy.

## Accessibility

- Every section title and list header carries the VoiceOver heading trait (headings rotor works on every screen).
- List rows are single VoiceOver elements ("BrailleNote Touch, Notetakers, HumanWare, 2016, Favorite").
- Every control has a text label; no image-only buttons. Favorite reports "Selected"; Compare announces how many devices are picked.
- All text uses Dynamic Type styles; labels sit above values so text wraps at the largest sizes.
- Swipe actions (remove favorite, remove recent, remove from compare) are also reachable from the VoiceOver Actions rotor.

## Project layout

- `project.yml`: XcodeGen spec (app, unit tests, UI tests). CI runs `xcodegen generate`; the generated `.xcodeproj` is not committed.
- `ATGuide/`: app sources (`App`, `Model`, `Views`), `Resources/atguide-data.json`, assets (placeholder icon), `PrivacyInfo.xcprivacy`.
- `ATGuideTests/`: unit tests (data integrity, search, comparison, export, saved state).
- `ATGuideUITests/`: UI flow tests and `performAccessibilityAudit()` audits.
- `.github/workflows/ios-ci.yml`: simulator build, unit tests, UI tests, and accessibility audits on every pull request and every push to main. See `ci/README.md`.
- `.github/workflows/testflight-upload.yml`: signing and upload, **disabled** unless the repository variable `ENABLE_TESTFLIGHT_UPLOAD` is `true`. See `docs/APP-STORE-SETUP.md`.
- `docs/PRIVACY-POLICY.md`: privacy policy text for the App Store privacy policy URL.

## Not verified yet

Real-device VoiceOver use, signing, TestFlight and App Review have not happened. The simulator audit catches many problems but does not replace testing with VoiceOver on an iPhone.

## macOS App Store target

A native macOS target (`ATGuideMac` in `project.yml`) ships the same ATGuide 2.0 catalog in a sidebar-and-detail layout, with the App Sandbox and Hardened Runtime on, for the Mac App Store. It uses the same bundle ID as the iPhone app (`com.thompsonoffice.atguide`) so both platforms share one listing and price.

- Unit tests: the `macOS build and test` workflow, or `xcodegen generate && xcodebuild test -scheme ATGuideMac -destination 'platform=macOS'`.
- Upload: the `Mac App Store upload` workflow (run by hand). It signs a `.pkg` with the Mac App Store certificates stored as repository secrets and uploads it to App Store Connect. It does not submit the version for review.

