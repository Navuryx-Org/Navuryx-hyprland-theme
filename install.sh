#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/install/package-catalog.sh
source "$ROOT/scripts/install/package-catalog.sh"
# shellcheck source=scripts/install/package-manager.sh
source "$ROOT/scripts/install/package-manager.sh"


VERSION="6.4.0"
NO_COLOR=0
VERBOSE=0
LOG_FILE=""
CURRENT_PHASE="startup"
CONFIG_APPLIED=0

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BLUE=$'\033[38;5;69m'; C_PURPLE=$'\033[38;5;141m'
  C_GREEN=$'\033[38;5;78m'; C_YELLOW=$'\033[38;5;220m'; C_RED=$'\033[38;5;203m'
  C_BOLD=$'\033[1m'
else
  C_RESET=''; C_BLUE=''; C_PURPLE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_BOLD=''
fi

say(){ printf '%s\n' "$*"; }
info(){ printf '%s[•]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok(){ printf '%s[✓]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn(){ printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die(){ printf '%s[✗]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }
phase(){ CURRENT_PHASE=$1; printf '\n%s==>%s %s\n' "$C_PURPLE$C_BOLD" "$C_RESET" "$1"; }

run_bash_helper(){
  local relative_path=$1; shift
  local script="$ROOT/$relative_path"
  [[ -f $script ]] || die "Required helper is missing: $relative_path"
  bash "$script" "$@"
}

normalize_repository_permissions(){
  local file
  chmod +x "$ROOT/install.sh" "$ROOT/uninstall.sh" "$ROOT/navuryx" 2>/dev/null || true
  while IFS= read -r -d '' file; do
    if head -c 2 "$file" 2>/dev/null | grep -q '^#!'; then chmod +x "$file" 2>/dev/null || true; fi
  done < <(find "$ROOT/scripts" "$ROOT/vendor" -type f -print0 2>/dev/null)
}

installer_failure(){
  local status=$1 line=$2 cmd=$3
  printf '\n%sNavuryx installation failed%s\n' "$C_RED$C_BOLD" "$C_RESET" >&2
  printf 'Phase: %s\nLine: %s\nExit status: %s\nCommand: %s\n' "$CURRENT_PHASE" "$line" "$status" "$cmd" >&2
  [[ -n $LOG_FILE ]] && printf 'Log: %s\n' "$LOG_FILE" >&2
  [[ -d ${BACKUP:-} ]] && printf 'Backup: %s\n' "$BACKUP" >&2
  if [[ -n ${PACKAGE_MANIFEST:-} && -f ${PACKAGE_MANIFEST}.tmp ]]; then
    mkdir -p "$(dirname "$PACKAGE_MANIFEST")"
    sort -u "${PACKAGE_MANIFEST}.tmp" > "${PACKAGE_MANIFEST%/*}/partial-installed-packages.tsv" 2>/dev/null || true
    printf 'Partial package record: %s\n' "${PACKAGE_MANIFEST%/*}/partial-installed-packages.tsv" >&2
  fi
  [[ $CONFIG_APPLIED == 1 ]] && warn "Configuration activation started. Run ./uninstall.sh --restore-latest to restore the previous desktop."
  printf 'Recovery: ./uninstall.sh --restore-latest\n' >&2
  exit "$status"
}
trap 'installer_failure "$?" "$LINENO" "$BASH_COMMAND"' ERR

MODE=full
ACTION=install
YES=0
INSTALL_DEPS=1
AUR_HELPER=yay
WITH_FLATPAK=0
APP_SOURCE=auto
BUNDLES=""
EXPLICIT_APPS=""
PLAN_ONLY=0
SOFTWARE_FLAGS_SET=0
PROFILE_SET=0

usage() {
  cat <<'HELP'
Navuryx Hyprland Theme installer

Usage:
  ./install.sh                         Guided installer
  ./install.sh --full --install-deps   Full shell and dependencies
  ./install.sh --core                  Waybar/Rofi recovery profile
  ./install.sh --config-only           Install configuration only

Software options:
  --aur-helper yay|paru|both           Yay is required; paru means install both
  --with-paru                         Install Paru alongside required Yay
  --with-flatpak                       Install Flatpak and add user-level Flathub
  --without-flatpak                    Disable Flatpak
  --bundle LIST                        daily,privacy,communication,media,developer,gaming,creator,ai,system,all,none
  --apps LIST                          Comma-separated application IDs
  --app-source auto|native|flatpak     Preferred source for selected applications
  --list-apps                          Show selectable application IDs
  --install-deps                       Install the Navuryx desktop dependency set
  --no-install-deps                    Do not install desktop dependencies
  --plan                               Print package commands without changing the system
  --no-color                           Disable ANSI colors
  --verbose                            Show additional installer details
  --log-file PATH                      Save installer output to a log file

Maintenance:
  --verify                             Show dependency and installation status
  --repair                             Reinstall managed files while preserving overrides
  --yes, -y                            Noninteractive package/configuration confirmation
  --help, -h                           Show this help

Examples:
  ./install.sh --full --install-deps --aur-helper yay --bundle daily
  ./install.sh --full --install-deps --aur-helper both --with-flatpak --bundle daily,gaming
  ./install.sh --apps firefox,navtop,protonvpn --with-paru
HELP
}

need_value() {
  [[ $# -ge 2 && -n ${2:-} ]] || { echo "Missing value for $1" >&2; exit 2; }
}

while (($#)); do
  case "$1" in
    --core|--use-waybar) MODE=core; PROFILE_SET=1 ;;
    --full|--use-quickshell) MODE=full; PROFILE_SET=1 ;;
    --config-only) MODE=config; PROFILE_SET=1 ;;
    --verify) ACTION=verify ;;
    --repair) ACTION=repair; INSTALL_DEPS=0; BUNDLES=none; SOFTWARE_FLAGS_SET=1 ;;
    --install-deps) INSTALL_DEPS=1; SOFTWARE_FLAGS_SET=1 ;;
    --no-install-deps) INSTALL_DEPS=0; SOFTWARE_FLAGS_SET=1 ;;
    --aur-helper)
      need_value "$1" "${2:-}"; AUR_HELPER=$2; SOFTWARE_FLAGS_SET=1; shift ;;
    --aur-helper=*) AUR_HELPER=${1#*=}; SOFTWARE_FLAGS_SET=1 ;;
    --with-paru) AUR_HELPER=both; SOFTWARE_FLAGS_SET=1 ;;
    --without-paru) AUR_HELPER=yay; SOFTWARE_FLAGS_SET=1 ;;
    --with-flatpak) WITH_FLATPAK=1; SOFTWARE_FLAGS_SET=1 ;;
    --without-flatpak|--no-flatpak) WITH_FLATPAK=0; SOFTWARE_FLAGS_SET=1 ;;
    --bundle)
      need_value "$1" "${2:-}"; BUNDLES=$2; SOFTWARE_FLAGS_SET=1; shift ;;
    --bundle=*) BUNDLES=${1#*=}; SOFTWARE_FLAGS_SET=1 ;;
    --apps)
      need_value "$1" "${2:-}"; EXPLICIT_APPS=$2; SOFTWARE_FLAGS_SET=1; shift ;;
    --apps=*) EXPLICIT_APPS=${1#*=}; SOFTWARE_FLAGS_SET=1 ;;
    --app-source)
      need_value "$1" "${2:-}"; APP_SOURCE=$2; SOFTWARE_FLAGS_SET=1; shift ;;
    --app-source=*) APP_SOURCE=${1#*=}; SOFTWARE_FLAGS_SET=1 ;;
    --list-apps) catalog_print; exit 0 ;;
    --plan) PLAN_ONLY=1; YES=1 ;;
    --no-color) NO_COLOR=1 ;;
    --verbose) VERBOSE=1 ;;
    --log-file) need_value "$1" "${2:-}"; LOG_FILE=$2; shift ;;
    --log-file=*) LOG_FILE=${1#*=} ;;
    --yes|-y) YES=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ $NO_COLOR == 1 ]]; then C_RESET=''; C_BLUE=''; C_PURPLE=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_BOLD=''; fi
