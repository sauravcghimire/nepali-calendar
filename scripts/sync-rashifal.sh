#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# sync-rashifal.sh
#
# Copies rashifal JSON files from ~/Desktop/Calendar/rashifal into the
# project's bundled Resources. Run once before ./scripts/build-app.sh whenever
# your source rashifal files change.
#
# Usage:
#   ./scripts/sync-rashifal.sh                              # default source
#   RASHIFAL_SRC=/path/to/rashifal ./scripts/sync-rashifal.sh
# -----------------------------------------------------------------------------
set -euo pipefail

SRC="${RASHIFAL_SRC:-$HOME/Desktop/Calendar/rashifal}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/NepaliCalendar/Sources/NepaliCalendar/Resources/rashifal"

if [ ! -d "$SRC" ]; then
  echo "Source folder not found: $SRC" >&2
  echo "Set RASHIFAL_SRC to the folder that contains <bsYear>/<bsMonth>.json" >&2
  exit 1
fi

echo "==> Syncing rashifal from $SRC to $DEST"
mkdir -p "$DEST"
# -a preserves structure; --delete-excluded keeps the tree in sync
rsync -a --delete --include='*/' --include='*.json' --exclude='*' "$SRC/" "$DEST/"
echo "==> Done"
find "$DEST" -type f -name '*.json' | sort | sed 's,^,  ,'
