# FCBDemo — Decisions made in your absence

You went to bed at 2026-06-12 ~mid-execution of subagent-driven build for the FCBDemo iOS app. This is the log of questions I had and the best-guess decisions I made on your behalf. Review when you wake up; revert anything you disagree with.

Format: each entry is `Q:` (the question I had) → `Decision:` (what I picked and why).

---

## Task 1 — implementer added a local .gitignore

Q: The implementer for Task 1 added `Example/FCBDemoFeatures/.gitignore` containing `.build` even though that wasn't in the task. Did they overreach?

Decision: Accepted. Reasonable hygiene. Task 2 (originally adding to the root `.gitignore`) is now mostly redundant for `.build` — I applied only the `.swiftpm/configuration/registries.json` and `.swiftpm/xcode/package.xcworkspace/contents.xcworkspacedata` entries to the root since those weren't covered.

## Task 14 (post-plan) — diagnostics about missing modules

Q: New SourceKit diagnostics appeared: "No such module 'ComposableArchitecture'" in `BluetoothCentralClient+Live.swift` (FCB package) and "No such module 'FCBDemoFeatures'" in the placeholder test. The `swift build` and `swift test` succeed though.

Decision: Ignoring. These are SourceKit IDE-side stale-index complaints, not real compiler errors — both `swift build` and `swift test --package-path Example/FCBDemoFeatures` ran clean. Will disappear when the editor re-indexes.

## Task 4 — Sendable capture workaround

Q: TCA reducers using `.run { send in ... await client.foo(...) ... }` fail Swift 6 strict concurrency because `self` (the reducer struct) gets captured into the `@Sendable` closure even when only `client` is needed. How to handle?

Decision: Accepted the implementer's fix — capture each `client` endpoint as a local `let` before the `.run` closure (e.g., `let stateStream = client.state` then use `stateStream()` inside the closure). It's a minor mechanical adjustment that doesn't change reducer behavior, and the same pattern will recur in every subsequent reducer task (5, 7, 8, 9, 10, 11). Future implementers will hit and apply the same fix without needing escalation.

## Task 6 — macOS compat in views

Q: SwiftUI views in FCBDemoFeatures need to compile for both iOS and macOS (the package declares both platforms so it can be tested with `swift test` on the dev host). Two iOS-only constructs broke macOS compile.

Decision: Accepted the implementer's fixes:
1. Use `@Perception.Bindable` instead of bare `@Bindable` (Perception's backport is unambiguous; bare `Bindable` is ambiguous between SwiftUI's macOS 14+ version and Perception's backport).
2. Wrap `.textInputAutocapitalization(...)` calls with `#if os(iOS)`.
Both are mechanical and have no behavioral impact on iOS. Same patterns will recur in view tasks 10 and 11.

## Task 10 — Perception.Bindable doesn't write through `$store.prop` on macOS

Q: `@Perception.Bindable` exposes `$store.localName` for reads but the subscript is "get-only" on macOS. The plan used `$store.localName` as a writable TextField binding, which doesn't compile on macOS.

Decision: Accepted the implementer's fix — use explicit `Binding(get:set:)` wrappers that dispatch the corresponding action (e.g. `.localNameChanged(newValue)`) instead of `$store.localName`. Same behavior, slightly more verbose, no macOS guard needed. Affected `AdvertisingView` and `GATTBuilderView`.

## Final summary

All 13 tasks landed cleanly. End state:
- **FCBDemoFeatures**: 41 tests passing across reducer + utility suites.
- **Root FCB package**: 80 tests still passing, no regressions.
- **`Example/FCBDemo.swiftpm/`**: iOS app shell ready to `open` in Xcode 14+. Bluetooth capability + permission string declared via SwiftPM `.iOSApplication` capabilities, not Info.plist.
- **`Example/FCBDemoFeatures/`**: SwiftPM library, builds and tests cleanly on both iOS and macOS dev hosts.

Decisions you may want to revisit:
- Local `.gitignore` at `Example/FCBDemoFeatures/.gitignore` instead of (or in addition to) root patterns. Both are now present; root is the source of truth, local is redundant but harmless.
- Heavy use of explicit `Binding(get:set:)` in views instead of `$store.prop` because of cross-platform support. If you decide to make FCBDemoFeatures iOS-only (drop `.macOS(.v13)` from its `Package.swift`), you can simplify views and tests run will still work in Xcode.
