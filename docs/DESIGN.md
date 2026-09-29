# Design

**Ink on paper.** Black pen (`#111`) on a white page, one pen hand for every word, and
every outline drawn by hand. The only colour in the chrome is red, and only
where it means something: recording, delete. Video is the colour. No dark mode — the one
dark surface is video itself.

Inspired by grug's line-drawn black-and-white NUX (before.click), not a copy of it: the
drawings, words and the drawn mark are vlogify's own (clocks, phones, cameras, clips side
by side).

## Tokens — `ios/VlogifyDesign/Sources/VlogifyDesign/`

- **Palette.swift** — `ground`/`card` paper `#FFF`, `fog` (picked/pressed), `hairline`,
  `pen` `#111`, `penSoft` (derived to AA), `ink`/`chalk` for chrome over video, `red`.
  The `Color` role names (`.text`, `.ground`, `.card`, `.action`…) are kept so every view
  restyled without edits. `avatar(seed:)` hues are wire-bound and never remapped, though
  nothing draws them any more. `PaletteTests` pin AA/AAA and "only red has chroma".
- **Typography.swift** — the hand for everything: `Typography.handFont` = Yomogi (OFL;
  Latin, Vietnamese, Cyrillic, Japanese) with Gaegu (OFL) cascaded for Hangul. One weight,
  so hierarchy is size. Exceptions: the camera hour (SF Pro Black, read over video) and
  the mono typewriter. UIKit chrome (nav titles, bar buttons) gets the hand via appearance.
- **Motion** — drawings trace themselves, then `HandwrittenText` writes each line left to
  right, one after another, then buttons trace their outline in (`drawIn`); `.writeIn`
  reveals anything else the same way and `DrawnRule` rules a line in. Onboarding and
  home both arrive like this. Reduce Motion shows everything finished.
- **Ink.swift** — the pen. `PenShape` (rounded rect / capsule / circle) wobbles off the
  ideal edge, never quite closes, and overshoots its start; seeded by size so it is stable.
  `InkStrokes` draws unit-square strokes (doodles and marks); `InkDrawing` traces them on
  appear (Reduce Motion: finished drawing).
- **Extruded.swift** — the `Sticker` API (`.sticker`, `StickerButtonStyle`…) now draws a
  pen outline on paper; press = fog wash + 0.97 scale. No plinth, gloss or shadow.
- **Doodles.swift** — 24 drawings made of code strokes (clock, phoneBuzz, frames,
  camcorder, bell, moon, friends, page, arrows, glyphs) plus `Doodle.clock(hour:minute:)`,
  the clock at a real time. No image assets, no artist slots.
- **Rule.swift** — `PenLine` / `DrawnRule`: a line ruled by hand, used for rules and
  underlines. `InkPressStyle` (Extruded.swift) is press feedback for a full-width line.

## The mark

Everyone draws a small doodle at sign-up (`MarkCanvas`/`MarkEditor`). It is their avatar
(`AvatarDisc` = mark in a pen circle), the badge on their clip tiles, and the signature on
their square of the exported vlog. Wire format: `VlogifyContract/Mark.swift`. Redraw from
Profile → your mark.

## Screens

- **Onboarding** — three self-drawing intro pages → Sign in with Apple → language →
  camera+mic and nudge asks (one "continue", straight to the system prompt) → name
  (optional) → "draw ↘" your mark → "meet <name>." → home with handwritten coach marks.
- **Home** — a notebook page that draws itself in (first time per launch, and on turning
  the day): the date written with a ruled underline and drawn arrows; the onboarding clock
  at the real time with one written line under it ("it's 7 pm. two seconds?"), tap =
  camera; rooms as written entries with a row of 24 hand-drawn hour circles (filled ink =
  filmed, heavy ring = now, light ring = missed, dot = later) and a rule under each;
  your own page; your clips as tilted polaroids.
- **Bar** — today (page doodle) · big drawn record button · `+`. "today" opens **your days**:
  a drawn month calendar (clip days circled, note days dotted, today inked in); tap a day
  to turn home to it. On the camera the left button is "← back". `+` opens a drawn card
  (start a room / join with a code), not a system menu. Bell and your mark sit top-right.
- **Rooms** — everyone has their own "just me" vlog, made automatically; a room is the
  multiplayer thing (the new-room sheet is friends only).
- **New room** — a sentence: "a room called ___ for me + (3) friends." with the number
  circled in pen.
- **Camera** — drawn frame (red while recording), a red pen ring that draws itself over
  the two seconds, the hour dead centre of the preview. Tap the hour to turn it 90°; the
  angle is saved per horizontal/vertical (sideways starts with the tops facing 9 o'clock),
  and "turn me sideways" points the way that makes it read upright.
- **Export** — each tile framed in a white pen line and signed with its owner's mark.
- **Icon** — a hand-drawn record button: one pen loop, a red dot (`swift run IconSheet`).

## Hand-copied values (no test guards these)

Both `.colorset`s (AccentColor = pen, LaunchBackground = paper), `web/style.css`.
