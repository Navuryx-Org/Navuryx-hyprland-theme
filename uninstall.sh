#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VERSION="6.4.0"
YES=0
RESTORE=1
PURGE=1
REMOVE_APPS=1
REMOVE_HELPERS=1
REMOVE_DEPS=1
REMOVE_FLATPAK=1
NO_COLOR=0

usage() {
  cat <<'HELP'
Navuryx complete uninstaller

Usage:
  ./uninstall.sh             Remove everything Navuryx installed and restore the previous desktop
  ./uninstall.sh --yes       Do the same without confirmation

Default removal includes:
  - Navuryx configuration, shell files, commands, state, logs and backups
  - Applications and dependencies recorded as newly installed by Navuryx
  - Yay/Paru only when Navuryx installed them
  - Flatpak applications, the Flatpak package and Flathub remote only when Navuryx added them
  - Navify installed automatically for Spotify
  - The newest pre-Navuryx configuration is restored when available

Keep options:
  --keep-installed-apps      Keep selected applications
  --keep-helpers             Keep Yay/Paru
  --keep-dependencies        Keep desktop dependencies and MicroTeX
  --keep-flatpak             Keep Flatpak and the Navuryx-added Flathub remote
  --keep-backups             Keep Navuryx state, logs and backups
  --no-restore               Do not restore the previous desktop configuration

Compatibility options:
  --restore-latest, --purge, --remove-installed-apps, --remove-helpers,
  --remove-dependencies and --remove-flatpak remain accepted.

Other:
  --yes, -y                 Skip confirmation prompts
  --no-color                Disable ANSI colors
  --help, -h                Show this help

Only packages recorded as newly installed by Navuryx are removed. Software that
was already present before installation is not added to the removal manifest.
HELP
}

while (($#)); do
  case "$1" in
    --yes|-y) YES=1 ;;
    --restore-latest) RESTORE=1 ;;
    --purge) PURGE=1 ;;
    --remove-installed-apps) REMOVE_APPS=1 ;;
    --remove-helpers) REMOVE_HELPERS=1 ;;
    --remove-dependencies) REMOVE_DEPS=1 ;;
    --remove-flatpak) REMOVE_FLATPAK=1 ;;
    --keep-installed-apps) REMOVE_APPS=0 ;;
    --keep-helpers) REMOVE_HELPERS=0 ;;
    --keep-dependencies) REMOVE_DEPS=0 ;;
    --keep-flatpak) REMOVE_FLATPAK=0 ;;
    --keep-backups) PURGE=0 ;;
    --no-restore) RESTORE=0 ;;
    --no-color) NO_COLOR=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ $EUID -eq 0 && ${NAVURYX_ALLOW_ROOT_TEST:-0} != 1 ]] && {
  echo "Do not run the Navuryx uninstaller as root." >&2
  exit 1
}

if [[ -t 1 && $NO_COLOR == 0 ]]; then
  RESET=$'\033[0m'; BLUE=$'\033[38;5;69m'; PURPLE=$'\033[38;5;141m'
  GREEN=$'\033[38;5;78m'; YELLOW=$'\033[38;5;220m'; RED=$'\033[38;5;203m'; BOLD=$'\033[1m'
else
  RESET=''; BLUE=''; PURPLE=''; GREEN=''; YELLOW=''; RED=''; BOLD=''
