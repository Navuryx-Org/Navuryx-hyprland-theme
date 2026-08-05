#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
VERSION=6.4.0
while (($#)); do
  case "$1" in
    --version) VERSION=${2:?version required}; shift;;
    --version=*) VERSION=${1#*=};;
    --help|-h) echo 'Usage: ./scripts/build-release.sh [--version VERSION]'; exit 0;;
    *) echo "Unknown option: $1" >&2; exit 2;;
  esac
  shift
done
DIST="$ROOT/dist"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$DIST" "$STAGE/navuryx-hyprland-theme"
rsync -a --delete \
  --exclude '.git/' --exclude 'dist/' --exclude 'tests/' --exclude 'test/' \
  "$ROOT/" "$STAGE/navuryx-hyprland-theme/"
find "$STAGE" -type d \( -name tests -o -name test \) -prune -exec rm -rf {} + 2>/dev/null || true
find "$STAGE" -type f \( -name 'test-*' -o -name 'test_*' -o -name '*.test.js' -o -name '*.spec.js' \) -delete

# Preserve working launchers even when the source came from a ZIP or filesystem
# that discarded Unix executable bits.
while IFS= read -r -d '' file; do
  if head -c 2 "$file" 2>/dev/null | grep -q '^#!'; then
    chmod 0755 "$file"
  fi
done < <(find "$STAGE/navuryx-hyprland-theme" -type f -print0)

archive="$DIST/navuryx-hyprland-theme-v${VERSION}.zip"
rm -f "$archive" "$archive.sha256"
(cd "$STAGE" && zip -qr "$archive" navuryx-hyprland-theme)
sha256sum "$archive" > "$archive.sha256"
echo "Created $archive"
