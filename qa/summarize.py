#!/usr/bin/env python3
"""Turns a report directory's xcresult JSON into summary.md.

Three numbers first -- cold launch, the flow timings, the failure triage -- then the
per-device table, then every failed test with its message, then the screenshot index.
Reads only what qa-matrix.sh wrote; never touches the app.
"""
import glob, json, os, re, sys
from collections import defaultdict

report = sys.argv[1]
results = sorted(glob.glob(os.path.join(report, "results-*.json")))

def walk(node, out, device):
    if isinstance(node, dict):
        if node.get("nodeType") == "Test Case":
            name = node.get("name", "?")
            result = node.get("result", "?")
            duration = node.get("duration", "")
            msgs = []
            for child in node.get("children", []) or []:
                if child.get("nodeType") in ("Failure Message", "Issue"):
                    msgs.append(child.get("name", ""))
            metrics = []
            for child in node.get("children", []) or []:
                if child.get("nodeType") == "Metric":
                    metrics.append(child.get("name", ""))
            out.append((device, name, result, duration, msgs, metrics))
        for child in node.get("children", []) or []:
            walk(child, out, device)
    elif isinstance(node, list):
        for item in node:
            walk(item, out, device)

rows = []
for path in results:
    device = re.sub(r"^results-|-\d{6}\.json$", "", os.path.basename(path))
    try:
        walk(json.load(open(path)), rows, device)
    except Exception as exc:  # a truncated bundle is itself a finding
        rows.append((device, "(bundle unreadable)", "Failed", "", [str(exc)], []))

total = len(rows)
failed = [r for r in rows if r[2] == "Failed"]
passed = [r for r in rows if r[2] == "Passed"]
by_device = defaultdict(lambda: [0, 0])
for r in rows:
    by_device[r[0]][0 if r[2] == "Passed" else 1] += 1

def metric_line(test):
    for r in rows:
        if test in r[1] and r[5]:
            return "; ".join(r[5])
    return "not measured (test did not run)"

print(f"# vlogify overnight — {os.path.basename(report)}\n")
print("## The three numbers\n")
print(f"1. **Cold launch**: {metric_line('testColdLaunch')}")
print(f"2. **How fast it works**: open camera — {metric_line('testOpenCamera')}; record→posted — {metric_line('testRecordToPosted')}; stitch a day — {metric_line('testStitchDay')}")
rate = f"{len(failed)}/{total}" if total else "0/0"
print(f"3. **Failures**: {rate} test runs failed across {len(by_device)} device(s). Triage below; proposed fixes in FIXES.md (not applied).\n")
print("## Per device\n")
print("| device | passed | failed |")
print("|---|---|---|")
for device, (ok, bad) in sorted(by_device.items()):
    print(f"| {device} | {ok} | {bad} |")
print("\n## Failed tests\n")
if not failed:
    print("none.")
for device, name, _, duration, msgs, _ in failed:
    print(f"- **{name}** on {device} ({duration})")
    for m in msgs:
        print(f"  - {m}")
print("\n## Screens\n")
for device_dir in sorted(glob.glob(os.path.join(report, "screens", "*"))):
    shots = sorted(glob.glob(os.path.join(device_dir, "*.png")))
    print(f"- {os.path.basename(device_dir)}: {len(shots)} screenshots in `{os.path.relpath(device_dir, report)}/`")
