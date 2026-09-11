# Paste-ready prompt — overnight session

Overnight mode. Project: ~/Downloads/current-projects/appscurrent/vlogify.
Read ~/.claude/rules/20-overnight.md and docs/OVERNIGHT.md. Then:

1. scripts/overnight.sh start --runs 20 --max-hours 7
2. After each pass, read qa/reports/<today>/summary.md. For every failed test: open its
   screenshot, classify (real bug / flaky / harness / environment). Rerun a suspected
   flaky test three times with scripts/qa-matrix.sh --only ScreenWalkerTests/<name>.
3. For each real bug, write file:line, what failed, and a proposed diff into
   qa/reports/<today>/FIXES.md. Do not apply it. Do not edit anything under
   ios/Vlogify/Sources or ios/VlogifyDesign/Sources.
4. Add anything you learned about the app's assumptions to docs/AGENT-NOTES.md.
5. If you find a missing test, write it in ios/VlogifyUITests/ (allowed) and note it.
6. Never delete a file, never touch a production database, never call a live URL.
   Simulators you boot, you shut down. Never push. Never kill tmux.
7. Leave the marker on. In the morning Matthew reads summary.md and FIXES.md and runs
   scripts/overnight.sh stop.
