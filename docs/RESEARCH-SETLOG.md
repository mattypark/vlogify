# Setlog, researched

What the app we are cloning actually does, where each fact came from, and how the
research was run so it can be repeated for the next reference app.

## The product in one paragraph

Setlog (New Chat Inc., App Store id6587576438, iOS 17.6+, 13+, Social Networking,
EN/JA/KO/RU/zh-Hant/VI, ~93 MB) is a "friends camera". A private room of 2–20 people
all receive the same ping roughly once an hour; each shoots a **two-second, one-take**
clip — no retakes, no camera-roll uploads. The app stitches everyone's clips into a
split-screen day-in-the-life video that can be saved to Photos and posted to Reels,
TikTok or Shorts. Solo logs have no limits. The day resets at **4 AM**; past days live
in **history**. It hit #1 Social Networking in Korea and Hong Kong in April 2026; all
nine members of Seventeen and aespa's Karina have posted Setlog days.

## Mechanics, with provenance

| Fact | Source |
|---|---|
| Ping once an hour, same moment for everyone in the room | Korea JoongAng Daily; zuzukorea; the app's home screen ("add a 2s clip every hour") |
| 2 s clips (some sources say 2–4 s) | App home screen: "add a 2s clip every hour."; Filmora KR guide |
| One take, no retry, no gallery upload | zuzukorea |
| Day resets at 4 AM; history for past days | **The app itself** — "day resets at 4AM. find past days in history." (screenshot). zuzukorea says midnight; the app wins. |
| Room types: log / stack / vlog (+ zip) | New-room sheet screenshots: `log` "you and friends", `stack` "24hrs, up to 40 friends", `vlog` "just you"; `+` menu shows "start a zip" |
| Room sizes 2 / 3 / 4 / 5 / 6-20 | New-room sheet screenshot; App Store v2.4 notes "Invite up to 20 friends" (older guides say 4, expandable to 6 via Instagram DM — pre-2.4) |
| Invite by code or link | JoongAng; app home: "join log (with a code)" |
| Landscape or portrait capture; "rotate to capture" hint | App Store v2.4 notes; screen recording |
| Export → save to phone → post to Reels/TikTok/Shorts | Filmora KR; welloffmap; JoongAng ("the daily vlog can be downloaded") |
| Zip = right-now 1:1 photo chat, view once, caption | App Store v2.3.5 notes ("Logs are for your day. Zips are for right now. Talk in photos."); note.com ikeda; SetlogHub |
| DM with a "save permission" toggle | welloffmap |
| Auth: Passkey / Apple / email | Welcome screenshot |
| "Photos and videos are end-to-end encrypted, only you and friends you share with can see them" | Permissions screen in the recording |
| Privacy label: Name, User Content, User ID linked to you | App Store listing |
| Developer string "newchat" leaks in the microphone prompt | Screen recording frame |

## How saving works (what we built to match)

1. `AVCaptureMovieFileOutput` with `maxRecordedDuration = 2 s`, rotation from
   `AVCaptureDevice.RotationCoordinator` so a turned phone records landscape.
2. The file is moved into the app-group container **first** (`LocalMediaCache`), then
   uploaded through `MediaStore.uploadURL` → `upload` → `ClipService.post`. A dropped
   connection costs nothing: the tile fills locally, the upload retries.
3. "Play the day": `DayCompositor` builds an `AVMutableComposition` — one video track
   per member, each posted hour a 2 s segment, `StitchPlan` tiles applied as layer
   transforms, hour label + missing-member discs as CoreAnimation layers — exports
   with `AVAssetExportSession` to .mp4.
4. `PHPhotoLibrary` add-only save, then the share sheet.

## Database or local? Both, necessarily

A room's clips must be visible to friends whose phones are asleep, so the room lives
on a server: **object storage** for the video bytes (Cloudflare R2, free egress —
every room replays video daily) and **Postgres** for rooms, members, slots and clip
rows (Supabase, with Row Level Security so only members can read a room). Each phone
keeps a **local cache**: its own clips are written locally before upload; friends'
clips are pulled on view and cached under the same path layout. "End-to-end
encrypted" in Setlog's copy means the clip is encrypted on the phone with a per-room
key before upload, so the server stores blobs it cannot play; the contract reserves
`EncryptedBlob` for that, and v1 ships TLS + RLS (see DECISIONS.md).

## How the research was done — recipe

1. **App Store listing** (`apps.apple.com/.../id6587576438`): subtitle, category, age
   rating, languages, size, seller, privacy nutrition labels, and — most useful —
   the **version history**, which names features release by release.
2. **Press**: SCMP, Korea Herald, JoongAng Daily, FZINE, PhilSTAR. Good for the why
   (Gen-Z fatigue with curated feeds, idol adoption), thin on mechanics.
3. **Fan/how-to guides**: SetlogHub (EN), Filmora KR, HitPaw KR, welloffmap KR,
   note.com (JA). These disagree with each other on numbers; treat as hints.
4. **The official Notion guide** is JS-rendered and unfetchable by a plain fetch —
   a browser tool (Claude in Chrome) would be needed.
5. **Screen recording → frames**: `ffmpeg -i rec.mp4 -vf "fps=2,scale=280:-1,tile=5x4"
   sheet_%02d.png` turns a 43 s recording into five contact sheets that settle every
   UI question the articles contradicted (exact copy, control placement, the 4 AM
   line, the room-type captions). This was the single most valuable step.
6. Where sources conflict, **the app's own screens win**.

For live signals next time (what people say on X/Reddit, SERP), `monid` or the
`deep-research` skill; for a JS-only page, Claude in Chrome.

## Sources

- https://www.scmp.com/lifestyle/entertainment/article/3350142/what-setlog-app-trending-hong-kong-and-south-korea
- https://www.koreaherald.com/article/10722194
- https://www.koreajoongangdaily.com/korea/social-media-app-setlog-gives-young-koreans-a-real-time-unvarnished-glimpse-at-their-friends-lives/12525462
- https://www.fzine.com/culture/setlog-social-media-app
- https://apps.apple.com/ph/app/setlog/id6587576438
- https://setloghub.com/en/learn · https://setloghub.com/en/learn/what-is-setlog-zip
- https://filmora.wondershare.kr/video-editing-app/how-to-use-setlog.html
- https://welloffmap.com/셋로그-setlog-사용방법/
- https://zuzukorea.travel/latest-trends/setlog-app-korea-2026/
- https://en.tamagodaruma.com/trend/setlog/
- Screenshots + 43 s screen recording in `~/Downloads/setlogui/` (2026-09-10)
