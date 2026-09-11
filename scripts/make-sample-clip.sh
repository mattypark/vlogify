#!/usr/bin/env bash
# Renders the bundled two-second sample clip the simulator "records" (it has no
# camera) and that seeded rooms play back. Needs ffmpeg. Output is committed, so this
# only runs when the look of the placeholder changes.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=ios/Vlogify/Resources/sample-clip.mov
ffmpeg -y -v error \
  -f lavfi -i "testsrc2=size=540x960:rate=30:duration=2" \
  -f lavfi -i "sine=frequency=330:duration=2" \
  -vf "hue=s=0.35,eq=brightness=-0.15" \
  -c:v libx264 -pix_fmt yuv420p -profile:v baseline -crf 28 -c:a aac -b:a 48k -shortest "$OUT"
ls -la "$OUT"
