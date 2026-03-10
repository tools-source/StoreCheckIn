# StoreCheckIn

This repo now includes a runnable iOS app target.

Open `StoreCheckIn.xcodeproj` in Xcode and run the `StoreCheckIn` scheme on an iPhone or iPad simulator.

CLI build:

```sh
xcodebuild -scheme StoreCheckIn -project StoreCheckIn.xcodeproj -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build
```

GitHub Pages-ready policy and metadata helper files live in `docs/`.

If GitHub Pages is enabled for this repo, the expected policy URL is:

- `https://tools-source.github.io/StoreCheckIn/privacy.html`

For App Store metadata compliance text (including Terms of Use link), use:

- `docs/app-store-description-snippet.md`