if [[ -n $LOG_FILE ]]; then mkdir -p "$(dirname "$LOG_FILE")"; exec > >(tee -a "$LOG_FILE") 2>&1; fi
normalize_repository_permissions

case "$AUR_HELPER" in
  yay) ;;
  paru|both) AUR_HELPER=both ;;
  none)
    [[ $MODE == config || $ACTION == repair ]] || { echo "Yay is required for Navuryx software installation." >&2; exit 2; }
    ;;
  *) echo "Invalid --aur-helper: $AUR_HELPER" >&2; exit 2;;
esac
case "$APP_SOURCE" in auto|native|flatpak) ;; *) echo "Invalid --app-source: $APP_SOURCE" >&2; exit 2;; esac

if [[ $MODE == config || $ACTION == repair ]]; then
  INSTALL_DEPS=0
  AUR_HELPER=none
  WITH_FLATPAK=0
  BUNDLES=none
  EXPLICIT_APPS=""
fi

[[ $EUID -eq 0 && ${NAVURYX_ALLOW_ROOT_TEST:-0} != 1 ]] && {
  echo "Do not run Navuryx as root. The installer uses sudo only for system packages." >&2
  exit 1
}

CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
BIN_HOME=${HOME}/.local/bin
NAV_STATE="$STATE_HOME/navuryx"
BACKUP="$NAV_STATE/backups/$(date +%Y%m%d-%H%M%S)"
MANIFEST="$NAV_STATE/managed-files.txt"
PACKAGE_MANIFEST="$NAV_STATE/installed-packages.tsv"

