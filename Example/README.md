# FCBDemo

A SwiftUI + TCA iOS demo app that exercises the FCBComposable client API.

## Layout

- `FCBDemoFeatures/` — SwiftPM library containing all Reducers, value types, SwiftUI views, and TestStore tests. Buildable and testable from the command line:
  ```
  swift build --package-path Example/FCBDemoFeatures
  swift test  --package-path Example/FCBDemoFeatures
  ```
- `FCBDemo.swiftpm/` — Swift Playgrounds App Project that pulls in `FCBDemoFeatures` and provides the `@main App`, Info.plist permission strings, and Bluetooth capability declaration. Open in Xcode 14+ to build and run on a device or simulator.

## Running

Open `Example/FCBDemo.swiftpm` in Xcode (`open Example/FCBDemo.swiftpm`). Build and run on a real iOS device. BLE does not work on the simulator.

## Permissions

`NSBluetoothAlwaysUsageDescription` is declared via the `.bluetoothAlways` capability in `FCBDemo.swiftpm/Package.swift`. The simulator's Bluetooth state will be `.unsupported`; deploy to a device.

## Notes

- iBeacon advertising is intentionally out of scope (the FCBComposable package does not handle iBeacon).
- No background BLE.
- No persistence; state resets on each launch.
