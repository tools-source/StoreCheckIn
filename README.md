# StoreCheckIn

This repo now includes a runnable iOS app target.

Current app status:

- Sign in with Apple account access
- App Store subscription-gated usage
- Employee check-in and check-out tracking
- Archive/history with per-employee weekly filtering
- Check-in and check-out reminder notifications
- 6-digit PIN lock with Face ID or Touch ID when available
- Store name customization for the Employees tab
- Local delete-account flow for removing this device's app data

Open `StoreCheckIn.xcodeproj` in Xcode and run the `StoreCheckIn` scheme on an iPhone or iPad simulator.

CLI build:

```sh
xcodebuild -scheme StoreCheckIn -project StoreCheckIn.xcodeproj -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build
```

GitHub Pages-ready support/policy pages and metadata helper files live in `docs/`.

If GitHub Pages is enabled for this repo, the expected URLs are:

- `https://tools-source.github.io/StoreCheckIn/support.html`
- `https://tools-source.github.io/StoreCheckIn/privacy.html`

For App Store metadata compliance text (including Terms of Use link), use:

- `docs/app-store-description-snippet.md`
