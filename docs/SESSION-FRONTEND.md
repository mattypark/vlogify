# Frontend session

## What this session owns
`ios/Vlogify/**`, `ios/VlogifyDesign/Sources/VlogifyDesign/**`, `ios/VlogifyDesign/Sources/VlogifyEngine/**`,
`ios/VlogifyUITests/**`, `web/**`, `qa/**`, `docs/DESIGN.md`, `docs/ART-SLOTS.md`.

It may read `VlogifyContract` and must not change it without a DECISIONS.md entry.

## The standing rules
- Never edit `ios/Vlogify.xcodeproj`; edit `ios/project.yml`, run `scripts/dev.sh`.
- Every screen root gets `.screen("screen.x")`; every control an `accessibilityIdentifier`
  the walker can find. New screens get a walker test the same day.
- No new colour, spacing or radius outside the tokens. No bundled fonts.
- Strings are `Text("…")` / `String(localized:"…", bundle: .app)` literals (the bundle argument is what makes the in-app language apply); run `scripts/build-strings.py`
  after adding one and fill the six columns.
- Commit after every stage. Never push.

## Verifying
`swift test --package-path ios/VlogifyDesign` · `scripts/run.sh --demo full --screen camera`
· `scripts/qa-matrix.sh --device "iPhone 17 Pro"` · shut the simulator down.

## The prompt for this session
See `nextsessions/frontend-session.md`.
