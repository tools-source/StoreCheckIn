# StoreCheckIn

This repo now includes a runnable iOS app target.

Open `StoreCheckIn.xcodeproj` in Xcode and run the `StoreCheckIn` scheme on an iPhone or iPad simulator.

CLI build:

```sh
xcodebuild -scheme StoreCheckIn -project StoreCheckIn.xcodeproj -destination 'generic/platform=iOS' -derivedDataPath .DerivedData CODE_SIGNING_ALLOWED=NO build
```
