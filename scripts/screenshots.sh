#!/usr/bin/env bash
# Regenerates the README images in docs/images. Pass demo recordings as arguments.
# Usage: scripts/screenshots.sh demo1.ts demo2.ts ...
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[[ $# -gt 0 ]] || { echo "usage: $0 demo-recordings..." >&2; exit 1; }
files="$(IFS=:; echo "$*")"
pkill -x combegone 2>/dev/null || true
COMBEGONE_SCREENSHOTS="$ROOT/docs/images" COMBEGONE_DEMO_FILES="$files" \
  "$ROOT/build/ComBeGone.app/Contents/MacOS/combegone"
