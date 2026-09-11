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

## Paper everywhere, no dark mode
Setlog's welcome page is light and its app is black; Matthew wanted the welcome look
carried through. The one dark surface is video. `preferredColorScheme(.light)` is set
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

## Rounded system faces, no bundled fonts
Two families where Setlog has three. Nothing to license, nothing to fail to register.
An artist's lettered wordmark lands as an image slot, not a font.

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

## The sticker language, from chingo
Every pressable thing is a sticker: flat fill, 3 pt soot outline, zero-blur hard shadow
offset 4 pt, and pressing moves the block *into* its shadow (`Sticker.swift`, copied from
chingo with the palette swapped). Never scale a sticker — the shadow slides out from
under it. Bare glyphs inside something else use `SquashButtonStyle`. Seven playful fills
(`Palette.playful`) so a row of chips never repeats a colour; each fill's ink is chosen
by contrast and tested. Rejected: soft blurred elevation on buttons (reads as a pane).

## Three type voices
Bagel Fat One for shouts and numbers, SF Pro Rounded for reading, Gloria Hallelujah for
notes and empty states. Both bundled faces are OFL and asserted at launch in debug.
Rejected: one face for everything (either generated-looking or unreadable).

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
