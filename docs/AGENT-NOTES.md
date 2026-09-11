# Agent notes

Assumptions learned the hard way, for the next agent (human or not). The overnight run
may append here; a person prunes it.

- A bare `.accessibilityIdentifier` on a `VStack`/`ScrollView` leaks to every child and
  overwrites the buttons' own ids. Use `.screen("…")` (contains children) for containers.
- `List` rows below the fold are not in the accessibility hierarchy. `swipeUp()` first.
- `AVVideoCompositionCoreAnimationTool` crashes the **simulator** (IOSurface
  `_xpc_shmem_create_with_prot` misuse in the CA render path) even with plain layers;
  the overlay is compiled out under `targetEnvironment(simulator)`. Verify the hour
  label on a device. Set `CATextLayer.font` to a `CTFont`, not a `UIFont`.
- XCUITest: a `.screen()` container is an `Other` on a stack but a `ScrollView` on a
  scroll view. Look ids up with `app.any("id")` (any type), never `otherElements[...]`.
- `confirmationDialog` buttons can match twice (the dialog and its accessibility
  proxy); use `.matching(identifier:).firstMatch`.
- The mock backend seeds relative to *its* `now`; when the app runs with `-vlogifyHour`
  the mock must be given the same frozen instant or "today" stops at real time.
- `Color.mint` exists in SwiftUI. Palette tokens must not collide with system colours.
- `-quiet xcodebuild` prints nothing on success; check the product, not the output.
- In-app language: `Text` follows `.environment(\.locale)`, `String(localized:)` does NOT —
  it needs `bundle: .app`. A `String(localized:)` without the bundle shows English.
- `xcodebuild -exportLocalizations` needs `-scheme` when `-derivedDataPath` is given.
- A simulator booted by a script must be shut down by that script: `mediaanalysisd`.