CORE_COMMANDS=(hyprland waybar rofi hyprlock swww grim slurp wl-copy wpctl nmcli)
FULL_COMMANDS=(qs)
OPTIONAL_COMMANDS=(wlogout wf-recorder brightnessctl bluetoothctl playerctl ollama flatpak yay paru navify)
CORE_PACKAGES=(
  hyprland waybar rofi hyprlock hypridle hyprpaper swww
  kitty foot networkmanager network-manager-applet bluez bluez-utils
  pipewire pipewire-pulse wireplumber brightnessctl playerctl wl-clipboard
  grim slurp swappy wf-recorder jq curl git unzip 7zip imagemagick ffmpeg
  fastfetch fzf ripgrep fd python rsync libnotify polkit-kde-agent xdg-desktop-portal-hyprland
  cliphist rofi-calc rofi-emoji power-profiles-daemon udiskie
  noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd papirus-icon-theme
)
FULL_PACKAGES=(quickshell)

command_report() {
  local missing=0 c
  echo "Navuryx dependency report"
  for c in "${CORE_COMMANDS[@]}"; do
    if command -v "$c" >/dev/null 2>&1; then echo "[ok] $c"; else echo "[missing/core] $c"; missing=1; fi
  done
  if [[ $MODE == full ]]; then
    for c in "${FULL_COMMANDS[@]}"; do
      if command -v "$c" >/dev/null 2>&1; then echo "[ok] $c"; else echo "[missing/full] $c"; missing=1; fi
    done
  fi
  for c in "${OPTIONAL_COMMANDS[@]}"; do
    command -v "$c" >/dev/null 2>&1 && echo "[ok/optional] $c" || echo "[optional] $c"
  done
  [[ -f $MANIFEST ]] && echo "[installed] file manifest: $MANIFEST"
  [[ -f $PACKAGE_MANIFEST ]] && echo "[installed] package manifest: $PACKAGE_MANIFEST"
  return "$missing"
}

