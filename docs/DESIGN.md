# Design

Cool blue-white, slate type, doodles — and every pressable thing **extruded**: a gradient
lid on two tiers of its own darker shades, a gloss on the top edge, and a press that
compresses the plinth rather than sliding. Seven fills so nothing repeats. One bundled
face (Bagel, the wordmark only); everything else is SF Pro. No dark mode — the only dark
surface is video itself. The home is a page you type on.

The direction is folk.com's, taken from their shipped CSS rather than from a screenshot.

## Tokens

All in `ios/VlogifyDesign/Sources/VlogifyDesign/`.

**Palette** (OKLCH; text variants are *derived*, never hand-picked). Views use the
semantic names: `ground`, `card`, `cardRaised`, `hairline`, `text`, `textSoft`, and
`action` / `warn` / `good` for what a colour *means*.
- `ground` `#F5F6F8` — the app, everywhere. Cool, never pure white: cards would vanish.
- `card` `#FFFFFF` (+ a hairline `#DDE5EE`) — cards, sheets, fields, the pill bar. The
  only pure white in the app. `cardRaised` `#E3E8F0` — a selected pill.
- `slate` `#1F2A2F` — every word, every outline, and the wordmark. `slateSoft` = the
  lightest slate that clears AA. Exposed as `.text` / `.textSoft`.
- `ink` / `chalk` — video chrome only: behind a playing clip, the pills over the camera.
- `blue` `#0088FF` — the single live action: selection, the create check, the recording
  ring, and the bottom stop of every primary button. Exposed as `.action`.
- `blueLight` `#4DB6FF` — the gradient's top stop, and the blue that carries text.
  `blueMid` / `blueDeep` — folk's two shadow tiers.
- `periwinkle` · `orange` (`.warn` — a missed slot, a denial) · `sand` (the mascot and
  doodles) · `mint` (`.good` — "saved") · `lilac`.
- `avatar(seed:)` — twelve evenly spaced hues for member discs. **Deliberately unchanged
  by the folk palette**: the seed rides on `Profile.avatarSeed` over the wire.

Contrast is tested (`PaletteTests`): body AAA on ground and over video, every accent's
text variant AA on ground, every fill's derived ink AA on that fill. A tweak that breaks
that fails the build's test step.

**The one deliberate exception.** folk's primary CTA is white on a `#4DB6FF → #0088FF`
gradient, which is 3.5:1 — AA for large text, which the 17 pt bold shout is, and not AA
for anything smaller. That is why `blue` is *not* a `Fill`: a `Fill` must carry a label at
4.5:1, and neither slate (4.17) nor white (3.52) clears it on `#0088FF`. The button style
supplies its own white label and folk's text shadow instead, and `ctaLabelClearsLargeAA`
pins it to 3:1 rather than waiving it.

**Typography** — Bagel Fat One for the wordmark and nothing else. SF Pro Display Heavy for
shouts, hour numerals and the invite code; SF Pro Text for everything a person reads and
for notes; SF Mono on exactly one screen, the permissions typewriter. Rounded is gone with
the warm palette.

**Space** 4 / 8 / 12 / 16 / 20 (gutter) / 24 / 32 / 48. **Radius** tile 12, row 12,
sheet 20, card 28, camera frame 32, pill. **Metrics** hit target 44, bar button 56,
shutter 84, tile height 132, hour dot 6, avatar 32.

**Extrusion** (`Extruded.swift`) — `drop` 4 (how far the plinth extends *below*; nothing
extends sideways), `press` 3, `line` 3, `lineThin` 2. Tier tones are mixed from the fill
at 22 % and 38 % slate, which on `#0088FF` reproduces folk's own `#0070D4` / `#005DB1`, so
every other fill gets the same relationship without a hardcoded blue. `stickerRoom()`
reserves the plinth's 4 pt at the bottom.

**Motion** — `tap` (0.24/0.6), `land` (0.42/0.74), `shift` (0.34/0.9), `ring` (linear 2 s,
it is a clock). Button presses are `.easeOut(0.12)`, folk's own duration — a spring would
make the lid wobble, and a key does not wobble. Reduce Motion returns `nil`, not a faster
spring.

## Screens

- **Welcome** (ground): mascot centre, thirteen doodle slots scattered by fraction of
  the screen, wordmark, tagline, Apple / Google / email.
- **Language**: asked once, right after sign-in — six rows in their own scripts.
- **Permissions** (mono): types itself in, one permission at a time, ✓ per grant,
  `continue →` / `done →`. Runs once; denial is handled where it matters.
- **Home**: wordmark + profile; room cards with 24 hour-dots (chalk = posted, blue =
  now, dim = to come) and a status line; the pill bar bell · camera|logs · +.
- **New room**: name pill, three tall type cards, size pills, blue ✓.
- **Room**: hour rows newest-first for today, one tile per member, empty tile = disc.
- **Camera**: preview in a 32-radius frame, hour stamp turns with the phone, "rotate to
  capture" until landscape, smiley shutter with a 2 s ring.
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
