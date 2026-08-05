#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
NAV_STATE="$DATA_HOME/navuryx"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$NAV_STATE/backups/$TIMESTAMP"
MANIFEST="$BACKUP/manifest"
INSTALL_GTK=1
INSTALL_DEPS=0
CORE_ONLY=0
ASSUME_YES=0
VERIFY_ONLY=0
DEPS_STATUS=skipped

CORE_PACKAGES=(
  hyprland waybar hyprpaper hyprlock rofi-wayland kitty mako jq libnotify
  wl-clipboard grim slurp brightnessctl playerctl polkit-gnome python
  xdg-desktop-portal-hyprland ttf-jetbrains-mono-nerd
)

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]
  --install-deps  Install/check Arch desktop dependencies
                  (yay required; optional paru/Flatpak prompts;
                   browser, Discord client and VPN multi-select,
                   Spotify, Navify CLI)
  --core-only     With --install-deps, install only the essential desktop
                  packages one by one instead of the full catalogue
  --verify        Check an existing install without reinstalling anything
  --no-gtk        Do not replace GTK 3/4 settings
  --yes, -y       Do not ask for confirmation (browsers default to Firefox,
                   Discord official only, no VPN; skips optional paru/Flatpak
                   unless NAVURYX_INSTALL_PARU=1 or NAVURYX_INSTALL_FLATPAK=1)
  --help, -h      Show this help

Selections can also be set without prompting:
  NAVURYX_BROWSERS=firefox,chromium,brave,zen
  NAVURYX_DISCORD=discord,vesktop,navtop,legcord,webcord
  NAVURYX_VPNS=proton,mullvad,wireguard,openvpn,tailscale
Optional helpers with --yes:
  NAVURYX_INSTALL_PARU=1 NAVURYX_INSTALL_FLATPAK=1
EOF
}

for arg in "$@"; do
  case "$arg" in
    --install-deps) INSTALL_DEPS=1 ;;
    --core-only) CORE_ONLY=1 ;;
    --verify) VERIFY_ONLY=1 ;;
    --no-gtk) INSTALL_GTK=0 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; usage; exit 2 ;;
  esac
done

