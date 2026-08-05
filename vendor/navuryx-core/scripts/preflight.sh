#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" == --source ]]; then ROOT="$2"; fi
required_files=(
  config/hypr/hyprland.lua
  config/hypr/hyprland.conf
  config/hypr/hyprpaper.conf
  config/hypr/navuryx/theme.lua
  config/hypr/navuryx/binds.lua
  config/hypr/navuryx/autostart.lua
  config/waybar/config.jsonc
  config/waybar/style.css
  config/waybar/launch.sh
  config/rofi/navuryx.rasi
  config/navuryx/bin/navuryx-spotlight
  config/navuryx/bin/navuryx-ai
  config/navuryx/bin/navuryx-terminal
  config/navuryx/bin/navuryx-hyprpaper
  config/navuryx/bin/navuryx-wallpaper
  config/navuryx/bin/navuryx-autostart-helpers
  config/navuryx/bin/navuryx-vpn
  config/navuryx/bin/navuryx-doctor
  config/navuryx/bin/navuryx-keybinds
  config/navuryx/bin/navuryx-gaming
  config/navuryx/bin/navuryx-backup
  config/navuryx/bin/navuryx-features
  config/navuryx/features.tsv
  wallpapers/wallpaper.png
)
for file in "${required_files[@]}"; do [[ -f "$ROOT/$file" ]] || { echo "Missing $file" >&2; exit 1; }; done
wall_count="$(find "$ROOT/wallpapers" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | wc -l | tr -d ' ')"
if [[ "${wall_count:-0}" -lt 1 ]]; then
  printf 'Missing wallpaper images under wallpapers/\n' >&2
  exit 1
fi
if command -v jq >/dev/null 2>&1; then
  if ! sed 's#^[[:space:]]*//.*$##' "$ROOT/config/waybar/config.jsonc" | jq empty >/dev/null 2>&1; then
    printf 'Lint notice: waybar/config.jsonc did not parse as strict JSON after comment stripping.\n'
    printf 'Waybar accepts JSONC, so this is a notice only and does not block the install.\n'
  fi
fi
if command -v luac >/dev/null 2>&1; then
  while IFS= read -r lua_file; do
    if ! luac -p "$lua_file" >/dev/null 2>&1; then
      printf 'Lint notice: Lua syntax check failed for %s\n' "$lua_file"
    fi
  done < <(find "$ROOT/config/hypr" -name '*.lua')
fi
missing=()
for command in Hyprland waybar rofi kitty mako hyprpaper hyprlock grim slurp wl-copy cliphist jq curl notify-send; do
  command -v "$command" >/dev/null 2>&1 || missing+=("$command")
done
if ! command -v wlogout >/dev/null 2>&1; then
  printf 'Optional notice: wlogout is not installed (AUR on Arch: yay -S wlogout). Navuryx power menu will use Rofi.\n'
fi
browser_found=0
for browser in firefox chromium brave google-chrome-stable torbrowser-launcher librewolf zen-browser; do
  if command -v "$browser" >/dev/null 2>&1; then
    browser_found=1
    break
  fi
done
if [[ "$browser_found" != 1 ]]; then
  printf 'Optional notice: no supported browser binary detected yet.\n'
fi
discord_found=0
for client in discord Discord vesktop navtop legcord webcord; do
  if command -v "$client" >/dev/null 2>&1; then
    discord_found=1
    break
  fi
done
if [[ "$discord_found" != 1 ]]; then
  printf 'Optional notice: no Discord client is installed (discord, vesktop, navtop, legcord, webcord).\n'
fi
vpn_found=0
for client in protonvpn protonvpn-app mullvad tailscale wg-quick; do
  if command -v "$client" >/dev/null 2>&1; then
    vpn_found=1
    break
  fi
done
if [[ "$vpn_found" != 1 ]]; then
  printf 'Optional notice: no VPN client is installed (NAVURYX_VPNS selects them during install).\n'
fi
if ! command -v spotify-launcher >/dev/null 2>&1 && ! command -v spotify >/dev/null 2>&1; then
  printf 'Optional notice: Spotify is not installed (spotify-launcher on Arch).\n'
fi
export PATH="$HOME/.navify:$PATH"
if ! command -v navify >/dev/null 2>&1; then
  printf 'Optional notice: Navify CLI is not installed (https://github.com/navify/navify-cli).\n'
fi
if ((${#missing[@]})); then
  printf 'Dependency notice: these commands are not currently available: %s\n' "${missing[*]}"
  printf 'Use ./install.sh --install-deps or install their equivalents manually.\n'
fi
printf 'Navuryx package preflight passed.\n'
