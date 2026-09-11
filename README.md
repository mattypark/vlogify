# vlogify

new moment every hour, vlog it with your friends.

A private room of friends all get the same hourly ping. Everyone shoots a two-second,
one-take clip. At the end of the day vlogify stitches every clip, side by side, into
one video you can save and post anywhere. Solo vlogs have no limits. The day resets
at 4 AM.

Native SwiftUI, iOS 18+. Six languages. Free.

## Layout

| Path | What |
|---|---|
| `ios/project.yml` | XcodeGen spec. The `.xcodeproj` is generated and gitignored. |
| `ios/Vlogify/` | The app target: screens, services, assets, privacy manifest. |
| `ios/VlogifyDesign/` | One local Swift package: `VlogifyDesign` (tokens, art slots), `VlogifyEngine` (day clock, ping, rules, stitch layout -- pure Swift), `VlogifyContract` (wire types, service protocols, the on-device mock backend). |
| `ios/VlogifyUITests/` | The overnight walker: every screen, every button, screenshots, launch and flow metrics. |
| `qa/` | Overnight QA harness: device matrix, report templates. Reports land in `qa/reports/` (gitignored). |
| `scripts/` | `dev.sh` (regenerate project), `run.sh` (build + screenshot on a sim), `qa-matrix.sh`, `overnight.sh`, `pre-submit.sh`, `testflight.sh`. |
| `web/` | Companion site: privacy, terms, support, 404. |
| `docs/` | Research, decisions, design, the frozen backend contract, session handoffs, checklists. |
| `nextsessions/` | Paste-ready prompts for the backend, App Store, and overnight sessions. |

## Running it

```sh
scripts/dev.sh                       # xcodegen + resolve packages
swift test --package-path ios/VlogifyDesign   # engine, contract, palette tests (~1s, no simulator)
scripts/run.sh --demo full           # build, boot "Vlogify Sim", screenshot, shut down
scripts/run.sh --demo empty --screen welcome
```

With no `ios/Vlogify/Secrets.xcconfig` the app runs on the on-device mock backend and
is fully usable: rooms, codes, clips (the simulator "records" a bundled sample), the
stitched export, save to Photos. The presence of `SUPABASE_URL` in that file is the
switch to the real backend, which the backend session builds against `docs/CONTRACT.md`.

## Status

See `docs/STAGES.md`.
