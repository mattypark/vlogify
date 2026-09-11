# Overnight QA

What runs while Matthew sleeps, what it may touch, and how to read the morning.

## Run it

```sh
scripts/overnight.sh start --runs 20 --max-hours 7    # guard on → N passes → guard off is manual
scripts/overnight.sh status
scripts/overnight.sh stop                              # in the morning, after reading the report
```

One pass = `scripts/qa-matrix.sh`: build-for-testing once, then `VlogifyUITests` on each
device in `qa/matrix.json` (iPhone 16e, iPhone 17 Pro, iPhone 17 Pro Max — no Android
SDK on this Mac; the slot is reserved). Simulators it boots, it shuts down.

## What it writes — `qa/reports/<date>/`

- `summary.md` — the three numbers first: cold launch, flow timings (open camera,
  record→posted, stitch a day), failure triage. Then per-device table, failed tests
  with messages, screenshot index.
- `screens/<device>/` — every screenshot the walker took, named `NN-screen-state`.
- `bundles/*.xcresult` — full result bundles, `open` them in Xcode for the video.
- `results-*.json` — `xcresulttool` output the summariser reads.
- `FIXES.md` — proposed fixes, file:line + diff in a code block. **Not applied.**
- `audit.jsonl` — one line per tool call the session made while the guard was on.
- `passes.log` — one line per pass, so a stall is visible from another terminal.

## What the guard does

While `~/.claude/overnight/ACTIVE` exists, `~/.claude/hooks/overnight-guard.sh` (PreToolUse)
refuses: Edit/Write outside `qa/**`, `docs/**`, `README.md`, `*Tests/**`; any Bash matching
`rm`, `git push`, `git reset --hard`, `sed -i` on source, `DROP/DELETE/TRUNCATE`, `supabase db`,
`psql`, `wrangler deploy`, `vercel deploy`, `simctl delete`, `tmux kill`, `altool`, or a
URL on supabase.co / workers.dev / vercel.app / vlogify.app. `overnight-audit.sh`
(PostToolUse) writes the audit line. Marker absent → both are no-ops.

## Reading the morning

1. `summary.md` top three lines.
2. Failed tests → open the named screenshot → decide: real bug / flaky / harness /
   environment. Flaky = passed on rerun ×3 (the walker reruns nothing automatically;
   `scripts/qa-matrix.sh --only ScreenWalkerTests/testX` does).
3. `FIXES.md` → apply what you agree with, by hand, in a normal session.
4. `docs/AGENT-NOTES.md` → the assumptions the run learned; keep or strike.
5. `scripts/overnight.sh stop`.

## Known simulator limits

- No camera: `CameraSession.isSimulated` records the bundled `sample-clip.mov`.
- No Sign in with Apple sheet: the welcome button exchanges a mock token directly when
  no backend is configured.
- Photos save works in the simulator; Share sheet does.
