# Art slots — the brief for the artist

Every drawing the app shows, by name. Drop a PNG named `<slot>.png` (plus `@2x`, `@3x`)
into `ios/Vlogify/Resources/Assets.xcassets/Doodles/` as an image set with that name and
the app picks it up; until then it draws a dashed footprint of the same size so nothing
has to be re-laid-out later.

Style: hand-drawn, thick rounded contours, two or three flat colours, transparent
background, no shadows. The welcome page is the cool ground (#F5F6F8); the home doodles sit on
ink (#08111A), so give those a light outline. The mascot is a cloud with two eyes and a
smile — it is also the app icon, so it must read at 32 × 32.

| slot | size (pt) | where |
|---|---|---|
| `mascot` | 180 × 160 | Welcome, centre. The app icon too. |
| `starHappy` | 76 × 76 | Welcome, top-left of the mascot. |
| `starSurprised` | 76 × 76 | Welcome, top-right of the mascot. |
| `sparkleSmall` | 24 × 24 | Welcome, scattered around the top. |
| `sparkleLarge` | 40 × 40 | Welcome, scattered around the top. |
| `moon` | 84 × 84 | Welcome, right of the mascot, asleep. |
| `envelope` | 70 × 56 | Welcome, left of the mascot, with a heart. |
| `pizza` | 110 × 96 | Welcome, left, under the tagline. |
| `orange` | 48 × 52 | Welcome, centre, under the tagline. |
| `plant` | 190 × 170 | Welcome, right, under the tagline, in a pot. |
| `tea` | 96 × 140 | Welcome, bottom-left, a mug that says tea. |
| `flames` | 96 × 60 | Welcome, bottom-centre, three small flames. |
| `sundae` | 90 × 130 | Welcome, bottom-right. |
| `turtle` | 78 × 44 | Home, empty state, bottom-left, walking. |
| `ufo` | 110 × 78 | Home, empty state, bottom-right, an alien waving. |
| `glyphLog` | 64 × 120 | New room sheet: three stacked clips labelled 12:00. |
| `glyphStack` | 64 × 120 | New room sheet: one tall clip labelled 12:00. |
| `glyphVlog` | 64 × 120 | New room sheet: one small clip labelled 12:00. |
| `shutterSmile` | 84 × 84 | Camera: the shutter. A smiley face on a sky disc. |

Generated from `Doodle` in `VlogifyDesign/Doodles.swift`; regenerate with
`python3 scripts/art-slots.py` after adding a slot.
