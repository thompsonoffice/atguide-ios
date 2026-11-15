# CI workflows

The workflows live in `.github/workflows/`.

- `ios-ci.yml` builds ATGuide for the iOS Simulator on `macos-15` and runs the unit tests, UI tests, and `performAccessibilityAudit()` checks. It runs on every pull request, on every push to `main`, and from the Actions tab. It does not sign or upload.
- `testflight-upload.yml` is prepared but gated. The job is skipped unless the repository variable `ENABLE_TESTFLIGHT_UPLOAD` is `true`. Leave that variable unset, and do not add signing secrets, until the Apple Developer Program membership is active. See `docs/APP-STORE-SETUP.md`.