hypr_version() {
  local raw=""
  local candidate
  for candidate in Hyprland hyprland; do
    if command -v "$candidate" >/dev/null 2>&1; then
      raw="$("$candidate" --version 2>/dev/null || true)"
      [[ -n "$raw" ]] && break
    fi
  done
  if [[ -z "$raw" ]] && command -v hyprctl >/dev/null 2>&1; then
    raw="$(hyprctl version 2>/dev/null || true)"
  fi
  if [[ -z "$raw" ]] && command -v pacman >/dev/null 2>&1; then
    raw="$(pacman -Q hyprland 2>/dev/null || true)"
  fi
  printf '%s' "$raw" | grep -Eo '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

version_at_least() {
  local want="$1" have="$2"
  [[ -n "$have" ]] || return 1
  [[ "$(printf '%s\n' "$want" "$have" | sort -V | head -1)" == "$want" ]]
}

HYPR_VERSION="$(hypr_version || true)"
if [[ -z "$HYPR_VERSION" ]]; then
  HYPR_BACKEND=unknown
elif version_at_least 0.55 "$HYPR_VERSION"; then
  HYPR_BACKEND=lua
else
  HYPR_BACKEND=hyprlang
fi

session_report() {
  printf '\n=== Session environment ===\n'
  printf '  Hyprland version   %s\n' "${HYPR_VERSION:-not detected}"
  printf '  Config backend     %s\n' "$HYPR_BACKEND"
  printf '  XDG_CONFIG_HOME    %s\n' "$XDG_CONFIG_HOME"
  printf '  XDG_CURRENT_DESKTOP %s\n' "${XDG_CURRENT_DESKTOP:-unset}"
  printf '  XDG_SESSION_TYPE   %s\n' "${XDG_SESSION_TYPE:-unset}"

  if [[ "$XDG_CONFIG_HOME" != "$HOME/.config" ]]; then
    printf '  [ warn ] XDG_CONFIG_HOME is not ~/.config.\n'
    printf '           Navuryx is being installed to %s.\n' "$XDG_CONFIG_HOME"
    printf '           If your Hyprland session does not set the same value, it will not see this config.\n'
  fi
  if [[ -n "${XDG_CURRENT_DESKTOP:-}" && "${XDG_CURRENT_DESKTOP}" != *Hyprland* ]]; then
    printf '  [ warn ] The current desktop is %s, not Hyprland.\n' "$XDG_CURRENT_DESKTOP"
    printf '           Navuryx only themes Hyprland. Log into the Hyprland session to see it.\n'
  fi
  if command -v uwsm >/dev/null 2>&1; then
    printf '  [ info ] uwsm is installed. Start Hyprland with: uwsm start hyprland-uwsm.desktop\n'
    printf '           uwsm sessions still read %s/hypr, so no extra step is needed.\n' "$XDG_CONFIG_HOME"
  fi
}

active_entrypoint() {
  if [[ "$HYPR_BACKEND" == hyprlang ]]; then
    printf '%s' "$XDG_CONFIG_HOME/hypr/hyprland.conf"
  elif [[ -f "$XDG_CONFIG_HOME/hypr/hyprland.lua" ]]; then
    printf '%s' "$XDG_CONFIG_HOME/hypr/hyprland.lua"
  else
    printf '%s' "$XDG_CONFIG_HOME/hypr/hyprland.conf"
  fi
}

select_entrypoint() {
  local lua="$XDG_CONFIG_HOME/hypr/hyprland.lua"
  local parked="$XDG_CONFIG_HOME/hypr/hyprland.lua.disabled"
  if [[ "$HYPR_BACKEND" == hyprlang ]]; then
    if [[ -f "$lua" ]]; then
      mv -f "$lua" "$parked"
    fi
    printf 'Hyprland %s predates the Lua config backend; hyprland.conf is the active entrypoint.\n' "$HYPR_VERSION"
    printf 'hyprland.lua was parked as hyprland.lua.disabled so it cannot shadow it later.\n'
  else
    if [[ -f "$parked" && ! -f "$lua" ]]; then
      mv -f "$parked" "$lua"
    fi
    rm -f "$parked"
  fi
}

verify_entrypoint_content() {
  local entrypoint="$1"
  local -a needles=()
  local failures=0 needle

  if [[ "$entrypoint" == *hyprland.lua ]]; then
    needles=(
      'hyprland.start'
      'navuryx.theme'
      'navuryx.binds'
      'waybar/launch.sh'
      'navuryx-wallpaper --restore'
    )
    for needle in "${needles[@]}"; do
      if grep -qF -- "$needle" "$entrypoint" 2>/dev/null; then
        printf '  [ ok ]   entrypoint declares %s\n' "$needle"
      else
        printf '  [ FAIL ] entrypoint is missing %s\n' "$needle"
        failures=$((failures + 1))
      fi
    done
    local binds="$XDG_CONFIG_HOME/hypr/navuryx/binds.lua"
    local theme="$XDG_CONFIG_HOME/hypr/navuryx/theme.lua"
    for needle in navuryx-spotlight navuryx-ai navuryx-settings navuryx-control navuryx-overview navuryx-terminal; do
      if grep -qF -- "$needle" "$binds" 2>/dev/null; then
        printf '  [ ok ]   keybind for %s\n' "$needle"
      else
        printf '  [ FAIL ] no keybind for %s in binds.lua\n' "$needle"
        failures=$((failures + 1))
      fi
    done
    if grep -qF 'hl.workspace_rule' "$theme" 2>/dev/null; then
      printf '  [ ok ]   persistent workspaces use hl.workspace_rule\n'
    else
      printf '  [ FAIL ] theme.lua does not call hl.workspace_rule; workspaces will not persist\n'
      failures=$((failures + 1))
    fi
  else
    needles=(
      '~/.config/waybar/launch.sh'
      'navuryx-wallpaper --restore'
      'navuryx-spotlight'
      'navuryx-ai'
      'navuryx-settings'
      'navuryx-control'
      'navuryx-overview'
      'navuryx-terminal'
      'workspace = 10, persistent:true'
    )
    for needle in "${needles[@]}"; do
      if grep -qF -- "$needle" "$entrypoint" 2>/dev/null; then
        printf '  [ ok ]   entrypoint declares %s\n' "$needle"
      else
        printf '  [ FAIL ] entrypoint is missing %s\n' "$needle"
        failures=$((failures + 1))
      fi
    done
  fi

  return "$failures"
}

install_core_packages() {
  if ! command -v pacman >/dev/null 2>&1; then
    printf 'Core dependency mode needs pacman; skipping.\n' >&2
    return 1
  fi
  local failed=() pkg
  for pkg in "${CORE_PACKAGES[@]}"; do
    printf '\n--- installing %s ---\n' "$pkg"
    if sudo pacman -S --needed --noconfirm "$pkg"; then
      continue
    fi
    printf 'pacman could not install %s; continuing with the rest.\n' "$pkg" >&2
    failed+=("$pkg")
  done
  if ((${#failed[@]})); then
    printf '\nThese core packages did not install: %s\n' "${failed[*]}" >&2
    printf 'Retry them manually with: sudo pacman -S %s\n' "${failed[*]}" >&2
    return 1
  fi
  return 0
}

report_missing_binaries() {
  local -a missing_pacman=() missing_aur=()
  local pair binary package
  for pair in \
    'Hyprland:hyprland' 'waybar:waybar' 'hyprpaper:hyprpaper' 'rofi:rofi-wayland' \
    'kitty:kitty' 'mako:mako' 'jq:jq' 'notify-send:libnotify' 'wl-copy:wl-clipboard' \
    'grim:grim' 'slurp:slurp' 'hyprctl:hyprland' 'python3:python'
  do
    binary="${pair%%:*}"
    package="${pair#*:}"
    if command -v "$binary" >/dev/null 2>&1; then
      printf '  [ ok ]   %-12s %s\n' "$binary" "$(command -v "$binary")"
    else
      printf '  [ MISSING ] %-12s needs pacman package %s\n' "$binary" "$package"
      missing_pacman+=("$package")
    fi
  done
  for pair in 'wlogout:wlogout' 'cliphist:cliphist' 'qs:quickshell'; do
    binary="${pair%%:*}"
    package="${pair#*:}"
    if command -v "$binary" >/dev/null 2>&1; then
      printf '  [ ok ]   %-12s %s\n' "$binary" "$(command -v "$binary")"
    else
      printf '  [ warn ] %-12s optional, AUR package %s\n' "$binary" "$package"
      missing_aur+=("$package")
    fi
  done

  if ((${#missing_pacman[@]})); then
    local unique
    unique="$(printf '%s\n' "${missing_pacman[@]}" | sort -u | tr '\n' ' ')"
    printf '\n'
    printf '###############################################################\n' >&2
    printf '#  REQUIRED DESKTOP PROGRAMS ARE NOT INSTALLED                #\n' >&2
    printf '#  Without them the desktop cannot look any different.        #\n' >&2
    printf '###############################################################\n' >&2
    printf 'Run exactly this, then log out and back in:\n' >&2
    printf '  sudo pacman -S --needed %s\n' "${unique% }" >&2
    if ((${#missing_aur[@]})); then
      printf 'Optional extras from the AUR:\n' >&2
      printf '  yay -S %s\n' "$(printf '%s\n' "${missing_aur[@]}" | sort -u | tr '\n' ' ')" >&2
    fi
    return 1
  fi
  return 0
}

verify_install() {
  local wallpaper="$1"
  local failures=0 entrypoint
  entrypoint="$(active_entrypoint)"

  local required=(
    "$XDG_CONFIG_HOME/hypr/hyprpaper.conf"
    "$XDG_CONFIG_HOME/hypr/navuryx/theme.lua"
    "$XDG_CONFIG_HOME/hypr/navuryx/binds.lua"
    "$XDG_CONFIG_HOME/hypr/navuryx/load.lua"
    "$XDG_CONFIG_HOME/waybar/config.jsonc"
    "$XDG_CONFIG_HOME/waybar/style.css"
    "$XDG_CONFIG_HOME/waybar/launch.sh"
    "$XDG_CONFIG_HOME/rofi/navuryx.rasi"
    "$XDG_CONFIG_HOME/navuryx/features.tsv"
    "$entrypoint"
  )
  local executables=(
    navuryx-terminal navuryx-wallpaper navuryx-hyprpaper navuryx-autostart-helpers
    navuryx-spotlight navuryx-ai navuryx-settings navuryx-control navuryx-overview
    navuryx-vpn navuryx-doctor navuryx-keybinds navuryx-gaming navuryx-backup
    navuryx-features navuryx-shell-config navuryx-appearance
  )

  printf '\n=== Navuryx file verification ===\n'
  local path
  for path in "${required[@]}"; do
    if [[ -f "$path" ]]; then
      printf '  [ ok ]   %s\n' "$path"
    else
      printf '  [ FAIL ] missing %s\n' "$path"
      failures=$((failures + 1))
    fi
  done
  if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
    printf '  [ ok ]   %s\n' "$wallpaper"
  else
    printf '  [ FAIL ] no wallpaper image installed\n'
    failures=$((failures + 1))
  fi

  printf '\n=== Executable bits ===\n'
  local name tool
  for name in "${executables[@]}"; do
    tool="$XDG_CONFIG_HOME/navuryx/bin/$name"
    if [[ ! -f "$tool" ]]; then
      printf '  [ FAIL ] missing %s\n' "$tool"
      failures=$((failures + 1))
    elif [[ -x "$tool" ]]; then
      printf '  [ ok ]   %s\n' "$name"
    else
      printf '  [ FAIL ] %s is not executable; its keybind will do nothing\n' "$tool"
      failures=$((failures + 1))
    fi
  done
  if [[ -x "$XDG_CONFIG_HOME/waybar/launch.sh" ]]; then
    printf '  [ ok ]   waybar/launch.sh\n'
  else
    printf '  [ FAIL ] waybar/launch.sh is not executable\n'
    failures=$((failures + 1))
  fi

  printf '\n=== Active Hyprland entrypoint ===\n'
  printf '  detected version   %s\n' "${HYPR_VERSION:-unknown}"
  printf '  config backend     %s\n' "$HYPR_BACKEND"
  printf '  Hyprland will load %s\n' "$entrypoint"
  local entrypoint_failures=0
  verify_entrypoint_content "$entrypoint" || entrypoint_failures=$?
  failures=$((failures + entrypoint_failures))

  printf '\n=== Menu fallbacks without Quickshell ===\n'
  if command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1; then
    printf '  [ ok ]   Quickshell is installed; the graphical panels are available\n'
  else
    printf '  [ info ] Quickshell is not installed; the Rofi menus are used instead\n'
  fi
  for name in navuryx-settings navuryx-control navuryx-overview navuryx-spotlight; do
    tool="$XDG_CONFIG_HOME/navuryx/bin/$name"
    if [[ -x "$tool" ]] && grep -q 'rofi' "$tool" 2>/dev/null; then
      printf '  [ ok ]   %s has a Rofi fallback\n' "$name"
    elif [[ -x "$tool" ]] && grep -q 'menu ' "$tool" 2>/dev/null; then
      printf '  [ ok ]   %s uses the shared Rofi menu helper\n' "$name"
    else
      printf '  [ FAIL ] %s has no usable fallback without Quickshell\n' "$name"
      failures=$((failures + 1))
    fi
  done

  printf '\n=== Desktop programs ===\n'
  local binaries_ok=1
  report_missing_binaries || binaries_ok=0

  session_report

  printf '\n=== Result ===\n'
  if ((failures > 0)); then
    printf '###############################################################\n' >&2
    printf '#  NAVURYX IS NOT CORRECTLY INSTALLED: %s check(s) failed\n' "$failures" >&2
    printf '#  Run this and share the output:                              #\n' >&2
    printf '#    ~/.config/navuryx/bin/navuryx-doctor --state              #\n' >&2
    printf '###############################################################\n' >&2
    return 1
  fi
  printf 'All configuration checks passed.\n'
  if ((binaries_ok == 0)); then
    printf 'Configuration is fine, but required programs are missing. Install them with the command above.\n'
    return 3
  fi
  printf 'Log out completely and log back into Hyprland to see the theme.\n'
  return 0
}

if [[ "$VERIFY_ONLY" == 1 ]]; then
  wallpaper=""
  if [[ -L "$XDG_CONFIG_HOME/navuryx/current-wallpaper" || -f "$XDG_CONFIG_HOME/navuryx/current-wallpaper" ]]; then
    wallpaper="$(readlink -f "$XDG_CONFIG_HOME/navuryx/current-wallpaper" 2>/dev/null || true)"
  fi
  printf 'Navuryx verify (no files are changed)\n'
  verify_status=0
  verify_install "$wallpaper" || verify_status=$?
  exit "$verify_status"
fi

if [[ "$INSTALL_DEPS" == 1 ]]; then
  if [[ "$CORE_ONLY" == 1 ]]; then
    if install_core_packages; then
      DEPS_STATUS=ok
    else
      DEPS_STATUS=incomplete
    fi
  elif NAVURYX_ASSUME_YES="$ASSUME_YES" "$ROOT/scripts/install-deps.sh"; then
    DEPS_STATUS=ok
  else
    DEPS_STATUS=incomplete
    printf '\n'
    printf '===============================================================\n' >&2
    printf 'Dependency install did not finish cleanly.\n' >&2
    printf 'This does NOT stop the Navuryx configuration install; continuing.\n' >&2
    printf 'Re-run with --install-deps --core-only to install just the essentials.\n' >&2
    printf '===============================================================\n\n' >&2
  fi
fi

if ! "$ROOT/scripts/preflight.sh" --source "$ROOT"; then
  printf '\n' >&2
  printf '===============================================================\n' >&2
  printf 'PREFLIGHT FAILED: this Navuryx checkout is incomplete.\n' >&2
  printf 'Nothing was installed. Re-clone the repository and try again:\n' >&2
  printf '  git clone https://github.com/Navuryx-Org/Navuryx-hyprland-theme.git\n' >&2
  printf '===============================================================\n' >&2
  exit 1
fi

if [[ "$HYPR_BACKEND" == hyprlang ]]; then
  printf '\nDetected Hyprland %s, which is older than 0.55.\n' "$HYPR_VERSION"
  printf 'Navuryx will install the hyprland.conf entrypoint instead of hyprland.lua.\n'
  printf 'Everything still applies; upgrading Hyprland is recommended but not required.\n'
elif [[ "$HYPR_BACKEND" == unknown ]]; then
  printf '\nCould not detect a Hyprland version (Hyprland, hyprland, hyprctl and pacman were all tried).\n'
  printf 'Both entrypoints will be installed; Hyprland picks hyprland.lua on 0.55+ and hyprland.conf below that.\n'
fi

items=(hypr waybar rofi kitty mako wlogout navuryx fastfetch)
if [[ -d "$ROOT/config/quickshell" ]]; then items+=(quickshell); fi
if [[ "$INSTALL_GTK" == 1 ]]; then items+=(gtk-3.0 gtk-4.0); fi

existing=()
for item in "${items[@]}"; do
  [[ -e "$XDG_CONFIG_HOME/$item" || -L "$XDG_CONFIG_HOME/$item" ]] && existing+=("$item")
done

printf '\nNavuryx will install these configuration folders:\n  %s\n' "${items[*]}"
if ((${#existing[@]})); then
  printf '\nThese existing folders will be replaced after backup:\n  %s\n' "${existing[*]}"
else
  printf '\nNo matching existing configuration folders were found.\n'
fi
printf 'Backup destination: %s\n\n' "$BACKUP"

if [[ "$ASSUME_YES" != 1 ]]; then
  read -r -p 'Continue? [y/N] ' answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 0
fi

mkdir -p "$BACKUP/config" "$NAV_STATE" "$STATE_HOME/navuryx"
: > "$MANIFEST"

rollback() {
  status=$?
  trap - ERR
  printf '\n' >&2
  printf '###############################################################\n' >&2
  printf '#  NAVURYX INSTALL FAILED WHILE COPYING CONFIGURATION FILES   #\n' >&2
  printf '#  Your previous configuration is being restored.             #\n' >&2
  printf '#  YOUR DESKTOP WILL LOOK UNCHANGED AFTER THIS.               #\n' >&2
  printf '###############################################################\n' >&2
  while IFS='|' read -r item existed; do
    rm -rf "$XDG_CONFIG_HOME/$item"
    if [[ "$existed" == 1 ]]; then cp -a "$BACKUP/config/$item" "$XDG_CONFIG_HOME/$item"; fi
  done < "$MANIFEST"
  printf 'Restored from: %s\n' "$BACKUP" >&2
  printf 'Report this with the output above so it can be fixed.\n' >&2
  exit "$status"
}
trap rollback ERR

for item in "${items[@]}"; do
  target="$XDG_CONFIG_HOME/$item"
  source="$ROOT/config/$item"
  if [[ ! -e "$source" ]]; then
    printf 'Missing package folder: %s\n' "$source" >&2
    false
  fi
  mkdir -p "$XDG_CONFIG_HOME"
  if [[ -e "$target" || -L "$target" ]]; then
    cp -a "$target" "$BACKUP/config/$item"
    printf '%s|1\n' "$item" >> "$MANIFEST"
  else
    printf '%s|0\n' "$item" >> "$MANIFEST"
  fi
  rm -rf "$target"
  cp -a "$source" "$target"
  printf 'Installed %s -> %s\n' "$item" "$target"
done

trap - ERR

find "$XDG_CONFIG_HOME/navuryx/bin" -maxdepth 1 -type f -exec chmod +x {} + 2>/dev/null || true
chmod +x "$XDG_CONFIG_HOME/waybar/launch.sh" 2>/dev/null || true

select_entrypoint

mkdir -p "$XDG_CONFIG_HOME/navuryx/wallpapers" "$STATE_HOME/navuryx"
if [[ -d "$ROOT/wallpapers" ]]; then
  find "$ROOT/wallpapers" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.jxl' \) -exec cp -a {} "$XDG_CONFIG_HOME/navuryx/wallpapers/" \;
fi

default_wall=""
for candidate in wallpaper.png wallpaper1.png navuryx-default.png navuryx-nocturne.jpg wallpaper2.png wallpaper3.png wallpaper4.png navuryx-strata.jpg navuryx-symmetry.jpg; do
  if [[ -f "$XDG_CONFIG_HOME/navuryx/wallpapers/$candidate" ]]; then
    default_wall="$XDG_CONFIG_HOME/navuryx/wallpapers/$candidate"
    break
  fi
done
if [[ -z "$default_wall" ]]; then
  default_wall="$(find "$XDG_CONFIG_HOME/navuryx/wallpapers" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | sort | head -1 || true)"
fi
if [[ -z "$default_wall" || ! -f "$default_wall" ]]; then
  printf 'Install verification failed; no wallpaper image found under wallpapers/.\n' >&2
  exit 1
fi

cat > "$XDG_CONFIG_HOME/navuryx/wallpaper.conf" <<EOF
wallpaper {
    monitor =
    path = $default_wall
    fit_mode = cover
}
EOF

cat > "$XDG_CONFIG_HOME/hypr/hyprpaper.conf" <<EOF
splash = false
ipc = true

wallpaper {
    monitor =
    path = $default_wall
    fit_mode = cover
}
EOF

ln -sfn "$default_wall" "$XDG_CONFIG_HOME/navuryx/current-wallpaper"

if [[ -f "$XDG_CONFIG_HOME/hypr/hyprlock.conf" ]]; then
  sed -i "s|path = .*navuryx/wallpapers/.*|path = $default_wall|" "$XDG_CONFIG_HOME/hypr/hyprlock.conf" 2>/dev/null || true
fi

printf 'Default wallpaper: %s\n' "$default_wall"

printf '%s\n' "$BACKUP" > "$NAV_STATE/last-backup"
printf '%s\n' "${items[@]}" > "$NAV_STATE/installed-items"
printf '%s\n' "$ROOT" > "$NAV_STATE/install-source"
{
  printf 'Navuryx 1.2 installed %s\n' "$(date -Iseconds)"
  printf 'Backup: %s\n' "$BACKUP"
  printf 'Source: %s\n' "$ROOT"
  printf 'Hyprland: %s\n' "${HYPR_VERSION:-unknown}"
  printf 'Backend: %s\n' "$HYPR_BACKEND"
  printf 'Entrypoint: %s\n' "$(active_entrypoint)"
  printf 'Commit: %s\n' "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || printf unknown)"
} > "$XDG_CONFIG_HOME/navuryx/.navuryx-install"
mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Videos/Captures" "$DATA_HOME/navuryx/ai-history" "$DATA_HOME/navuryx/profiles"

verify_status=0
verify_install "$default_wall" || verify_status=$?

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
  printf '\nActive Hyprland session detected.\n'
  printf 'Hyprland chooses hyprland.lua vs hyprland.conf only at compositor start.\n'
  printf 'Attempting reload + Waybar restart now; a full logout is still required if the session started on the old format.\n'
  hyprctl reload >/dev/null 2>&1 || true
  if [[ -x "$XDG_CONFIG_HOME/navuryx/bin/navuryx-wallpaper" ]]; then
    "$XDG_CONFIG_HOME/navuryx/bin/navuryx-wallpaper" --restore >/dev/null 2>&1 || true
  fi
  if [[ -x "$XDG_CONFIG_HOME/waybar/launch.sh" ]]; then
    "$XDG_CONFIG_HOME/waybar/launch.sh" >/dev/null 2>&1 || true
  else
    pkill -x waybar 2>/dev/null || true
    nohup waybar >"$STATE_HOME/navuryx/waybar.log" 2>&1 &
  fi
  errors="$(hyprctl configerrors 2>/dev/null || true)"
  if [[ -n "$errors" && "$errors" != *"no errors"* ]]; then
    printf '\nHyprland reported configuration errors:\n%s\n' "$errors" >&2
  fi
fi

if ((verify_status == 1)); then
  printf '\nThe configuration files were installed, but the checks above did not all pass.\n' >&2
  printf 'Fix the items marked FAIL or MISSING, then run: ./install.sh --verify\n' >&2
  exit 1
fi

printf '\nNavuryx installed successfully.\n'
if [[ "$DEPS_STATUS" == incomplete ]]; then
  printf 'Note: some optional dependencies failed to install; the theme itself is installed.\n'
fi
printf 'Active entrypoint: %s\n' "$(active_entrypoint)"
printf 'Your previous configuration is in:\n  %s\n' "$BACKUP"
printf '\nIMPORTANT: log out completely, then log back into Hyprland.\n'
printf 'If the UI still looks unchanged, reboot once so the display manager starts a fresh Hyprland session.\n'
printf 'Default shortcuts after login:\n'
printf '  Super+Enter or Super+T  open terminal\n'
printf '  Super+Space             Spotlight search\n'
printf '  Super+A                 AI assistant\n'
printf '  Super+, or Super+I      settings / welcome options\n'
printf '  Super+N                 control center\n'
printf '  Super+Tab               workspace overview\n'
printf '  Super+1-0               switch workspaces\n'
printf '  Ctrl+Super+Shift+D      toggle dark/light\n'
printf '  Super+W                 wallpaper picker\n'
printf '  Super+K                 keybinding cheatsheet\n'
printf '  Super+Shift+V           VPN menu\n'
printf '  Super+Shift+G           gaming mode toggle\n'
printf 'To re-check this install at any time:\n  ./install.sh --verify\n'
printf 'For local AI setup, run:\n  %s/navuryx/bin/navuryx-ai-setup\n' "$XDG_CONFIG_HOME"
printf 'To apply Waybar/wallpaper in the current session without waiting for logout:\n'
printf '  %s/navuryx/bin/navuryx-activate\n' "$XDG_CONFIG_HOME"
printf 'If keybinds/UI still do nothing after logout, force the .conf entrypoint:\n'
printf '  %s/navuryx/bin/navuryx-activate --use-conf\n' "$XDG_CONFIG_HOME"
printf '  then fully log out and back into Hyprland.\n'
printf 'Spotify: Super+Shift+M, or Spotlight/command palette, or run navuryx-spotify\n'
printf 'If the desktop still looks unchanged after logout, run this and share the output:\n'
printf '  %s/navuryx/bin/navuryx-doctor --state\n' "$XDG_CONFIG_HOME"
printf 'To restore the old theme, run:\n  ~/.config/navuryx/bin/navuryx-uninstall --restore\n'

if ((verify_status == 3)); then
  printf '\n' >&2
  printf 'ACTION REQUIRED: the theme is installed but the programs it draws with are not.\n' >&2
  printf 'Install them with the pacman command printed above, then log out and back in.\n' >&2
  exit 3
fi
