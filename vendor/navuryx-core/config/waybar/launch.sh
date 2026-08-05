#!/usr/bin/env bash
set -uo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FILE="$RUNTIME_DIR/navuryx-waybar-launch.lock"
LOG_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/navuryx/waybar.log"
NAV_BIN="$CONFIG_HOME/navuryx/bin"
CONFIG="$CONFIG_HOME/waybar/config.jsonc"
STYLE="$CONFIG_HOME/waybar/style.css"

mkdir -p "$(dirname "$LOG_FILE")"

if command -v flock >/dev/null 2>&1; then
  exec 200>"$LOCK_FILE"
  if ! flock -n 200; then
    exit 0
  fi
fi

pkill -x waybar 2>/dev/null || true
sleep 0.2

if [[ -x "$NAV_BIN/navuryx-shell-config" ]]; then
  visible="$("$NAV_BIN/navuryx-shell-config" get waybar_visible 1 2>/dev/null || printf 1)"
  if [[ "$visible" == 0 || "$visible" == false || "$visible" == False ]]; then
    printf 'Waybar hidden by shell.conf (waybar_visible=%s)\n' "$visible" >>"$LOG_FILE"
    exit 0
  fi
  "$NAV_BIN/navuryx-shell-config" write-waybar >/dev/null 2>&1 || true
  runtime="${XDG_RUNTIME_DIR:-/tmp}/navuryx"
  if [[ -f "$runtime/waybar-config.path" ]]; then
    CONFIG="$(cat "$runtime/waybar-config.path")"
  fi
  if [[ -f "$runtime/waybar-style.path" ]]; then
    STYLE="$(cat "$runtime/waybar-style.path")"
  fi
fi

if ! command -v waybar >/dev/null 2>&1; then
  printf 'waybar binary is not installed\n' >>"$LOG_FILE"
  exit 1
fi

if [[ ! -f "$CONFIG" || ! -f "$STYLE" ]]; then
  printf 'Waybar config missing: %s / %s\n' "$CONFIG" "$STYLE" >>"$LOG_FILE"
  exit 1
fi

nohup waybar -c "$CONFIG" -s "$STYLE" >>"$LOG_FILE" 2>&1 &
disown || true
printf 'Waybar started pid=%s config=%s\n' "$!" "$CONFIG" >>"$LOG_FILE"
