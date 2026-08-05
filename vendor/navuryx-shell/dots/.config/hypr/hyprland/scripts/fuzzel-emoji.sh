#!/usr/bin/env bash
set -Eeuo pipefail
MODE="${1:-type}"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DATA_FILE="$SCRIPT_DIR/fuzzel-emoji-data.txt"
[[ -r "$DATA_FILE" ]] || { echo "Emoji data file missing: $DATA_FILE" >&2; exit 1; }
emoji="$(fuzzel --match-mode fzf --dmenu < "$DATA_FILE" | cut -d ' ' -f 1 | tr -d '\n')"
[[ -n "$emoji" ]] || exit 0
case "$MODE" in
  type) wtype "$emoji" || wl-copy "$emoji" ;;
  copy) wl-copy "$emoji" ;;
  both) wtype "$emoji" || true; wl-copy "$emoji" ;;
  *) echo "Usage: $0 [type|copy|both]" >&2; exit 2 ;;
esac
