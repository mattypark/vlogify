# Decisions

Each one is a choice against a rejected alternative, so it can be reopened on purpose
rather than drifted away from.

## vlogify, not Setlog
Setlog is a live App Store app. A 1:1 copy of the name and mascot is a Guideline 4.1
copycat rejection and a trademark problem. Same mechanics, own brand. Drawings are
placeholder slots until an artist replaces them (`docs/ART-SLOTS.md`).

## The day starts at 4 AM, and the engine is the only clock
`VlogifyEngine.DayClock` converts every instant through wall-clock components in the
user's time zone. Nothing else in the app calls `Calendar` to decide which day a clip
belongs to. Rejected: midnight (some articles claim it; the app's own screen says 4 AM).

## The ping minute is a hash, not a server random
`SlotPing.minute(room:slot:)` = splitmix-finalised FNV-1a of `room|day|hour`, mod 51.
Every member's phone, the mock, and the future server compute the same minute with no
round-trip, so local notifications can be scheduled a day ahead offline. Rejected: the
server picking a random minute and pushing it (needs connectivity at 3 AM; the mock
could never match it).

## Two seconds, one take, no camera roll
`RoomRules.clipLimit(.log) == 2.0`, `capturesPerSlot == 1`, `canRetake == false`, and
the client and mock both enforce it; the real backend must too. Rejected: letting
people pick from the library (kills the candid).

## Landscape by default; the stamp, the hint and the stitch move together
Most people turn the phone. `CapturePreferences.orientation` defaults to landscape,
which rotates the hour stamp along the long edge, shows "rotate to capture" until the
phone is turned, and makes `StitchPlan` stack clips as full-width rows (up to four
people, one column) on the 1080x1920 canvas — landscape clips stack; portrait clips
stand side by side. Tap the stamp (or Profile → recording) to flip; nothing else has to
be told. Rejected: portrait-only strips (the original design) — a room of four
landscape clips became four letterboxed slivers.

## Local first, upload second
A recording is moved into the app-group container before any network call. The tile
fills from the cache; the upload retries on foreground. Rejected: upload-then-save
(a dropped connection at 5:03 PM loses the only take).

## Supabase + Cloudflare R2, not Supabase Storage, not Firebase
Postgres + RLS for rooms and clip rows; Supabase Auth covers Apple, Google and email
codes natively. Video goes to R2 because egress is free and every room replays video
daily. Rejected: Firebase (Google sign-in via Firebase triggers the Sign in with Apple
requirement anyway, storage egress is billed, no SQL for slot queries); Convex (weak on
large blobs and native auth).

## Plaintext-over-TLS + RLS in v1; E2E is a reserved v2
Setlog markets end-to-end encryption. The contract reserves `EncryptedBlob` (ciphertext,
nonce, wrapped key id) so a v2 backend can store what it cannot play. v1 does not
implement it: it would also break server-side stitching and moderation review, both
of which need a decision, not a default. `ITSAppUsesNonExemptEncryption` flips to
`true` the day this ships.

## Google through the system browser, not a bundled SDK
`ASWebAuthenticationSession` opens the backend's authorize URL and returns the callback.
No client secret in the app, no third-party SDK carrying a privacy manifest. Rejected:
GoogleSignIn-iOS SPM package.

## "skip for now" exists only while the mock is the backend
`WelcomeView` shows it when `BackendRoot.config == nil`, so the whole onboarding can be
walked without an email in the loop. It disappears the day `Secrets.xcconfig` points at
a real backend; a real guest mode would be `signInAnonymously` on `AuthService`, which
is a contract change and has not been made.

## Email codes go out through Resend
The backend session sends the six-digit code with Resend (connected to this account),
from `hello@vlogify.app`; the app never sees the provider. `review@vlogify.app` stays
pinned to `000000` for App Review.

## No passkey in v1
Setlog offers it; Matthew asked for Apple + Google + email. The `AuthService` protocol
is where it would go.

## Cool blue-white everywhere, no dark mode
Setlog's welcome page is light and its app is black; Matthew wanted the welcome look
carried through. The ground moved from warm paper (`#F5F5F3`) to folk's `#F5F6F8` and the
ink from soot to their blue-slate `#1F2A2F`; the rule did not change, only the temperature. The one dark surface is video. `preferredColorScheme(.light)` is set
at the root; the palette has no dark variant to drift. Rejected: supporting both (twice
the screenshots, twice the contrast tests, for a look he did not want).

## Six languages, chosen in the app, not in Settings
Asked once right after sign-in (`LanguageView`) — before that there is nothing to set
up, and the welcome page has to work in every language at once anyway; the choice persists in `UserDefaults` and drives
both the SwiftUI environment locale (for `Text`) and `Bundle.app` (for every
`String(localized:bundle:)`), so nothing mixes. `AppleLanguages` is written too so
system-drawn UI (the Apple button, alerts, keyboard) follows on the next launch.
Rejected: the iOS per-app language setting — it lives three taps away in Settings and
left the app half-translated whenever the two disagreed. Every user-facing string is a
`Text("…")` / `String(localized:bundle: .app)` literal so Xcode's extraction keeps the
catalog honest. Wire types spell their JSON keys by hand because Foundation's key strategy
turns `roomID` into `room_id` on the way out and `roomId` on the way back.

## (superseded) Rounded system faces, no bundled fonts
The original call was two *system* families and nothing bundled. The "Alive" commit broke
it by bundling Bagel and Gloria; the folk redesign settles at one bundled face used as a
logotype. See **One bundled face, and it is a logotype**.

## `stack` and `zip` are modelled, hidden, and unbuilt
They exist in `RoomType`, the wire format and the mock so adding them is UI work, not
a migration. `FeatureFlags` keeps them off; there is no "coming soon" button (2.1).

## iPhone-only target, portrait chrome, landscape capture
`TARGETED_DEVICE_FAMILY 1`; iPad runs the iPhone layout, which App Review accepts. The
UI never rotates; the camera reads device orientation to stamp the hour along the
long edge and record landscape when the phone is turned.

## The mock is a real backend that says no
`MockBackend` refuses a full room, a second clip in a slot, a clip over two seconds, a
bad checksum, a wrong email code. Rejected: a stub that returns success (tests would
pass against a backend that does not exist).

## The extruded language, from folk — replacing the sticker language, from chingo
Every pressable thing sits on a plinth: a gradient lid over two tiers of progressively
darker shades *of its own fill*, a gloss on the top edge, a soft ambient shadow, and a
press that compresses the plinth instead of sliding (`Extruded.swift`). Never scale one —
the plinth slides out from under the lid. Bare glyphs inside something else still use
`SquashButtonStyle`. Seven fills (`Palette.playful`) so a row of chips never repeats a
colour; each fill's ink is chosen by contrast and tested.

This replaces chingo's sticker: flat fill, 3 pt soot outline, zero-blur hard shadow offset
4 pt down *and right*. That shadow was the loudest thing tying vlogify's look to another of
Matthew's apps, which makes it a 4.1 conversation nobody needs. The type names
(`StickerButtonStyle`, `.sticker(…)`, `.stickerRoom()`) were deliberately kept so the
twenty call sites did not move — only what they draw changed.

Tier tones are mixed from the fill (22 % and 38 % slate) rather than hardcoded. On folk's
own `#0088FF` that lands within a couple of points of their `#0070D4` / `#005DB1`, so the
relationship holds for every fill including white. Rejected: hardcoding folk's two blues
(every non-blue button would have grown a blue shadow).

## folk's blue is the action colour, and cannot be a fill
`#0088FF` sits in the dead zone: slate on it is 4.17:1 and white 3.52:1, so neither ink
clears AA and `PaletteTests.fillInks` rejects it. `#E7642B` fails the same way (4.37 /
3.36). So `blue` and `orange` as folk ship them stay non-`Fill` tokens, and the seven
playful fills use lighter siblings that do clear AA.

The primary button keeps folk's exact gradient anyway, with a white label at 3.5:1 — AA for
large text, which the 17 pt bold shout is, plus folk's `text-shadow: 0 1px #00285A59`.
`ctaLabelClearsLargeAA` pins it to 3:1 so it is a measured threshold rather than a waiver.
Rejected: deepening the bottom stop to `#0070D4` for a full 4.5:1 (correct by the letter,
but it is no longer folk's button, and Matthew asked to copy that button exactly).

## One bundled face, and it is a logotype
Bagel Fat One sets the wordmark and nothing else. Shouts, hour numerals and the invite
code are SF Pro Display Heavy; everything a person reads, notes included, is SF Pro Text.

Gloria Hallelujah is gone: handwriting on a cool blue-white ground reads as two apps
arguing, and a note looks like a note because of where it sits, not because of the
letterforms. `Typography.hand` / `handSmall` kept their names so the seven note call sites
did not move. `design: .rounded` went with the warm palette — folk's display face is a
tight gothic and SF Pro Display Heavy is the closest thing already on the device.

Rejected: bundling a new OFL gothic (one more face to license, register and fail to
register); keeping Bagel for shouts (it is unmistakably the chingo voice).

## Notes are local, full stop
`NotesStore` writes JSON to the app-group container and never touches `Backend`. No sync,
no sharing, no server copy — Matthew asked for "no one else can see your text", and the
simplest way to guarantee it is for the bytes to never leave. Deleting the account wipes
them. Rejected: syncing notes as private rows (a server copy is a copy).

## The home is a page
`DayPageView` is a Notion-style page per day: typed title, tap-to-type blocks, rooms as
blocks, your clips along the foot. The first day's explainer is real blocks, which is why
it looks typed. Rooms also carry their own notes above the timeline. Rejected: a room
list with a notes tab (two places to look).

## Tap bursts, random colour
`TapBurstLayer` on the onboarding screens only: a circle pops and stripes fly out at the
touch point, colour drawn from `Palette.playful` at random each tap. Garnish, never a
gate (`simultaneousGesture`). Reduce Motion gets a single soft circle.

## Your colour is on the wire; the stamp font is not
The outline colour has to differentiate *you* from friends, so it rides on `Profile.avatarSeed`
(already in the contract); `ProfileService.update(avatarSeed:)` was added — additive, the
backend session implements it as a column update. The stamp font is burned into the video
you export and needs no server.

## Cloudflare relay replaces Supabase (2026-09-28)
Supersedes "Supabase + Cloudflare R2" and "Email codes go out through Resend" above. The
backend is one Cloudflare Worker (`worker/`): Hono for routes, D1 for metadata, R2 for
bytes, and the `web/` site served from the same origin.

- **A relay, not an archive.** Clips live on the phones -- the app already records into
  its own cache first. The server only moves a clip between friends: the copy in R2
  under `clips/` expires after 7 days by a bucket lifecycle rule (`CLIP_TTL_DAYS`). D1
  rows stay, so history still lists every day; a gone object answers 410 and the app
  plays its own copy. That keeps storage flat as rooms age and leaves the least
  footage on a server that could leak or be subpoenaed.
- **The Worker signs its own media URLs.** Uploads PUT to `/media/upload/<clip id>`,
  playback GETs `/media/<key>`, each with an expiry and an HMAC (`MEDIA_SIGNING_KEY`)
  over exactly what it may touch; the bytes stream through the `CLIPS` binding. No R2
  access keys exist anywhere, so none can leak, and a download URL is only minted for
  a member of the clip's room. Playback honours byte ranges because AVPlayer needs them.
- **Apple-only sign-in until there is a domain.** Google needs an OAuth client and a
  callback domain, email codes need a sending domain; neither exists tonight. Both
  answer `unsupported` (501) and the client throws `ContractError.unsupported` without a
  round trip. Apple identity tokens are verified against Apple's keys with the nonce;
  only HMAC(`PEPPER`, sub) is stored; the authorization code is exchanged and the
  refresh token sealed so account deletion can revoke it (when the Apple key secrets
  are set).
- **Presence is polling.** `PresenceService` fetches the room's day every 30 s and yields
  what changed. A room changes a few times an hour; a Durable Object socket is the v2
  answer if that ever feels slow.
- **Pings stay local.** v1 schedules the hourly ping on each phone from `SlotPing`, which
  every phone computes identically offline. No APNs, no device tokens on the server;
  `/v1/push/register` is a 204 no-op kept for when APNs arrives.
- **Same rules as the mock.** Capacity, the 2 s + 250 ms limit, one clip per slot (also a
  partial unique index), owner-only remove/regenerate, blocks hiding both ways,
  idempotent post on clip id. `worker/test/rules.test.ts` runs the Swift engine's own
  vectors against the TypeScript port.

Rejected: Supabase (a second vendor, RLS policy surface and an auth product for what is
a dozen routes; its Realtime was the draw and polling covers v1); presigned R2 URLs
(needs R2 API tokens in Worker secrets and gives up per-request membership checks);
keeping clips forever (cost and exposure grow with every day, for a product whose
output is the exported vlog on the phone).

## Ink on paper, and your own mark (2026-09-28)

The folk blue-white look was replaced, and with it the last of what read as Setlog:
the cloud mascot (also the icon), the thirteen welcome doodles in Setlog's positions,
word-for-word lines ("new moment every hour…", "your day, side by side.", "add a 2s
clip every hour…", "it's 5:00. add your 2s clip."), the bell · camera|logs · + bar, and
the three-card new-room sheet. What replaced them, and why:

- **Black pen on white paper, drawn outlines** (`Ink.swift`), grug-*inspired*: the
  handwriting is secondary, SF Pro stays the primary voice, and the drawings are our own.
  Rejected: copying grug's font-first voice (a second 4.1 problem).
- **Everyone draws a mark.** It replaced the colour ring as identity and is the most
  vlogify-specific thing in the app: avatar, clip badge, export signature, and the
  onboarding "mascot" ("meet <name>."). `Profile.mark` on the wire, additive.
- **Doodles are code**, not art slots: one pen for drawings and marks, animatable, no
  artist dependency. `art-slots.py` / `ART-SLOTS.md` are obsolete.
- **Words**: "nudge" not "ping", "room" not "log", our own onboarding and notification
  copy; Setlog-era catalog keys dropped out when the catalog was rebuilt from source.
- **App Review hardening** (audit before first submission): pre-permission screens have
  one button that always reaches the system prompt; the name is optional after Sign in
  with Apple; a word filter masks names and room names; an open report hides a clip from
  the whole room; a person can be reported without a clip; age rating 13+ (override of the
  calculated 4+) to match the terms; the EU storefronts are off until trader status is
  decided; Mac/Vision Pro availability is off.
- **The hand became the main font** (Matthew, same day, after seeing it on his phone): all
  text is Yomogi; the camera hour is SF Pro Black so it reads over video. Onboarding
  writes itself in line by line, and its buttons draw themselves.

## Home draws itself; the camera hour follows the hand (2026-09-29)

- **Home is a notebook page, drawn in like onboarding** (Matthew: the onboarding's rough,
  self-drawing vibe is the point; the home after sign-in was dense, typed and boxed).
  The big drawing is the onboarding clock at the real time -- it echoes the camera's hour
  without touching the camera. Rooms are written entries, not sticker cards. Red stays
  for record and delete only.
- **The first page no longer seeds four explainer paragraphs** -- onboarding and the coach
  marks explain; the page keeps one to-do. **"add a note" left the `+` menu**: it did
  nothing.
- **Draw-in once per launch and on turning the day**, not on every return from the
  camera: the camera is one tap away all day, and replaying a 3-second animation each time
  would be a tax.
- **Camera hour turns with the hand.** It was fixed at -90 degrees, upside down for a phone
  turned top-left (the right-hand way). It now follows the device orientation, defaults to
  top-left, and sits at the true centre of the preview.
- **The camera's room is derived, not stored on appear.** Storing it once left "pick a
  room" with a dead pill and a dead shutter whenever rooms loaded after the camera opened;
  a reviewer on a fresh account hits that path. The pill is a `Menu`, so it always opens.
- Stage 2 (every other screen in the same language) waits for Matthew; build 5 ships the
  new home with the old room/profile/sheets.

