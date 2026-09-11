#!/usr/bin/env bash
# Regenerates the Xcode project from ios/project.yml and resolves packages.
#
# The .xcodeproj is generated and gitignored -- project.yml is the source of truth.
# Run this after adding or removing a source file; XcodeGen picks up new files only on
# a regenerate, and a missing file shows up as a baffling "has no member" error.
set -euo pipefail

cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || {
  echo "xcodegen not found. brew install xcodegen" >&2
  exit 1
}

cd ios
xcodegen generate
xcodebuild -resolvePackageDependencies -project Vlogify.xcodeproj -scheme Vlogify >/dev/null

echo "Vlogify.xcodeproj regenerated. open ios/Vlogify.xcodeproj"
