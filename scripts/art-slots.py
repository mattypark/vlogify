#!/usr/bin/env python3
"""Regenerates docs/ART-SLOTS.md from the Doodle enum, so the brief cannot drift."""
import os, re
os.chdir(os.path.join(os.path.dirname(__file__), ".."))
src = open("ios/VlogifyDesign/Sources/VlogifyDesign/Doodles.swift").read()
sizes, place = {}, {}
for m in re.finditer(r'case ([.\w, ]+): return CGSize\(width: (\d+), height: (\d+)\)', src):
    for name in re.findall(r'\.(\w+)', m.group(1)): sizes[name] = (m.group(2), m.group(3))
for m in re.finditer(r'case ([.\w, ]+): return "([^"]+)"', src):
    for name in re.findall(r'\.(\w+)', m.group(1)): place[name] = m.group(2)
order = re.findall(r'case ([\w, ]+)\n', src.split("public enum Doodle")[1].split("public var size")[0])
names = [n.strip() for grp in order for n in grp.split(",")]
out = ["# Art slots — the brief for the artist", "",
"Every drawing the app shows, by name. Drop a PNG named `<slot>.png` (plus `@2x`, `@3x`)",
"into `ios/Vlogify/Resources/Assets.xcassets/Doodles/` as an image set with that name and",
"the app picks it up; until then it draws a dashed footprint of the same size so nothing",
"has to be re-laid-out later.", "",
"Style: hand-drawn, thick rounded contours, two or three flat colours, transparent",
"background, no shadows. The welcome page is the cool ground (#F5F6F8); the home doodles sit on",
"ink (#08111A), so give those a light outline. The mascot is a cloud with two eyes and a",
"smile — it is also the app icon, so it must read at 32 × 32.", "",
"| slot | size (pt) | where |", "|---|---|---|"]
for n in names:
    if n in sizes: out.append(f"| `{n}` | {sizes[n][0]} × {sizes[n][1]} | {place.get(n, '')} |")
out += ["", "Generated from `Doodle` in `VlogifyDesign/Doodles.swift`; regenerate with", "`python3 scripts/art-slots.py` after adding a slot."]
open("docs/ART-SLOTS.md", "w").write("\n".join(out) + "\n")
print(f"{len(names)} slots")
