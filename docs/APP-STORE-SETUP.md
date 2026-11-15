# Getting ATGuide onto TestFlight and the App Store

Nothing here can happen until Apple finishes the developer enrollment (status changes from "Apple Developer, pending" and the "Welcome to the Apple Developer Program" email arrives).

## 1. App Store Connect basics (once)

1. Sign in at https://appstoreconnect.apple.com.
2. Business section: accept the Paid Apps agreement, add bank and tax info.
3. Apply for the App Store Small Business Program (15% commission): https://developer.apple.com/app-store/small-business-program/
4. Apps → "+" → New App: platform iOS, name ATGuide (or a variant if taken), language English (U.S.), bundle ID `com.thompsonoffice.atguide` (register it under Certificates, Identifiers & Profiles → Identifiers first if it is not offered), SKU `atguide-ios`.

## 2. App Store Connect API key (for GitHub to sign and upload)

1. App Store Connect → Users and Access → Integrations → App Store Connect API → Team Keys → "+".
2. Name it `GitHub ATGuide`, access **Admin** (needed for cloud-managed signing; App Manager can upload but cannot create signing certificates).
3. Download the `.p8` file. Apple only lets you download it once. Note the **Key ID** and the **Issuer ID** shown on that page.
4. Find the **Team ID** at https://developer.apple.com/account → Membership details.

## 3. GitHub secrets and the on switch

In the GitHub repo: Settings → Secrets and variables → Actions.

Secrets (New repository secret):

| Name | Value |
| --- | --- |
| `ASC_KEY_ID` | the Key ID |
| `ASC_ISSUER_ID` | the Issuer ID |
| `ASC_KEY_P8` | the whole text of the `.p8` file, including the BEGIN and END lines |
| `APPLE_TEAM_ID` | the 10-character Team ID |

Variables tab: add `ENABLE_TESTFLIGHT_UPLOAD` = `true`.

Then Actions → "TestFlight upload (disabled)" → Run workflow. It archives with cloud-managed signing, sets the build number to the run number, and uploads. The build appears in App Store Connect → TestFlight after Apple processes it (often 10 to 30 minutes).

Never paste the `.p8` key or its contents into chat, email or the repository; only into the GitHub secret field.

## 4. TestFlight

- Internal testing (Hunter's own Apple ID): add yourself under TestFlight → Internal Testing; no review needed.
- Public link: create an External group, add the build, fill in "What to Test", submit for Beta App Review (usually about a day), then enable the public link (up to 10,000 testers).

## 5. App Store listing checklist

- Price: $5.99 (Pricing and Availability).
- Category: Reference (secondary: Education).
- Age rating questionnaire: no objectionable content → 4+.
- App Privacy: "Data Not Collected" (the app has no analytics, accounts, ads, tracking or network calls). Privacy policy URL: host `docs/PRIVACY-POLICY.md` somewhere public (for example the existing ATGuide website) and paste its link.
- Accessibility Nutrition Labels (App Store Connect → Accessibility): declare only what has been confirmed on a real iPhone (VoiceOver, Larger Text, Dark Interface, Sufficient Contrast, Differentiate Without Color). Do not claim a feature before testing it.
- Screenshots: 6.9-inch iPhone screenshots are required; they can be generated from the simulator later.
- Replace the placeholder app icon (`ATGuide/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, 1024×1024, no transparency) if a final icon is made.
- Review notes for Apple: explain that ATGuide is an offline reference for blind and low-vision users with browse, full-text search, favorites, recently viewed, side-by-side comparison and text size settings, built for VoiceOver.
