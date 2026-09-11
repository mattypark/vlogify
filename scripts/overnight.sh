#!/usr/bin/env bash
# The overnight run. Starts guard mode, runs the three-device walker N times, writes
# the morning report, stops guard mode. Never touches app source; never pushes.
#
#   scripts/overnight.sh start [--runs 500] [--max-hours 8]
#   scripts/overnight.sh status
#   scripts/overnight.sh stop
#
# `start` writes ~/.claude/overnight/ACTIVE. While that file exists the Claude Code
# hooks in ~/.claude/hooks/overnight-guard.sh refuse any Edit/Write outside qa/, docs/,
# README.md and the test targets, and any Bash that deletes, pushes, or talks to a live
# service. `stop` removes it. A crashed run leaves the marker in place on purpose: the
# next session opens in guard mode and has to be told "normal mode" -- safer than the
# other way round.
#
# Each pass calls scripts/qa-matrix.sh. Between passes it appends one line to
# passes.log so a stalled run is visible from another terminal. Simulators it boots,
# it shuts down (qa-matrix.sh does that per pass). tmux is never touched.
set -uo pipefail
cd "$(dirname "$0")/.."

MARKER="$HOME/.claude/overnight/ACTIVE"
PROJECT="$(pwd)"
REPORT="qa/reports/$(date +%Y-%m-%d)"
RUNS=1
MAX_HOURS=8

cmd="${1:-status}"; shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --runs) RUNS="$2"; shift 2 ;;
    --max-hours) MAX_HOURS="$2"; shift 2 ;;
    --report) REPORT="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

case "$cmd" in
  status)
    if [[ -f "$MARKER" ]]; then echo "overnight mode ON:"; cat "$MARKER"; else echo "overnight mode off"; fi
    ;;
  stop)
    rm -f "$MARKER"
    echo "overnight mode off"
    ;;
  start)
    mkdir -p "$(dirname "$MARKER")" "$REPORT"
    ABS_REPORT="$PROJECT/$REPORT"
    python3 - "$MARKER" "$PROJECT" "$ABS_REPORT" "$RUNS" <<'PY'
import json, sys, datetime
marker, project, report, runs = sys.argv[1:]
json.dump({"project": project, "report_dir": report, "runs": int(runs),
           "started_at": datetime.datetime.now().isoformat(timespec="seconds")},
          open(marker, "w"), indent=2)
PY
    echo "overnight mode ON — guard hooks active, report → $REPORT"
    : > "$REPORT/passes.log"
    printf '# proposed fixes — %s\n\nWritten by the overnight run. Nothing here has been applied.\nEach entry: file:line, what failed, the proposed diff. Review in the morning.\n\n' "$(date +%Y-%m-%d)" > "$REPORT/FIXES.md"
    DEADLINE=$(( $(date +%s) + MAX_HOURS * 3600 ))
    for (( pass = 1; pass <= RUNS; pass++ )); do
      if (( $(date +%s) > DEADLINE )); then
        echo "pass $pass: max-hours reached, stopping" | tee -a "$REPORT/passes.log"
        break
      fi
      START=$(date +%s)
      if scripts/qa-matrix.sh --report "$REPORT" > "$REPORT/pass-$pass.log" 2>&1; then STATUS=ok; else STATUS=FAILED; fi
      echo "$(date +%H:%M:%S) pass $pass/$RUNS $STATUS ($(( $(date +%s) - START ))s)" | tee -a "$REPORT/passes.log"
      command -v tg >/dev/null && [[ "$STATUS" == FAILED ]] && tg "vlogify overnight pass $pass FAILED — see $REPORT/summary.md" >/dev/null 2>&1 || true
    done
    command -v tg >/dev/null && tg "vlogify overnight done: $(grep -c ' ok ' "$REPORT/passes.log") ok / $(grep -c FAILED "$REPORT/passes.log") failed — $REPORT/summary.md" >/dev/null 2>&1 || true
    echo "done. read $REPORT/summary.md, then scripts/overnight.sh stop"
    ;;
  *) echo "usage: scripts/overnight.sh start|status|stop" >&2; exit 1 ;;
esac
