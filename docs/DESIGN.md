# Design

Same idea as Setlog's welcome page, carried through the whole app: warm paper, black
type, doodles, one orchid accent. No dark mode — the only dark surface is video
itself. Cleaned up: two type families, one accent, a closed spacing set, radius that
tracks size, four named springs.

## Tokens

All in `ios/VlogifyDesign/Sources/VlogifyDesign/`.

**Palette** (OKLCH; text variants are *derived*, never hand-picked). Views use the
semantic names: `ground`, `card`, `cardRaised`, `hairline`, `text`, `textSoft`.
- `paper` ~#F5F5F3 — the ground, everywhere. Never pure white: cards would vanish.
- `card` ~#FEFEFD (+ a hairline) — cards, sheets, fields, the pill bar. `cardRaised` — a selected pill.
- `soot` ~#1A1A1D — every word, and the wordmark. `sootSoft` = the lightest soot that clears AA.
- `ink` / `chalk` — video chrome only: behind a playing clip, the pills drawn over the camera.
- `orchid` ~#E58BE8 — the single live action: selection, the create check, the recording ring.
- `sky` — the shutter. `butter` — the mascot and doodles. `ember` — a missed slot, a denial. `spearmint` — "saved".
- `avatar(seed:)` — twelve evenly spaced hues at one lightness for member discs.

Contrast is tested (`PaletteTests`): body AAA on paper and over video, every accent's
text variant AA on paper. A tweak that breaks that fails the build's test step.

**Typography** — SF Pro Rounded (black/heavy) for the wordmark, the hour numerals and
sheet titles; SF Pro for reading; SF Mono on exactly one screen, the permissions
typewriter. No bundled fonts.

**Space** 4 / 8 / 12 / 16 / 20 (gutter) / 24 / 32 / 48. **Radius** tile 12, row 12,
sheet 20, card 28, camera frame 32, pill. **Metrics** hit target 44, bar button 56,
shutter 84, tile height 132, hour dot 6, avatar 32.

**Motion** — `tap` (0.24/0.6), `land` (0.42/0.74), `shift` (0.34/0.9), `ring` (linear 2 s,
it is a clock). Reduce Motion returns `nil`, not a faster spring.

## Screens

- **Welcome** (paper): mascot centre, thirteen doodle slots scattered by fraction of
  the screen, wordmark, tagline, Apple / Google / email.
- **Language**: asked once, right after sign-in — six rows in their own scripts.
- **Permissions** (mono): types itself in, one permission at a time, ✓ per grant,
  `continue →` / `done →`. Runs once; denial is handled where it matters.
- **Home**: wordmark + profile; room cards with 24 hour-dots (chalk = posted, orchid =
  now, dim = to come) and a status line; the pill bar bell · camera|logs · +.
- **New room**: name pill, three tall type cards, size pills, orchid ✓.
- **Room**: hour rows newest-first for today, one tile per member, empty tile = disc.
- **Camera**: preview in a 32-radius frame, hour stamp turns with the phone, "rotate to
  capture" until landscape, smiley shutter with a 2 s orchid ring.
- **Day player**: stitched video, save to Photos, share.

## Art slots

Every illustration is a named slot with a size and a placement (`Doodle` enum). If
`Doodles/<name>.png` is in the asset catalogue it is drawn; otherwise a dashed
footprint of the same size. `docs/ART-SLOTS.md` is the artist's brief.

## Accessibility

Every control has a label; every screen root uses `.screen(id)` so the identifier
stays on the container (a bare `.accessibilityIdentifier` on a stack leaks to every
child and breaks the walker). 44 pt targets. Dynamic Type honoured on all text. Reduce
Motion drops springs. VoiceOver reads hour dots as "n of m hours posted".
