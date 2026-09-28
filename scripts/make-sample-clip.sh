#!/usr/bin/env bash
# Renders the bundled two-second sample clip the simulator "records" (it has no
# camera) and that seeded rooms play back. Needs ffmpeg. Output is committed, so this
# only runs when the look of the placeholder changes.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=ios/Vlogify/Resources/sample-clip.mov
# A slow golden-hour gradient with film grain and a quiet room-tone hiss: it reads as
# "a moment someone filmed" in a thumbnail, where test bars read as a broken camera.
ffmpeg -y -v error \
  -f lavfi -i "gradients=size=540x960:rate=30:duration=2:c0=0xf2a65e:c1=0x6d5a8c:c2=0x2c3550:x0=270:y0=0:x1=270:y1=960:speed=0.015" \
  -f lavfi -i "anoisesrc=color=pink:amplitude=0.015:duration=2" \
  -vf "noise=alls=10:allf=t,vignette=PI/5" \
  -c:v libx264 -pix_fmt yuv420p -profile:v baseline -crf 28 -c:a aac -b:a 48k -shortest "$OUT"
ls -la "$OUT"