[[ $ACTION == verify ]] && { command_report || true; exit 0; }

ask_yes_no() {
  local prompt=$1 default=${2:-n} answer suffix='[y/N]'
  [[ $default == y ]] && suffix='[Y/n]'
  read -r -p "$prompt $suffix " answer
  [[ -z $answer ]] && answer=$default
  [[ $answer =~ ^[Yy]$ ]]
}

append_apps(){
  local value=$1
  [[ -n $value ]] || return 0
  EXPLICIT_APPS="${EXPLICIT_APPS:+$EXPLICIT_APPS,}$value"
}

parse_multi_selection(){
  local raw=${1:-} max=${2:?maximum selection count required} defaults=${3:-}
  local -A picked=()
  local token lowered start end value i

  # Copy/paste and some terminals can introduce CR characters.
  raw=${raw//$'\r'/}
  raw=${raw//,/ }
  raw=${raw//;/ }
  [[ -n ${raw//[[:space:]]/} ]] || raw=$defaults

  for token in $raw; do
    lowered=${token,,}
    case "$lowered" in
      a|all)
        for ((i=1; i<=max; i++)); do picked[$i]=1; done
        ;;
      n|none|clear|skip)
        picked=()
        ;;
      *-*)
        start=${lowered%%-*}
        end=${lowered##*-}
        [[ $start =~ ^[0-9]+$ && $end =~ ^[0-9]+$ ]] || return 1
        start=$((10#$start)); end=$((10#$end))
        ((start >= 1 && end >= start && end <= max)) || return 1
        for ((i=start; i<=end; i++)); do picked[$i]=1; done
        ;;
      *)
        [[ $lowered =~ ^[0-9]+$ ]] || return 1
        value=$((10#$lowered))
        ((value >= 1 && value <= max)) || return 1
        picked[$value]=1
        ;;
    esac
  done

  SELECTED_INDEXES=()
  for ((i=1; i<=max; i++)); do
    if [[ ${picked[$i]:-0} == 1 ]]; then
      SELECTED_INDEXES+=("$i")
    fi
  done

  # Do not return the status of the final unchecked item. That made every
  # partial selection look invalid even though it had parsed correctly.
  return 0
}

multi_select(){
  local title=$1 defaults=$2; shift 2
  local -a ids=() labels=()
  while (($#)); do ids+=("$1"); labels+=("$2"); shift 2; done
  local i raw selected_text

  while true; do
    echo
    printf '%s%s%s\n' "$C_BOLD" "$title" "$C_RESET"
    echo "Choose one or more: 1 3 5, 1,3,5, 1-4, a=all, n=none."
    for ((i=0; i<${#ids[@]}; i++)); do
      printf ' %2d) %s\n' "$((i+1))" "${labels[$i]}"
    done

    if ! read -r -p "Selection [${defaults:-none}]: " raw; then
      warn "Input ended before a selection was received. Using the default."
      raw=""
    fi

    if parse_multi_selection "$raw" "${#ids[@]}" "$defaults"; then
      break
    fi
    warn "Invalid selection: '${raw:-<empty>}'. Use only listed numbers, commas, spaces or ranges."
  done

  MULTI_RESULT=()
  selected_text=""
  for i in "${SELECTED_INDEXES[@]}"; do
    MULTI_RESULT+=("${ids[$((i-1))]}")
    selected_text+="${selected_text:+, }${labels[$((i-1))]}"
  done
  info "Selected: ${selected_text:-none}"
}

single_select(){
  local title=$1 default=$2; shift 2
  local -a ids=() labels=()
  while (($#)); do ids+=("$1"); labels+=("$2"); shift 2; done
  local choice i
  while true; do
    echo; printf '%s%s%s\n' "$C_BOLD" "$title" "$C_RESET"
    for ((i=0;i<${#ids[@]};i++)); do printf ' %2d) %s\n' "$((i+1))" "${labels[$i]}"; done
    read -r -p "Choose [$default]: " choice; choice=${choice:-$default}
    if [[ $choice =~ ^[0-9]+$ ]] && ((choice>=1 && choice<=${#ids[@]})); then SINGLE_RESULT=${ids[$((choice-1))]}; break; fi
    warn "Invalid choice."
  done
}

wizard(){
  if [[ -n ${TERM:-} ]]; then clear 2>/dev/null || true; fi
  echo "${C_BLUE}╔══════════════════════════════════════════╗${C_RESET}"
  echo "${C_BLUE}║${C_RESET}       ${C_BOLD}NAVURYX INSTALLER v6.4${C_RESET}          ${C_BLUE}║${C_RESET}"
  echo "${C_BLUE}╚══════════════════════════════════════════╝${C_RESET}"
  echo "Black. Royal blue. Purple. One complete Hyprland desktop."

  phase "System preflight"
  command -v pacman >/dev/null 2>&1 && ok "Arch-compatible package manager detected" || warn "Automatic dependency installation currently targets pacman systems"
  command -v git >/dev/null 2>&1 && ok "Git available" || warn "Git will be installed with dependencies"
  [[ -n ${WAYLAND_DISPLAY:-} || -n ${DISPLAY:-} ]] && info "Graphical session detected" || info "TTY installation mode"
  local free_mb; free_mb=$(df -Pm "$HOME" | awk 'NR==2{print $4}')
  info "Available home-disk space: ${free_mb:-unknown} MB"

  if [[ $PROFILE_SET == 0 ]]; then
    single_select "Installation type" 1 \
      full "Full — complete Navuryx desktop (recommended)" \
      custom "Custom — choose application groups" \
      core "Recovery — Waybar/Rofi essentials only" \
      config "Configuration only — install no packages"
    case "$SINGLE_RESULT" in custom) MODE=full;; *) MODE=$SINGLE_RESULT;; esac
    [[ $SINGLE_RESULT == custom ]] && CUSTOM_MODE=1 || CUSTOM_MODE=0
  else CUSTOM_MODE=0; fi

  if [[ $MODE != config ]]; then
    [[ -n $BUNDLES ]] || BUNDLES="ai,gaming"
    if [[ $INSTALL_DEPS == 1 ]]; then
      ok "Desktop dependencies will be installed"
    else
      warn "Desktop dependency installation was disabled by command-line option"
    fi
    [[ $AUR_HELPER == none ]] && AUR_HELPER=yay
    ok "Yay will be installed when missing"
    ok "Navuryx AI foundation is included"
    ok "Navuryx gaming foundation is included"

    multi_select "Browsers" 1 \
      firefox "Firefox" zen "Zen Browser" brave "Brave" chromium "Chromium" \
      chrome "Google Chrome" librewolf "LibreWolf" vivaldi "Vivaldi" floorp "Floorp" \
      edge "Microsoft Edge" opera "Opera"
    ((${#MULTI_RESULT[@]})) && append_apps "$(IFS=,; echo "${MULTI_RESULT[*]}")"

    multi_select "Discord clients" 1 \
      navtop "Navtop (recommended)" vesktop "Vesktop" discord "Discord" \
      discord-canary "Discord Canary" webcord "WebCord" armcord "ArmCord"
    ((${#MULTI_RESULT[@]})) && append_apps "$(IFS=,; echo "${MULTI_RESULT[*]}")"
    ((${#MULTI_RESULT[@]}>1)) && warn "Multiple Discord clients were selected; only one may own discord:// links at a time."

    multi_select "VPN tools" "3 4" \
      protonvpn "Proton VPN" mullvad "Mullvad" wireguard "WireGuard" openvpn "OpenVPN" \
      nordvpn "NordVPN" surfshark "Surfshark" pia "Private Internet Access"
    ((${#MULTI_RESULT[@]})) && append_apps "$(IFS=,; echo "${MULTI_RESULT[*]}")"

    single_select "Development tools" 2 none "None" basic "Basic — GitHub CLI, Python, Node.js, Bun" full "Full developer bundle"
    case "$SINGLE_RESULT" in basic) append_apps "github-cli,python,node,bun";; full) BUNDLES="$BUNDLES,developer";; esac

    multi_select "Media applications" n spotify "Spotify" cider "Cider" youtube-music "YouTube Music" nuclear "Nuclear" vlc "VLC" mpv "mpv"
    ((${#MULTI_RESULT[@]})) && append_apps "$(IFS=,; echo "${MULTI_RESULT[*]}")"

    multi_select "Creator applications" n obs-studio "OBS Studio" kdenlive "Kdenlive" gimp "GIMP" inkscape "Inkscape" blender "Blender"
    ((${#MULTI_RESULT[@]})) && append_apps "$(IFS=,; echo "${MULTI_RESULT[*]}")"

    ask_yes_no "Enable Flatpak and user-level Flathub?" "$([[ $WITH_FLATPAK == 1 ]] && echo y || echo n)" && WITH_FLATPAK=1 || WITH_FLATPAK=0
    ask_yes_no "Install Paru alongside required Yay?" "$([[ $AUR_HELPER == both ]] && echo y || echo n)" && AUR_HELPER=both || AUR_HELPER=yay

    if [[ $WITH_FLATPAK == 1 ]]; then
      single_select "Application source preference" 1 auto "Auto — repo, custom installer, AUR, then Flatpak" native "Native — repo/custom/AUR only" flatpak "Prefer Flatpak where available"
      APP_SOURCE=$SINGLE_RESULT
    fi
  fi
}

if [[ $YES == 0 && -t 0 ]]; then wizard; fi

if [[ -z $BUNDLES ]]; then
  [[ $MODE == full && $ACTION == install ]] && BUNDLES="ai,gaming" || BUNDLES="none"
fi
if [[ $MODE == full && $ACTION == install ]]; then
  BUNDLES="ai,gaming${BUNDLES:+,$BUNDLES}"
fi

csv_to_unique_apps() {
  local input=$1 token bundle_apps
  local -A seen=()
  SELECTED_APPS=()
  IFS=',' read -ra tokens <<< "$input"
  for token in "${tokens[@]}"; do
    token=${token//[[:space:]]/}
    [[ -n $token ]] || continue
    bundle_apps=$(catalog_bundle_apps "$token") || { echo "Unknown bundle: $token" >&2; exit 2; }
    IFS=',' read -ra expanded <<< "$bundle_apps"
    local id
    for id in "${expanded[@]}"; do [[ -n $id && -z ${seen[$id]:-} ]] && { SELECTED_APPS+=("$id"); seen[$id]=1; }; done
  done
  IFS=',' read -ra tokens <<< "$EXPLICIT_APPS"
  for token in "${tokens[@]}"; do
    token=${token//[[:space:]]/}
    [[ -n $token ]] || continue
    local valid=0 id
    for id in "${NAVURYX_APP_IDS[@]}"; do [[ $id == "$token" ]] && { valid=1; break; }; done
    [[ $valid == 1 ]] || { echo "Unknown application ID: $token" >&2; exit 2; }
    [[ -z ${seen[$token]:-} ]] && { SELECTED_APPS+=("$token"); seen[$token]=1; }
  done
}

csv_to_unique_apps "$BUNDLES"

selected_app() {
  local wanted=$1 id
  for id in "${SELECTED_APPS[@]}"; do
    [[ $id == "$wanted" ]] && return 0
  done
  return 1
}

print_plan() {
  echo
  echo "Navuryx installation plan"
  echo "  Profile:       $MODE"
  echo "  Dependencies:  $([[ $INSTALL_DEPS == 1 ]] && echo install || echo skip)"
  echo "  AUR helper:    $AUR_HELPER"
  echo "  Flatpak:       $([[ $WITH_FLATPAK == 1 ]] && echo enabled || echo disabled)"
  echo "  App source:    $APP_SOURCE"
  if ((${#SELECTED_APPS[@]})); then
    echo "  Applications:"
    local id
    for id in "${SELECTED_APPS[@]}"; do echo "    - $id ($(catalog_label "$id"))"; done
  else
    echo "  Applications:  none"
  fi
  selected_app spotify && echo "  Spotify add-on: Navify CLI (automatic)"
  echo "  Config target: $CONFIG_HOME"
  echo "  Backup:        $BACKUP"
  echo
}

print_plan

if [[ $YES == 0 ]]; then
  ask_yes_no "Apply this plan?" n || exit 0
fi

install_software() {
  phase "Installing software and dependencies"
  [[ $MODE != config ]] || return 0

  # Authenticate sudo once. This is the local system password only; Navuryx
  # disables all interactive Git credential prompts.
  if [[ ${NAVURYX_DRY_RUN:-0} != 1 && $INSTALL_DEPS == 1 && $EUID -ne 0 ]]; then
    info "System packages require your local sudo password once. GitHub credentials are never requested."
    sudo -v
  fi

  if [[ $INSTALL_DEPS == 1 ]]; then
    if [[ $MODE == full ]]; then
      PACKAGE_PURPOSE=dependency install_repo_packages "${CORE_PACKAGES[@]}" "${FULL_PACKAGES[@]}"
    else
      PACKAGE_PURPOSE=dependency install_repo_packages "${CORE_PACKAGES[@]}"
    fi
  fi

  # Yay is prepared before the full dependency graph because some desktop
  # integrations may be available only through the AUR.
  case "$AUR_HELPER" in
    yay) install_aur_helper yay ;;
    both) install_aur_helper yay; install_aur_helper paru ;;
  esac

  if [[ $MODE == full && $INSTALL_DEPS == 1 ]]; then
    export YES AUR_HELPER PACKAGE_MANIFEST NAVURYX_DRY_RUN
    run_bash_helper "scripts/integration/install-navuryx-deps.sh" "$ROOT"
  fi

  [[ $WITH_FLATPAK == 1 ]] && install_flatpak_support
  ((${#SELECTED_APPS[@]} == 0)) || install_app_ids "${SELECTED_APPS[@]}"
  if selected_app spotify; then
    install_navify || warn "Spotify was installed, but Navify could not be installed automatically."
  fi
}

if [[ $PLAN_ONLY == 1 ]]; then
  NAVURYX_DRY_RUN=1
  PLAN_STATE=$(mktemp -d)
  PACKAGE_MANIFEST="$PLAN_STATE/packages.tsv"
  : > "$PACKAGE_MANIFEST.tmp"
  trap 'rm -rf "$PLAN_STATE"' EXIT
  install_software || true
  echo "Plan complete. No Navuryx configuration or system packages were changed."
  exit 0
fi


mkdir -p "$NAV_STATE"
printf '%s\n' "packages" > "$NAV_STATE/active-phase"
if [[ -f $PACKAGE_MANIFEST ]]; then cp "$PACKAGE_MANIFEST" "$PACKAGE_MANIFEST.tmp"; else : > "$PACKAGE_MANIFEST.tmp"; fi
install_software
sort -u "$PACKAGE_MANIFEST.tmp" > "$PACKAGE_MANIFEST"
rm -f "$PACKAGE_MANIFEST.tmp"

phase "Staging and activating Navuryx configuration"
printf '%s\n' "configuration" > "$NAV_STATE/active-phase"
mkdir -p "$BACKUP" "$CONFIG_HOME" "$BIN_HOME" "$NAV_STATE" "$DATA_HOME/navuryx"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE" "$MANIFEST.tmp" "$PACKAGE_MANIFEST.tmp"' EXIT

backup_path() {
  local rel=$1 src="$CONFIG_HOME/$rel"
  [[ -e $src || -L $src ]] || return 0
  mkdir -p "$BACKUP/$(dirname "$rel")"
  cp -a "$src" "$BACKUP/$rel"
}

install_tree() {
  local rel=$1 src="$ROOT/config/$rel" dst="$CONFIG_HOME/$rel"
  [[ -e $src ]] || return 0
  backup_path "$rel"
  mkdir -p "$STAGE/config/$(dirname "$rel")"
  cp -a "$src" "$STAGE/config/$rel"
  mkdir -p "$dst"
  cp -a "$STAGE/config/$rel"/. "$dst"/
  while IFS= read -r source_path; do
    local relative_path=${source_path#"$STAGE/config/$rel/"}
    printf '%s/%s\n' "$dst" "$relative_path" >> "$MANIFEST.tmp"
  done < <(find "$STAGE/config/$rel" \( -type f -o -type l \) -print)
}

: > "$MANIFEST.tmp"
CONFIG_APPLIED=1
for rel in hypr waybar rofi hyprlock wlogout kitty foot gtk-3.0 gtk-4.0 navuryx navtop; do install_tree "$rel"; done
[[ $MODE == full ]] && install_tree quickshell/navuryx

if [[ $MODE == full ]]; then
  run_bash_helper "scripts/integration/install-combined.sh" "$ROOT" "$CONFIG_HOME" "$DATA_HOME" "$STATE_HOME" "$MANIFEST.tmp"
fi

install -m755 "$ROOT/navuryx" "$BIN_HOME/navuryx"
printf '%s\n' "$BIN_HOME/navuryx" >> "$MANIFEST.tmp"
mkdir -p "$CONFIG_HOME/navuryx/scripts"
install -m755 "$ROOT/scripts/diagnostics/navuryx-doctor" "$CONFIG_HOME/navuryx/scripts/navuryx-doctor"
printf '%s\n' "$CONFIG_HOME/navuryx/scripts/navuryx-doctor" >> "$MANIFEST.tmp"

if [[ ! -f "$CONFIG_HOME/navuryx/ai.env.example" ]]; then
  cat > "$CONFIG_HOME/navuryx/ai.env.example" <<'ENV'
NAVURYX_AI_PROVIDER=ollama
NAVURYX_OLLAMA_MODEL=llama3.2
OPENAI_BASE_URL=
OPENAI_API_KEY=
ENV
fi
printf '%s\n' "$CONFIG_HOME/navuryx/ai.env.example" >> "$MANIFEST.tmp"

mkdir -p "$CONFIG_HOME/hypr/user"
if [[ ! -f "$CONFIG_HOME/hypr/user/overrides.conf" ]]; then
  printf '# Personal Navuryx overrides. This file is preserved during repair.\n' > "$CONFIG_HOME/hypr/user/overrides.conf"
fi

cat > "$NAV_STATE/install-options.env" <<OPTIONS
NAVURYX_PROFILE=$MODE
NAVURYX_AUR_HELPER=$AUR_HELPER
NAVURYX_FLATPAK=$WITH_FLATPAK
NAVURYX_APP_SOURCE=$APP_SOURCE
NAVURYX_BUNDLES=$BUNDLES
NAVURYX_APPS=$(IFS=,; echo "${SELECTED_APPS[*]}")
OPTIONS

printf '%s\n' "$BACKUP" > "$NAV_STATE/last-backup"
sort -u "$MANIFEST.tmp" > "$MANIFEST"
rm -f "$MANIFEST.tmp"
printf '%s\n' "complete" > "$NAV_STATE/active-phase"
rm -f "$NAV_STATE/partial-installed-packages.tsv"

phase "Installation complete"
ok "Installed Navuryx ($MODE)"
info "Backup: $BACKUP"
command_report || true