fi
info(){ printf '%s[•]%s %s\n' "$BLUE" "$RESET" "$*"; }
ok(){ printf '%s[✓]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s[!]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
fail(){ printf '%s[✗]%s %s\n' "$RED" "$RESET" "$*" >&2; }
phase(){ printf '\n%s==>%s %s\n' "$PURPLE$BOLD" "$RESET" "$*"; }

CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
BIN_HOME=$HOME/.local/bin
NAV_STATE="$STATE_HOME/navuryx"
MANIFEST="$NAV_STATE/managed-files.txt"
PACKAGE_MANIFEST="$NAV_STATE/installed-packages.tsv"
PARTIAL_PACKAGE_MANIFEST="$NAV_STATE/partial-installed-packages.tsv"
LOG_DIR="$NAV_STATE/logs"
LOG_FILE="$LOG_DIR/uninstall-$(date +%Y%m%d-%H%M%S).log"

for value in "$HOME" "$CONFIG_HOME" "$STATE_HOME" "$DATA_HOME" "$BIN_HOME"; do
  [[ -n $value && $value != / ]] || { echo "Unsafe path detected: '$value'" >&2; exit 1; }
done
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

ask_yes_no() {
  local prompt=$1 default=${2:-n} answer suffix='[y/N]'
  [[ $default == y ]] && suffix='[Y/n]'
  read -r -p "$prompt $suffix " answer || answer="$default"
  [[ -z $answer ]] && answer=$default
  [[ $answer =~ ^[Yy]$ ]]
}

is_allowed_managed_path() {
  local path=$1
  case "$path" in
    "$CONFIG_HOME"/*|"$BIN_HOME"/*|"$DATA_HOME/navuryx"/*|"$DATA_HOME/navuryx") return 0 ;;
    *) return 1 ;;
  esac
}

remove_one_path() {
  local path=$1
  [[ -e $path || -L $path ]] || return 0
  if is_allowed_managed_path "$path"; then
    rm -f -- "$path" 2>/dev/null || {
      [[ -d $path ]] && rmdir --ignore-fail-on-non-empty "$path" 2>/dev/null || true
    }
  else
    warn "Skipped path outside Navuryx-managed roots: $path"
  fi
}

remove_manifest_files() {
  local manifest=$1
  [[ -f $manifest ]] || return 1
  info "Using managed-file manifest: $manifest"
  # Deepest paths first prevents parent directories from interfering with file
  # cleanup and makes repeated uninstalls safe.
  awk 'NF && !seen[$0]++ { print length($0) "\t" $0 }' "$manifest" \
    | sort -rn \
    | cut -f2- \
    | while IFS= read -r path; do remove_one_path "$path"; done
  return 0
}

remove_source_inventory() {
  local rel src source_path target removed=0
  [[ -d $ROOT/config ]] || return 1
  info "Manifest unavailable or incomplete; using the repository file inventory."
  for rel in hypr waybar rofi hyprlock wlogout kitty foot gtk-3.0 gtk-4.0 navuryx navtop quickshell/navuryx; do
    src="$ROOT/config/$rel"
    [[ -d $src ]] || continue
    while IFS= read -r -d '' source_path; do
      target="$CONFIG_HOME/$rel/${source_path#"$src/"}"
      if [[ -e $target || -L $target ]]; then rm -f -- "$target"; removed=1; fi
    done < <(find "$src" \( -type f -o -type l \) -print0)
  done
  return "$((removed == 0))"
}

remove_known_navuryx_paths() {
  # These directories are uniquely owned by Navuryx and are safe to remove as
  # a fallback after failed/older installs. Shared application directories are
  # handled only through the manifest/source inventory above.
  local paths=(
    "$CONFIG_HOME/navuryx"
    "$CONFIG_HOME/navtop"
    "$CONFIG_HOME/quickshell/navuryx"
    "$DATA_HOME/navuryx/components"
    "$BIN_HOME/navuryx"
  )
  local path
  if [[ $REMOVE_APPS == 1 && -f $NAV_STATE/navify-installed ]]; then
    paths+=("$BIN_HOME/navify" "$CONFIG_HOME/navify")
  fi
  for path in "${paths[@]}"; do
    [[ -e $path || -L $path ]] || continue
    case "$path" in
      "$CONFIG_HOME/navuryx"|"$CONFIG_HOME/navtop"|"$CONFIG_HOME/quickshell/navuryx"|"$DATA_HOME/navuryx/components"|"$CONFIG_HOME/navify") rm -rf -- "$path" ;;
      *) rm -f -- "$path" ;;
    esac
  done
}

prune_empty_directories() {
  local root
  for root in \
    "$CONFIG_HOME/quickshell" "$CONFIG_HOME/hypr" "$CONFIG_HOME/waybar" "$CONFIG_HOME/rofi" \
    "$CONFIG_HOME/hyprlock" "$CONFIG_HOME/wlogout" "$CONFIG_HOME/kitty" "$CONFIG_HOME/foot" \
    "$CONFIG_HOME/gtk-3.0" "$CONFIG_HOME/gtk-4.0" "$DATA_HOME/navuryx"; do
    [[ -d $root ]] || continue
    find "$root" -depth -type d -empty -delete 2>/dev/null || true
  done
}

latest_backup() {
  local latest=""
  if [[ -f $NAV_STATE/last-backup ]]; then
    IFS= read -r latest < "$NAV_STATE/last-backup" || true
  fi
  if [[ -z $latest || ! -d $latest ]]; then
    latest=$(find "$NAV_STATE/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1 || true)
  fi
  printf '%s' "$latest"
}

restore_latest_backup() {
  local latest
  latest=$(latest_backup)
  if [[ -n $latest && -d $latest ]]; then
    mkdir -p "$CONFIG_HOME"
    cp -a "$latest"/. "$CONFIG_HOME"/
    ok "Restored previous configuration from: $latest"
  else
    warn "No Navuryx backup was found. Configuration removal still completed."
    return 1
  fi
}

collect_package_records() {
  local file
  for file in "$PACKAGE_MANIFEST" "$PARTIAL_PACKAGE_MANIFEST"; do
    if [[ -f $file ]]; then
      cat "$file"
    fi
  done | awk -F '\t' 'NF >= 2 && !seen[$1 FS $2]++'
  return 0
}

remove_recorded_packages() {
  local records
  records=$(mktemp)
  collect_package_records > "$records"
  if [[ ! -s $records ]]; then
    info "No recorded package changes were found."
    rm -f "$records"
    return 0
  fi

  local kind name
  local native=() flatpaks=() custom_paths=() custom_apps=() flatpak_remotes=()
  while IFS=$'\t' read -r kind name; do
    [[ -n $kind && -n $name ]] || continue
    case "$kind" in
      repo-app|aur-app|github-app) [[ $REMOVE_APPS == 1 ]] && native+=("$name") ;;
      aur-helper) [[ $REMOVE_HELPERS == 1 ]] && native+=("$name") ;;
      repo-dependency|aur-dependency|repo-app-dependency) [[ $REMOVE_DEPS == 1 ]] && native+=("$name") ;;
      custom-dependency) [[ $REMOVE_DEPS == 1 ]] && custom_paths+=("$name") ;;
      custom-app) [[ $REMOVE_APPS == 1 ]] && custom_apps+=("$name") ;;
      repo-runtime) [[ $REMOVE_FLATPAK == 1 ]] && native+=("$name") ;;
      flatpak-app) [[ $REMOVE_APPS == 1 ]] && flatpaks+=("$name") ;;
      flatpak-remote) [[ $REMOVE_FLATPAK == 1 ]] && flatpak_remotes+=("$name") ;;
    esac
  done < "$records"
  rm -f "$records"

  if ((${#flatpaks[@]})) && command -v flatpak >/dev/null 2>&1; then
    local installed_flatpaks=() app
    for app in "${flatpaks[@]}"; do flatpak info --user "$app" >/dev/null 2>&1 && installed_flatpaks+=("$app"); done
    if ((${#installed_flatpaks[@]})); then
      local flatpak_cmd=(flatpak uninstall --user)
      [[ $YES == 1 ]] && flatpak_cmd+=(-y)
      flatpak_cmd+=("${installed_flatpaks[@]}")
      "${flatpak_cmd[@]}" || warn "Some Flatpak applications could not be removed."
    fi
  fi

  if ((${#flatpak_remotes[@]})) && command -v flatpak >/dev/null 2>&1; then
    local remote
    for remote in "${flatpak_remotes[@]}"; do
      flatpak remote-delete --user --force "$remote" >/dev/null 2>&1 || true
    done
  fi

  if ((${#custom_apps[@]})); then
    local custom_app
    for custom_app in "${custom_apps[@]}"; do
      case "$custom_app" in
        "$BIN_HOME/navify") rm -f -- "$BIN_HOME/navify" ;;
        *) warn "Skipped unknown custom application path: $custom_app" ;;
      esac
    done
  fi
  if [[ $REMOVE_APPS == 1 && -f $NAV_STATE/navify-installed ]]; then
    local navify_path
    IFS= read -r navify_path < "$NAV_STATE/navify-installed" || true
    [[ $navify_path == "$BIN_HOME/navify" ]] && rm -f -- "$navify_path"
    rm -rf -- "$CONFIG_HOME/navify"
  fi

  if ((${#native[@]})) && command -v pacman >/dev/null 2>&1; then
    local -A seen=()
    local installed_native=() pkg
    for pkg in "${native[@]}"; do
      [[ -z ${seen[$pkg]:-} ]] || continue
      seen[$pkg]=1
      pacman -Q "$pkg" >/dev/null 2>&1 && installed_native+=("$pkg")
    done
    if ((${#installed_native[@]})); then
      info "Removing recorded packages: ${installed_native[*]}"
      local native_cmd=(sudo pacman -Rns)
      [[ $YES == 1 ]] && native_cmd+=(--noconfirm)
      native_cmd+=("${installed_native[@]}")
      "${native_cmd[@]}" || warn "Pacman kept packages that are still required by other software."
    fi
  fi

  local custom
  for custom in "${custom_paths[@]}"; do
    case "$custom" in
      /opt/MicroTeX) sudo rm -rf -- /opt/MicroTeX || warn "Could not remove /opt/MicroTeX" ;;
      *) warn "Skipped unknown custom dependency path: $custom" ;;
    esac
  done
}

printf '%s╭──────────────────────────────────────────╮%s\n' "$PURPLE" "$RESET"
printf '%s│%s %sNavuryx removal utility v%s%s          %s│%s\n' "$PURPLE" "$RESET" "$BOLD" "$VERSION" "$RESET" "$PURPLE" "$RESET"
printf '%s╰──────────────────────────────────────────╯%s\n' "$PURPLE" "$RESET"
info "Log: $LOG_FILE"

if [[ $YES != 1 ]]; then
  echo
  echo "This performs a complete Navuryx removal."
  [[ $RESTORE == 1 ]] && echo "- Restore the newest pre-Navuryx configuration when available."
  [[ $REMOVE_APPS == 1 ]] && echo "- Remove recorded applications, including Navify installed for Spotify."
  [[ $REMOVE_HELPERS == 1 ]] && echo "- Remove recorded Yay/Paru packages."
  [[ $REMOVE_DEPS == 1 ]] && echo "- Remove recorded desktop dependencies and MicroTeX."
  [[ $REMOVE_FLATPAK == 1 ]] && echo "- Remove recorded Flatpak apps/runtime and Navuryx-added Flathub remote."
  [[ $PURGE == 1 ]] && echo "- Delete Navuryx backups, manifests, state and logs after restoration."
  ask_yes_no "Continue?" n || exit 0
fi

phase "Removing Navuryx-managed files"
manifest_used=0
if remove_manifest_files "$MANIFEST"; then manifest_used=1; fi
# Also clean exact files from the current repository. This repairs old or
# partial manifests without deleting unrelated user configuration.
remove_source_inventory || true
remove_known_navuryx_paths
prune_empty_directories
ok "Navuryx configuration removal completed"

if [[ $REMOVE_APPS == 1 || $REMOVE_HELPERS == 1 || $REMOVE_DEPS == 1 || $REMOVE_FLATPAK == 1 ]]; then
  phase "Removing explicitly selected software"
  remove_recorded_packages
fi

if [[ $RESTORE == 1 ]]; then
  phase "Restoring previous configuration"
  restore_latest_backup || true
fi

if [[ $PURGE == 1 ]]; then
  phase "Purging Navuryx state"
  # The main confirmation already covers complete removal; do not prompt twice.
  rm -rf -- "$NAV_STATE" "$DATA_HOME/navuryx"
  ok "Removed Navuryx state and backups"
else
  rm -f -- "$MANIFEST" "$PACKAGE_MANIFEST" "$PARTIAL_PACKAGE_MANIFEST" "$NAV_STATE/active-phase"
  info "Backups were kept in: $NAV_STATE/backups"
fi

phase "Removal complete"
ok "Navuryx has been removed"
if [[ $RESTORE == 0 ]]; then info "Restore later with: ./uninstall.sh --restore-latest"; fi
if [[ $PURGE == 0 ]]; then info "Log: $LOG_FILE"; fi
exit 0
