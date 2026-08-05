#!/usr/bin/env bash
set -uo pipefail

STATUS_LINES=()
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
NAV_STATE="$DATA_HOME/navuryx"
PKG_MANIFEST="$NAV_STATE/installed-packages"

NAVTOP_REPO="Navcord/Navtop"
NAVTOP_URL="https://github.com/Navcord/Navtop"
NAVTOP_HOME="$DATA_HOME/navtop"
NAVTOP_BIN="$HOME/.local/bin/navtop"
NAVTOP_DESKTOP="$DATA_HOME/applications/navtop.desktop"

confirm() {
  [[ "${NAVURYX_ASSUME_YES:-0}" == 1 ]] && return 0
  read -r -p "$1 [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

ensure_pkg_manifest() {
  mkdir -p "$NAV_STATE"
  touch "$PKG_MANIFEST"
}

record_installed() {
  local kind="$1"
  local name="$2"
  [[ -z "$name" ]] && return 0
  ensure_pkg_manifest
  if ! grep -qxF "${kind}|${name}" "$PKG_MANIFEST" 2>/dev/null; then
    printf '%s|%s\n' "$kind" "$name" >> "$PKG_MANIFEST"
  fi
}

record_status() {
  STATUS_LINES+=("$1|$2")
}

print_status_summary() {
  printf '\n=== Navuryx optional install summary ===\n'
  local line name state
  if ((${#STATUS_LINES[@]} == 0)); then
    printf 'No optional apps were attempted.\n'
    return 0
  fi
  for line in "${STATUS_LINES[@]}"; do
    name="${line%%|*}"
    state="${line#*|}"
    printf '  %-12s %s\n' "$name" "$state"
  done
  printf '=======================================\n'
  if [[ -f "$PKG_MANIFEST" ]]; then
    printf 'Package manifest: %s\n' "$PKG_MANIFEST"
  fi
}

aur_helper() {
  if command -v yay >/dev/null 2>&1; then
    printf 'yay'
  elif command -v paru >/dev/null 2>&1; then
    printf 'paru'
  else
    return 1
  fi
}

pkg_present() {
  local pkg="$1"
  local bin="${2:-$1}"
  if command -v pacman >/dev/null 2>&1 && pacman -Q "$pkg" >/dev/null 2>&1; then
    return 0
  fi
  if command -v rpm >/dev/null 2>&1 && rpm -q "$pkg" >/dev/null 2>&1; then
    return 0
  fi
  command -v "$bin" >/dev/null 2>&1
}

zen_available() {
  pkg_present zen-browser-bin zen-browser \
    || command -v zen-browser >/dev/null 2>&1 \
    || command -v zen >/dev/null 2>&1 \
    || [[ -x /usr/bin/zen-browser ]] \
    || [[ -x /usr/bin/zen ]] \
    || compgen -G /usr/share/applications/*zen*.desktop >/dev/null 2>&1 \
    || (command -v flatpak >/dev/null 2>&1 && flatpak info app.zen_browser.zen >/dev/null 2>&1)
}

spotify_available() {
  pkg_present spotify-launcher spotify-launcher \
    || command -v spotify-launcher >/dev/null 2>&1 \
    || command -v spotify >/dev/null 2>&1 \
    || (command -v flatpak >/dev/null 2>&1 && flatpak info com.spotify.Client >/dev/null 2>&1)
}

navify_available() {
  export PATH="$HOME/.navify:$HOME/.local/bin:$PATH"
  command -v navify >/dev/null 2>&1
}

navtop_available() {
  export PATH="$HOME/.local/bin:$PATH"
  command -v navtop >/dev/null 2>&1 && return 0
  [[ -x "$NAVTOP_BIN" ]] && return 0
  pkg_present navtop navtop
}

install_aur_each() {
  local helper="$1"
  shift
  local pkg
  for pkg in "$@"; do
    if pkg_present "$pkg"; then
      printf 'Already available: %s\n' "$pkg"
      continue
    fi
    printf 'Installing AUR package with %s: %s\n' "$helper" "$pkg"
    if "$helper" -S --needed --noconfirm "$pkg"; then
      if pkg_present "$pkg"; then
        record_installed pkg "$pkg"
      fi
    else
      printf 'Optional AUR package failed (continuing): %s\n' "$pkg" >&2
    fi
  done
}

try_pacman_each() {
  local pkg
  for pkg in "$@"; do
    if pkg_present "$pkg"; then
      printf 'Already available: %s\n' "$pkg"
      continue
    fi
    printf 'Installing package: %s\n' "$pkg"
    if sudo pacman -S --needed --noconfirm "$pkg"; then
      if pkg_present "$pkg"; then
        record_installed pkg "$pkg"
      fi
    else
      printf 'Package failed (continuing): %s\n' "$pkg" >&2
    fi
  done
}

try_dnf_each() {
  local pkg
  for pkg in "$@"; do
    if pkg_present "$pkg"; then
      printf 'Already available: %s\n' "$pkg"
      continue
    fi
    printf 'Installing optional package: %s\n' "$pkg"
    if sudo dnf install -y "$pkg"; then
      if pkg_present "$pkg"; then
        record_installed pkg "$pkg"
      fi
    else
      printf 'Optional package unavailable or failed (continuing): %s\n' "$pkg" >&2
    fi
  done
}

try_zypper_each() {
  local pkg
  for pkg in "$@"; do
    if pkg_present "$pkg"; then
      printf 'Already available: %s\n' "$pkg"
      continue
    fi
    printf 'Installing optional package: %s\n' "$pkg"
    if sudo zypper install -y "$pkg"; then
      if pkg_present "$pkg"; then
        record_installed pkg "$pkg"
      fi
    else
      printf 'Optional package unavailable or failed (continuing): %s\n' "$pkg" >&2
    fi
  done
}

ensure_flathub() {
  command -v flatpak >/dev/null 2>&1 || return 1
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo >/dev/null 2>&1 || true
}

try_flatpak_app() {
  local app_id="$1"
  local label="$2"
  command -v flatpak >/dev/null 2>&1 || return 1
  if flatpak info "$app_id" >/dev/null 2>&1; then
    printf 'Already available (Flatpak): %s\n' "$label"
    return 0
  fi
  printf 'Installing optional Flatpak: %s (%s)\n' "$label" "$app_id"
  ensure_flathub
  if flatpak install -y flathub "$app_id"; then
    record_installed flatpak "$app_id"
    return 0
  fi
  printf 'Optional Flatpak failed (continuing): %s\n' "$label" >&2
  return 1
}

bootstrap_aur_pkg() {
  local name="$1"
  local url="$2"
  local tmp
  if command -v "$name" >/dev/null 2>&1; then
    printf 'Already available: %s\n' "$name"
    return 0
  fi
  printf 'Bootstrapping %s from AUR...\n' "$name"
  tmp="$(mktemp -d)"
  if ! git clone --depth 1 "$url" "$tmp/$name"; then
    printf 'Failed to clone %s\n' "$url" >&2
    rm -rf "$tmp"
    return 1
  fi
  (
    cd "$tmp/$name" || exit 1
    if [[ "${NAVURYX_ASSUME_YES:-0}" == 1 ]]; then
      makepkg -si --noconfirm --needed
    else
      makepkg -si --needed --noconfirm
    fi
  )
  local ok=$?
  rm -rf "$tmp"
  if command -v "$name" >/dev/null 2>&1; then
    printf '%s installed\n' "$name"
    return 0
  fi
  printf 'Could not bootstrap %s\n' "$name" >&2
  return "$ok"
}

bootstrap_arch_helpers() {
  printf 'Installing required Arch build tools (base-devel, git)...\n'
  sudo pacman -S --needed --noconfirm base-devel git || {
    printf 'Failed to install base-devel/git\n' >&2
    return 1
  }

  printf 'Installing required AUR helper: yay (non-optional)\n'
  if ! bootstrap_aur_pkg yay https://aur.archlinux.org/yay.git; then
    printf 'ERROR: yay is required and could not be installed.\n' >&2
    return 1
  fi
  printf 'AUR helper ready: yay\n'

  local want_paru=0 want_flatpak=0
  if [[ "${NAVURYX_ASSUME_YES:-0}" == 1 ]]; then
    [[ "${NAVURYX_INSTALL_PARU:-0}" == 1 ]] && want_paru=1
    [[ "${NAVURYX_INSTALL_FLATPAK:-0}" == 1 ]] && want_flatpak=1
    if [[ "$want_paru" != 1 ]]; then
      printf 'Non-interactive: skipping optional paru (set NAVURYX_INSTALL_PARU=1 to install).\n'
    fi
    if [[ "$want_flatpak" != 1 ]]; then
      printf 'Non-interactive: skipping optional Flatpak (set NAVURYX_INSTALL_FLATPAK=1 to install).\n'
    fi
  else
    if confirm "Also install paru (optional second AUR helper)?"; then
      want_paru=1
    fi
    if confirm "Also install Flatpak (optional app fallbacks)?"; then
      want_flatpak=1
    fi
  fi

  if [[ "$want_paru" == 1 ]]; then
    local had_paru=0
    command -v paru >/dev/null 2>&1 && had_paru=1
    bootstrap_aur_pkg paru https://aur.archlinux.org/paru.git || true
    if [[ "$had_paru" == 0 ]] && command -v paru >/dev/null 2>&1; then
      record_installed optional-bootstrap paru
      printf 'Optional AUR helper ready: paru\n'
    fi
  fi

  if [[ "$want_flatpak" == 1 ]]; then
    local had_flatpak=0
    pkg_present flatpak flatpak && had_flatpak=1
    if [[ "$had_flatpak" == 0 ]]; then
      if sudo pacman -S --needed --noconfirm flatpak && pkg_present flatpak flatpak; then
        record_installed optional-bootstrap flatpak
        printf 'Optional Flatpak installed\n'
      else
        printf 'Optional Flatpak install failed (continuing)\n' >&2
      fi
    else
      printf 'Already available: flatpak\n'
    fi
    ensure_flathub || true
  fi

  return 0
}

BROWSER_KEYS=(firefox chromium brave chrome tor librewolf zen)
BROWSER_LABELS=(
  "Firefox (recommended)"
  "Chromium"
  "Brave"
  "Google Chrome"
  "Tor Browser"
  "LibreWolf"
  "Zen Browser"
)
BROWSER_SRC=(pacman pacman aur aur pacman aur aur)
BROWSER_PKG=(firefox chromium brave-bin google-chrome torbrowser-launcher librewolf-bin zen-browser-bin)
BROWSER_ALT=("" "" "brave" "google-chrome-stable" "" "librewolf" "zen-browser")
BROWSER_BIN=(firefox chromium brave google-chrome-stable torbrowser-launcher librewolf zen-browser)
BROWSER_FLATPAK=(
  org.mozilla.firefox
  org.chromium.Chromium
  com.brave.Browser
  com.google.Chrome
  org.torproject.torbrowser-launcher
  io.gitlab.librewolf-community
  app.zen_browser.zen
)
BROWSER_DNF=(firefox chromium "" "" torbrowser-launcher "" "")
BROWSER_ZYPPER=(firefox chromium "" "" torbrowser-launcher "" "")
BROWSER_EXTRA=("" "" "" "" "" "" "")
BROWSER_POST=("" "" "" "" "" "" "")

VPN_KEYS=(proton proton-cli mullvad wireguard openvpn tailscale nm-plugins)
VPN_LABELS=(
  "ProtonVPN (GTK app)"
  "ProtonVPN (CLI)"
  "Mullvad VPN"
  "WireGuard tools"
  "OpenVPN + NetworkManager plugin"
  "Tailscale"
  "NetworkManager VPN plugins (OpenConnect / VPNC / PPTP)"
)
VPN_SRC=(pacman pacman aur pacman pacman pacman pacman)
VPN_PKG=(proton-vpn-gtk-app proton-vpn-cli mullvad-vpn-bin wireguard-tools openvpn tailscale networkmanager-openconnect)
VPN_ALT=("" "" "mullvad-vpn" "" "" "" "")
VPN_BIN=(protonvpn-app protonvpn mullvad wg openvpn tailscale nmcli)
VPN_FLATPAK=("" "" "" "" "" "" "")
VPN_DNF=("" "" "" wireguard-tools openvpn tailscale NetworkManager-openconnect)
VPN_ZYPPER=("" "" "" wireguard-tools openvpn tailscale NetworkManager-openconnect)
VPN_EXTRA=(
  "gnome-keyring libsecret libayatana-appindicator librsvg networkmanager networkmanager-openvpn network-manager-applet"
  "gnome-keyring libsecret networkmanager networkmanager-openvpn"
  ""
  "openresolv"
  "networkmanager-openvpn"
  ""
  "networkmanager-openvpn networkmanager-vpnc networkmanager-pptp"
)
VPN_POST=("" "" "mullvad-daemon" "" "" "tailscaled" "")

DISCORD_KEYS=(discord vesktop navtop legcord webcord)
DISCORD_LABELS=(
  "Discord (official)"
  "Vesktop (Vencord desktop)"
  "Navtop (Navcord desktop)"
  "Legcord (formerly ArmCord)"
  "WebCord"
)
DISCORD_SRC=(pacman aur aur aur aur)
DISCORD_PKG=(discord vesktop-bin navtop legcord-bin webcord-bin)
DISCORD_ALT=("" "vesktop" "" "legcord" "webcord")
DISCORD_BIN=(discord vesktop navtop legcord webcord)
DISCORD_FLATPAK=(com.discordapp.Discord dev.vencord.Vesktop "" "" io.github.spacingbat3.webcord)
DISCORD_DNF=(discord "" "" "" "")
DISCORD_ZYPPER=(discord "" "" "" "")
DISCORD_EXTRA=("" "" "" "" "")
DISCORD_POST=("" "" "" "" "")

SELECTED_INDEXES=()
SELECTED_BROWSERS=()
SELECTED_VPNS=()
SELECTED_DISCORD=()
ZEN_ATTEMPTED=0

catalog_index_for_key() {
  local -n _ck_keys="$1"
  local key="$2" i
  for i in "${!_ck_keys[@]}"; do
    if [[ "${_ck_keys[$i]}" == "$key" ]]; then
      printf '%s' "$i"
      return 0
    fi
  done
  return 1
}

normalize_catalog_key() {
  local token="${1,,}"
  case "$token" in
    google-chrome|google_chrome) printf 'chrome' ;;
    tor-browser|torbrowser) printf 'tor' ;;
    libre-wolf) printf 'librewolf' ;;
    zen-browser) printf 'zen' ;;
    protonvpn|proton-vpn) printf 'proton' ;;
    protonvpn-cli|proton-vpn-cli) printf 'proton-cli' ;;
    mullvad-vpn) printf 'mullvad' ;;
    wg|wireguard-tools) printf 'wireguard' ;;
    nm|nm-vpn|networkmanager) printf 'nm-plugins' ;;
    armcord) printf 'legcord' ;;
    nav-top|navcord) printf 'navtop' ;;
    web-cord) printf 'webcord' ;;
    none|skip) printf 'none' ;;
    *) printf '%s' "$token" ;;
  esac
}

parse_catalog_selection() {
  local keys_name="$1" raw="$2"
  local -n _pc_keys="$keys_name"
  local -a tokens=()
  local token key idx
  SELECTED_INDEXES=()
  IFS=', ' read -r -a tokens <<<"$raw"
  for token in "${tokens[@]}"; do
    [[ -z "$token" ]] && continue
    if [[ "$token" =~ ^[0-9]+$ ]]; then
      idx=$((token - 1))
      if ((idx >= 0 && idx < ${#_pc_keys[@]})); then
        SELECTED_INDEXES+=("$idx")
      else
        printf 'Unknown option number: %s\n' "$token" >&2
      fi
      continue
    fi
    key="$(normalize_catalog_key "$token")"
    [[ "$key" == none ]] && continue
    if idx="$(catalog_index_for_key "$keys_name" "$key")"; then
      SELECTED_INDEXES+=("$idx")
    else
      printf 'Unknown option: %s\n' "$token" >&2
    fi
  done
}

unique_selected_indexes() {
  local -A seen=()
  local idx
  local -a out=()
  for idx in "${SELECTED_INDEXES[@]}"; do
    [[ -n "${seen[$idx]:-}" ]] && continue
    seen[$idx]=1
    out+=("$idx")
  done
  SELECTED_INDEXES=()
  if ((${#out[@]} > 0)); then
    SELECTED_INDEXES=("${out[@]}")
  fi
}

apply_catalog_default() {
  local keys_name="$1" default_keys="$2"
  SELECTED_INDEXES=()
  [[ -z "$default_keys" ]] && return 0
  parse_catalog_selection "$keys_name" "$default_keys"
  unique_selected_indexes
}

select_from_catalog() {
  local prefix="$1" prompt="$2" env_value="$3" default_keys="$4"
  local keys_name="${prefix}_KEYS"
  local -n _sc_keys="${prefix}_KEYS"
  local -n _sc_labels="${prefix}_LABELS"
  local i answer=""

  SELECTED_INDEXES=()

  if [[ -n "$env_value" ]]; then
    parse_catalog_selection "$keys_name" "$env_value"
    unique_selected_indexes
    if ((${#SELECTED_INDEXES[@]} == 0)); then
      apply_catalog_default "$keys_name" "$default_keys"
    fi
    printf '%s: using selection from environment.\n' "$prompt"
    return 0
  fi

  if [[ "${NAVURYX_ASSUME_YES:-0}" == 1 ]]; then
    apply_catalog_default "$keys_name" "$default_keys"
    printf 'Non-interactive mode: %s defaults to %s.\n' "$prompt" "${default_keys:-none}"
    return 0
  fi

  printf '\n%s (multi-select supported)\n' "$prompt"
  for i in "${!_sc_keys[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "${_sc_labels[$i]}"
  done
  printf 'Enter one or more numbers separated by spaces or commas (example: 1 3).\n'
  printf 'Press Enter for the default: %s\n' "${default_keys:-none}"

  if command -v gum >/dev/null 2>&1; then
    local gum_out line
    local -a labels=()
    for i in "${!_sc_keys[@]}"; do
      labels+=("$((i + 1))) ${_sc_labels[$i]}")
    done
    if gum_out="$(gum choose --no-limit --header "$prompt (Tab/Space to multi-select, Enter to confirm)" "${labels[@]}")"; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        answer+="${line%%)*},"
      done <<<"$gum_out"
    fi
  fi

  if [[ -z "$answer" ]]; then
    read -r -p "Selection [default: ${default_keys:-none}]: " answer || true
  fi

  if [[ -z "${answer//[[:space:]]/}" ]]; then
    apply_catalog_default "$keys_name" "$default_keys"
  else
    parse_catalog_selection "$keys_name" "$answer"
    unique_selected_indexes
  fi

  if ((${#SELECTED_INDEXES[@]} == 0)); then
    printf 'Selected: none\n'
    return 0
  fi
  printf 'Selected:'
  for i in "${SELECTED_INDEXES[@]}"; do
    printf ' %s' "${_sc_labels[$i]}"
  done
  printf '\n'
}

select_browsers() {
  select_from_catalog BROWSER 'Browser selection' "${NAVURYX_BROWSERS:-}" firefox
  SELECTED_BROWSERS=()
  if ((${#SELECTED_INDEXES[@]} > 0)); then
    SELECTED_BROWSERS=("${SELECTED_INDEXES[@]}")
  fi
}

select_vpns() {
  select_from_catalog VPN 'VPN selection' "${NAVURYX_VPNS:-}" ""
  SELECTED_VPNS=()
  if ((${#SELECTED_INDEXES[@]} > 0)); then
    SELECTED_VPNS=("${SELECTED_INDEXES[@]}")
  fi
}

select_discord_clients() {
  select_from_catalog DISCORD 'Discord client selection' "${NAVURYX_DISCORD:-}" discord
  SELECTED_DISCORD=()
  if ((${#SELECTED_INDEXES[@]} > 0)); then
    SELECTED_DISCORD=("${SELECTED_INDEXES[@]}")
  fi
}

install_zen_browser() {
  ZEN_ATTEMPTED=1
  if zen_available; then
    printf 'Already available: Zen Browser\n'
    record_status Zen OK
    return 0
  fi

  if command -v yay >/dev/null 2>&1; then
    printf 'Installing Zen Browser: yay -S zen-browser-bin\n'
    if yay -S --needed --noconfirm zen-browser-bin && zen_available; then
      record_installed pkg zen-browser-bin
      record_status Zen OK
      return 0
    fi
    printf 'yay install failed or Zen binary not found after install\n' >&2
  elif helper="$(aur_helper)"; then
    install_aur_each "$helper" zen-browser-bin
    if zen_available; then
      record_status Zen OK
      return 0
    fi
  else
    printf 'Zen Browser needs yay (required): yay -S zen-browser-bin\n' >&2
  fi

  if try_flatpak_app app.zen_browser.zen "Zen Browser" && zen_available; then
    record_status Zen OK
    return 0
  fi

  printf 'FAILED: Zen Browser could not be installed. Run: yay -S zen-browser-bin\n' >&2
  record_status Zen FAILED
  return 1
}

navtop_asset_arch() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'x64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *) return 1 ;;
  esac
}

navtop_latest_release_json() {
  curl -fsSL -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$NAVTOP_REPO/releases/latest" 2>/dev/null
}

navtop_asset_url() {
  local json="$1" suffix="$2" arch="$3" urls
  urls="$(printf '%s\n' "$json" \
    | grep -o '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed 's/.*"\(https[^"]*\)"$/\1/')"
  [[ -n "$urls" ]] || return 1
  if [[ "$arch" == arm64 ]]; then
    urls="$(printf '%s\n' "$urls" | grep -Ei 'arm64|aarch64' || true)"
  else
    urls="$(printf '%s\n' "$urls" | grep -Eiv 'arm64|aarch64' || true)"
  fi
  [[ -n "$urls" ]] || return 1
  printf '%s\n' "$urls" | grep -Ei "(${suffix})\$" | head -1
}

navtop_write_desktop_entry() {
  local exec_path="$1" desktop_dir
  desktop_dir="$(dirname "$NAVTOP_DESKTOP")"
  mkdir -p "$desktop_dir"
  cat > "$NAVTOP_DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Navtop
GenericName=Internet Messenger
Comment=Navcord desktop client
Exec=$exec_path %U
Icon=navtop
Terminal=false
Categories=Network;InstantMessaging;Chat;
Keywords=discord;navcord;navtop;chat;
MimeType=x-scheme-handler/discord;
StartupWMClass=navtop
EOF
  record_installed file "$NAVTOP_DESKTOP"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
  fi
}

navtop_link_binary() {
  local exec_path="$1"
  mkdir -p "$HOME/.local/bin"
  ln -sfn "$exec_path" "$NAVTOP_BIN"
  record_installed file "$NAVTOP_BIN"
  export PATH="$HOME/.local/bin:$PATH"
}

navtop_install_local_app() {
  local exec_path="$1"
  record_installed file "$NAVTOP_HOME"
  navtop_link_binary "$exec_path"
  navtop_write_desktop_entry "$exec_path"
  navtop_available
}

navtop_install_pacman_file() {
  local file="$1" pkgname
  command -v pacman >/dev/null 2>&1 || return 1
  printf 'Installing Navtop package: %s\n' "$file"
  sudo pacman -U --needed --noconfirm "$file" || return 1
  navtop_available || return 1
  pkgname="$(pacman -Qp "$file" 2>/dev/null | awk '{print $1}' | head -1)"
  record_installed pkg "${pkgname:-navtop}"
}

navtop_install_appimage() {
  local url="$1" target="$NAVTOP_HOME/Navtop.AppImage"
  mkdir -p "$NAVTOP_HOME"
  printf 'Downloading Navtop AppImage: %s\n' "$url"
  if ! curl --fail --location --progress-bar --output "$target" "$url"; then
    rm -f "$target"
    return 1
  fi
  chmod +x "$target"
  navtop_install_local_app "$target"
}

navtop_install_tarball() {
  local url="$1" archive exec_path
  command -v tar >/dev/null 2>&1 || return 1
  mkdir -p "$NAVTOP_HOME"
  archive="$NAVTOP_HOME/navtop.tar.gz"
  printf 'Downloading Navtop archive: %s\n' "$url"
  if ! curl --fail --location --progress-bar --output "$archive" "$url"; then
    rm -f "$archive"
    return 1
  fi
  if ! tar xzf "$archive" -C "$NAVTOP_HOME"; then
    rm -f "$archive"
    return 1
  fi
  rm -f "$archive"
  exec_path="$(find "$NAVTOP_HOME" -type f -name navtop 2>/dev/null | head -1 || true)"
  [[ -n "$exec_path" ]] || return 1
  chmod +x "$exec_path" 2>/dev/null || true
  navtop_install_local_app "$exec_path"
}

install_navtop_from_release() {
  command -v curl >/dev/null 2>&1 || return 1
  local arch json url pkg_file
  arch="$(navtop_asset_arch)" || return 1
  json="$(navtop_latest_release_json)" || return 1
  [[ -n "$json" ]] || return 1

  if command -v pacman >/dev/null 2>&1; then
    url="$(navtop_asset_url "$json" '\.pacman|\.pkg\.tar\.(zst|xz)' "$arch" || true)"
    if [[ -n "$url" ]]; then
      mkdir -p "$NAVTOP_HOME"
      pkg_file="$NAVTOP_HOME/${url##*/}"
      printf 'Downloading Navtop package: %s\n' "$url"
      if curl --fail --location --progress-bar --output "$pkg_file" "$url" \
        && navtop_install_pacman_file "$pkg_file"; then
        rm -f "$pkg_file"
        return 0
      fi
      rm -f "$pkg_file"
    fi
  fi

  url="$(navtop_asset_url "$json" '\.appimage' "$arch" || true)"
  if [[ -n "$url" ]] && navtop_install_appimage "$url"; then
    return 0
  fi

  url="$(navtop_asset_url "$json" '\.tar\.gz' "$arch" || true)"
  if [[ -n "$url" ]] && navtop_install_tarball "$url"; then
    return 0
  fi

  return 1
}

navtop_ensure_bun() {
  command -v bun >/dev/null 2>&1 && return 0
  local helper
  if command -v pacman >/dev/null 2>&1 && helper="$(aur_helper)"; then
    install_aur_each "$helper" bun-bin
  fi
  command -v bun >/dev/null 2>&1
}

install_navtop_from_source() {
  if ! command -v git >/dev/null 2>&1; then
    printf 'Navtop needs git to build from source\n' >&2
    return 1
  fi
  if ! navtop_ensure_bun; then
    printf 'Navtop needs bun >= 1.3.0 to build from source: yay -S bun-bin\n' >&2
    return 1
  fi

  local work src target built status=1
  work="$(mktemp -d)" || return 1
  src="$work/Navtop"

  printf 'Building Navtop from source; this downloads Electron and can take several minutes.\n'
  if ! git clone --depth 1 "$NAVTOP_URL.git" "$src"; then
    rm -rf "$work"
    return 1
  fi

  if command -v pacman >/dev/null 2>&1; then
    target=pacman
  else
    target=AppImage
  fi

  if (cd "$src" && bun install && bun package --linux "$target"); then
    if [[ "$target" == pacman ]]; then
      built="$(find "$src/dist" -maxdepth 1 -type f -name '*.pacman' 2>/dev/null | head -1 || true)"
      if [[ -n "$built" ]] && navtop_install_pacman_file "$built"; then
        status=0
      fi
    else
      built="$(find "$src/dist" -maxdepth 1 -type f -iname '*.AppImage' 2>/dev/null | head -1 || true)"
      if [[ -n "$built" ]]; then
        mkdir -p "$NAVTOP_HOME"
        if cp -f "$built" "$NAVTOP_HOME/Navtop.AppImage"; then
          chmod +x "$NAVTOP_HOME/Navtop.AppImage"
          if navtop_install_local_app "$NAVTOP_HOME/Navtop.AppImage"; then
            status=0
          fi
        fi
      fi
    fi
  fi

  rm -rf "$work"
  return "$status"
}

install_navtop() {
  export PATH="$HOME/.local/bin:$PATH"

  if navtop_available; then
    printf 'Already available: Navtop (%s)\n' "$(command -v navtop || printf '%s' "$NAVTOP_BIN")"
    record_status Navtop OK
    return 0
  fi

  printf 'Installing Navtop from %s ...\n' "$NAVTOP_URL"

  local helper aur_pkg
  if command -v pacman >/dev/null 2>&1 && helper="$(aur_helper)"; then
    for aur_pkg in navtop-bin navtop; do
      if "$helper" -Si "$aur_pkg" >/dev/null 2>&1; then
        install_aur_each "$helper" "$aur_pkg"
        if navtop_available; then
          record_status Navtop OK
          return 0
        fi
      fi
    done
  fi

  if install_navtop_from_release; then
    printf 'Navtop installed from a published release (%s)\n' "$(command -v navtop || printf '%s' "$NAVTOP_BIN")"
    record_status Navtop OK
    return 0
  fi

  printf 'No matching Navtop release build for this system; falling back to a source build.\n'
  if install_navtop_from_source; then
    printf 'Navtop built and installed (%s)\n' "$(command -v navtop || printf '%s' "$NAVTOP_BIN")"
    record_status Navtop OK
    return 0
  fi

  printf 'FAILED: Navtop could not be installed. Build it manually: git clone %s.git && cd Navtop && bun install && bun package --linux\n' "$NAVTOP_URL" >&2
  record_status Navtop FAILED
  return 1
}

catalog_entry_available() {
  local prefix="$1" idx="$2"
  local -n _av_keys="${prefix}_KEYS"
  local -n _av_pkg="${prefix}_PKG"
  local -n _av_alt="${prefix}_ALT"
  local -n _av_bin="${prefix}_BIN"
  local -n _av_flatpak="${prefix}_FLATPAK"
  local key="${_av_keys[$idx]}"
  local pkg="${_av_pkg[$idx]}"
  local bin="${_av_bin[$idx]}"
  local flatpak_id="${_av_flatpak[$idx]}"
  local alt

  if [[ "$key" == zen ]]; then
    zen_available
    return $?
  fi
  if [[ "$key" == navtop ]]; then
    navtop_available
    return $?
  fi
  if [[ -n "$bin" ]] && command -v "$bin" >/dev/null 2>&1; then
    return 0
  fi
  if [[ -n "$pkg" ]] && pkg_present "$pkg" "${bin:-$pkg}"; then
    return 0
  fi
  for alt in ${_av_alt[$idx]}; do
    if pkg_present "$alt" "${bin:-$alt}"; then
      return 0
    fi
  done
  if [[ -n "$flatpak_id" ]] && command -v flatpak >/dev/null 2>&1 && flatpak info "$flatpak_id" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

enable_catalog_service() {
  local service="$1"
  [[ -z "$service" ]] && return 0
  command -v systemctl >/dev/null 2>&1 || return 0
  printf 'Enabling service: %s\n' "$service"
  if ! sudo systemctl enable --now "$service" >/dev/null 2>&1; then
    printf 'Could not enable %s automatically; start it manually when needed.\n' "$service" >&2
  fi
  return 0
}

install_catalog_extras() {
  local prefix="$1" idx="$2"
  local -n _ix_extra="${prefix}_EXTRA"
  local extras="${_ix_extra[$idx]}"
  if [[ -n "$extras" ]] && command -v pacman >/dev/null 2>&1; then
    try_pacman_each $extras
  fi
  return 0
}

install_catalog_entry() {
  local prefix="$1" idx="$2"
  local -n _ie_keys="${prefix}_KEYS"
  local -n _ie_labels="${prefix}_LABELS"
  local -n _ie_src="${prefix}_SRC"
  local -n _ie_pkg="${prefix}_PKG"
  local -n _ie_alt="${prefix}_ALT"
  local -n _ie_flatpak="${prefix}_FLATPAK"
  local -n _ie_dnf="${prefix}_DNF"
  local -n _ie_zypper="${prefix}_ZYPPER"
  local -n _ie_post="${prefix}_POST"
  local key="${_ie_keys[$idx]}"
  local label="${_ie_labels[$idx]}"
  local helper="" alt

  if [[ "$key" == zen ]]; then
    install_zen_browser || true
    return 0
  fi
  if [[ "$key" == navtop ]]; then
    install_navtop || true
    return 0
  fi

  if catalog_entry_available "$prefix" "$idx"; then
    printf 'Already available: %s\n' "$label"
    install_catalog_extras "$prefix" "$idx"
    record_status "$label" OK
    enable_catalog_service "${_ie_post[$idx]}"
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    if [[ "${_ie_src[$idx]}" == pacman ]]; then
      try_pacman_each "${_ie_pkg[$idx]}"
    elif helper="$(aur_helper)"; then
      install_aur_each "$helper" "${_ie_pkg[$idx]}"
      if ! catalog_entry_available "$prefix" "$idx"; then
        for alt in ${_ie_alt[$idx]}; do
          install_aur_each "$helper" "$alt"
          if catalog_entry_available "$prefix" "$idx"; then
            break
          fi
        done
      fi
    else
      printf 'Needs the yay AUR helper: %s (%s)\n' "$label" "${_ie_pkg[$idx]}" >&2
    fi
    install_catalog_extras "$prefix" "$idx"
  elif command -v dnf >/dev/null 2>&1; then
    if [[ -n "${_ie_dnf[$idx]}" ]]; then
      try_dnf_each ${_ie_dnf[$idx]}
    fi
  elif command -v zypper >/dev/null 2>&1; then
    if [[ -n "${_ie_zypper[$idx]}" ]]; then
      try_zypper_each ${_ie_zypper[$idx]}
    fi
  fi

  if catalog_entry_available "$prefix" "$idx"; then
    record_status "$label" OK
    enable_catalog_service "${_ie_post[$idx]}"
    return 0
  fi

  if [[ -n "${_ie_flatpak[$idx]}" ]] && try_flatpak_app "${_ie_flatpak[$idx]}" "$label" && catalog_entry_available "$prefix" "$idx"; then
    record_status "$label" OK
    return 0
  fi

  printf 'Could not install: %s\n' "$label" >&2
  record_status "$label" FAILED
  return 0
}

install_catalog_selection() {
  local prefix="$1" title="$2"
  shift 2
  local idx
  if (($# == 0)); then
    printf 'Skipping %s (nothing selected).\n' "$title"
    return 0
  fi
  printf 'Installing %s...\n' "$title"
  for idx in "$@"; do
    install_catalog_entry "$prefix" "$idx"
  done
}

install_selected_browsers() {
  install_catalog_selection BROWSER 'selected browsers' "${SELECTED_BROWSERS[@]}"
}

protonvpn_desktop_entry_present() {
  local dir
  for dir in /usr/share/applications /usr/local/share/applications "$HOME/.local/share/applications"; do
    if [[ -f "$dir/proton.vpn.app.gtk.desktop" || -f "$dir/protonvpn-app.desktop" ]]; then
      return 0
    fi
  done
  return 1
}

report_missing_packages() {
  local label="$1"
  shift
  local pkg missing=()
  for pkg in "$@"; do
    pkg_present "$pkg" || missing+=("$pkg")
  done
  if ((${#missing[@]} > 0)); then
    printf '%s is missing optional packages: %s\n' "$label" "${missing[*]}" >&2
  fi
  return 0
}

verify_protonvpn_entries() {
  local idx key label bin
  ((${#SELECTED_VPNS[@]} == 0)) && return 0
  for idx in "${SELECTED_VPNS[@]}"; do
    key="${VPN_KEYS[$idx]}"
    [[ "$key" == proton || "$key" == proton-cli ]] || continue
    label="${VPN_LABELS[$idx]}"
    bin="${VPN_BIN[$idx]}"
    report_missing_packages "$label" ${VPN_EXTRA[$idx]}
    if command -v "$bin" >/dev/null 2>&1; then
      if [[ "$key" == proton ]] && ! protonvpn_desktop_entry_present; then
        printf 'ProtonVPN desktop entry not found; launch it with %s\n' "$bin" >&2
      fi
      record_status "$label check" OK
      continue
    fi
    if [[ "$key" == proton ]] && protonvpn_desktop_entry_present; then
      record_status "$label check" OK
      continue
    fi
    printf 'Could not verify %s (%s not found)\n' "$label" "$bin" >&2
    record_status "$label check" FAILED
  done
  return 0
}

install_selected_vpns() {
  install_catalog_selection VPN 'selected VPN clients' "${SELECTED_VPNS[@]}"
  verify_protonvpn_entries || true
}

install_selected_discord_clients() {
  install_catalog_selection DISCORD 'selected Discord clients' "${SELECTED_DISCORD[@]}"
}

ensure_navify_path() {
  local navify_install="$HOME/.navify"
  local local_bin="$HOME/.local/bin"
  mkdir -p "$local_bin" "$navify_install"
  export PATH="$navify_install:$local_bin:$PATH"

  if [[ -x "$navify_install/navify" && ! -e "$local_bin/navify" ]]; then
    ln -sfn "$navify_install/navify" "$local_bin/navify"
  fi

  local rc
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    if [[ -f "$rc" ]] && ! grep -qF '$HOME/.navify' "$rc" 2>/dev/null; then
      printf '\nexport PATH="$HOME/.navify:$HOME/.local/bin:$PATH"\n' >> "$rc"
    fi
  done
  if [[ ! -f "$HOME/.bashrc" ]]; then
    printf 'export PATH="$HOME/.navify:$HOME/.local/bin:$PATH"\n' > "$HOME/.bashrc"
  fi
}

install_navify() {
  export PATH="$HOME/.navify:$HOME/.local/bin:$PATH"

  if navify_available; then
    printf 'Already available: navify (%s)\n' "$(command -v navify)"
    ensure_navify_path
    record_status Navify OK
    return 0
  fi

  printf 'Installing Navify CLI from https://github.com/navify/navify-cli ...\n'

  if ! command -v curl >/dev/null 2>&1; then
    printf 'curl is required to install Navify\n' >&2
    record_status Navify FAILED
    return 1
  fi
  if ! command -v tar >/dev/null 2>&1; then
    printf 'tar is required to install Navify\n' >&2
    record_status Navify FAILED
    return 1
  fi

  local target tag download_uri navify_install tar_path exe found
  case "$(uname -sm)" in
    "Linux x86_64") target="linux-amd64" ;;
    "Linux aarch64") target="linux-arm64" ;;
    *)
      printf 'Navify has no prebuilt binary for %s\n' "$(uname -sm)" >&2
      record_status Navify FAILED
      return 1
      ;;
  esac

  tag="$(curl -fsSL -H 'Accept: application/json' https://github.com/Navify/navify-cli/releases/latest | sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p' | head -1 || true)"
  tag="${tag#v}"
  if [[ -z "$tag" ]]; then
    printf 'Could not resolve latest Navify release tag\n' >&2
    record_status Navify FAILED
    return 1
  fi

  download_uri="https://github.com/Navify/navify-cli/releases/download/v${tag}/navify-${tag}-${target}.tar.gz"
  navify_install="$HOME/.navify"
  tar_path="$navify_install/navify.tar.gz"

  mkdir -p "$navify_install"
  printf 'Downloading %s\n' "$download_uri"
  if ! curl --fail --location --progress-bar --output "$tar_path" "$download_uri"; then
    printf 'Navify download failed. Retry: curl -fsSL https://raw.githubusercontent.com/Navify/navify-cli/main/install.sh | sh\n' >&2
    rm -f "$tar_path"
    record_status Navify FAILED
    return 1
  fi

  if ! tar xzf "$tar_path" -C "$navify_install"; then
    printf 'Navify extract failed\n' >&2
    rm -f "$tar_path"
    record_status Navify FAILED
    return 1
  fi
  rm -f "$tar_path"

  found="$(find "$navify_install" -type f -name navify 2>/dev/null | head -1 || true)"
  if [[ -z "$found" ]]; then
    found="$(find "$navify_install" -type f -executable 2>/dev/null | head -1 || true)"
  fi
  if [[ -n "$found" && "$found" != "$navify_install/navify" ]]; then
    cp -f "$found" "$navify_install/navify"
  fi
  chmod +x "$navify_install/navify" 2>/dev/null || true
  ensure_navify_path

  if navify_available; then
    if navify --version >/dev/null 2>&1 || navify -h >/dev/null 2>&1 || navify help >/dev/null 2>&1; then
      printf 'Navify CLI v%s installed (%s)\n' "$tag" "$(command -v navify)"
    else
      printf 'Navify CLI v%s installed at %s\n' "$tag" "$(command -v navify)"
    fi
    record_installed asset navify
    record_status Navify OK
    return 0
  fi

  printf 'Navify binary missing after extract. Retry: curl -fsSL https://raw.githubusercontent.com/Navify/navify-cli/main/install.sh | sh\n' >&2
  record_status Navify FAILED
  return 1
}

install_spotify() {
  printf 'Installing Spotify...\n'
  if spotify_available; then
    printf 'Already available: Spotify\n'
    record_status Spotify OK
    return 0
  fi

  if command -v pacman >/dev/null 2>&1; then
    try_pacman_each spotify-launcher
    if spotify_available; then
      record_status Spotify OK
      return 0
    fi
    if helper="$(aur_helper)"; then
      install_aur_each "$helper" spotify-launcher
      if spotify_available; then
        record_status Spotify OK
        return 0
      fi
      install_aur_each "$helper" spotify
      if spotify_available; then
        record_status Spotify OK
        return 0
      fi
    fi
  elif command -v dnf >/dev/null 2>&1; then
    try_dnf_each spotify
  elif command -v zypper >/dev/null 2>&1; then
    try_zypper_each spotify
  fi

  if try_flatpak_app com.spotify.Client Spotify && spotify_available; then
    record_status Spotify OK
    return 0
  fi

  printf 'FAILED: Spotify could not be installed\n' >&2
  record_status Spotify FAILED
  return 1
}

install_optional_apps() {
  printf 'Installing optional desktop apps...\n'
  install_selected_discord_clients || true
  install_selected_vpns || true
  install_spotify || true
  install_navify || true
}

install_quickshell_optional() {
  if command -v pacman >/dev/null 2>&1; then
    try_pacman_each quickshell matugen swww tesseract satty imagemagick || true
    if ! pkg_present quickshell quickshell && helper="$(aur_helper)"; then
      install_aur_each "$helper" quickshell-git || install_aur_each "$helper" quickshell || true
    fi
    if ! pkg_present matugen matugen && helper="$(aur_helper)"; then
      install_aur_each "$helper" matugen-bin || install_aur_each "$helper" matugen || true
    fi
  fi
}

if command -v pacman >/dev/null 2>&1; then
  packages=(
    hyprland hyprpaper hyprlock hypridle waybar rofi-wayland kitty dolphin mako
    network-manager-applet pipewire wireplumber brightnessctl playerctl grim slurp
    wl-clipboard cliphist pavucontrol jq curl libnotify polkit-gnome
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk noto-fonts noto-fonts-emoji
    ttf-jetbrains-mono-nerd fastfetch btop wf-recorder qalculate-gtk
  )
  aur_packages=(wlogout)

  printf 'Installing official Arch repository packages...\n'
  if ! sudo pacman -S --needed --noconfirm "${packages[@]}"; then
    printf 'Bulk package install failed; retrying one package at a time.\n' >&2
    try_pacman_each "${packages[@]}"
  fi

  bootstrap_arch_helpers || {
    printf 'ERROR: required yay bootstrap failed; AUR packages will be skipped.\n' >&2
  }
  install_quickshell_optional || true

  missing_aur=()
  for pkg in "${aur_packages[@]}"; do
    if pkg_present "$pkg"; then
      printf 'Already available: %s\n' "$pkg"
    else
      missing_aur+=("$pkg")
    fi
  done

  if ((${#missing_aur[@]})); then
    if helper="$(aur_helper)"; then
      install_aur_each "$helper" "${missing_aur[@]}"
      if pkg_present wlogout wlogout; then
        record_status wlogout OK
      else
        record_status wlogout FAILED
      fi
    else
      cat <<EOF
Note: these packages need yay (required bootstrap failed):
  ${missing_aur[*]}
Navuryx power menu falls back to Rofi without wlogout.
EOF
      record_status wlogout SKIPPED
    fi
  else
    record_status wlogout OK
  fi

  select_browsers
  select_discord_clients
  select_vpns
  install_selected_browsers
  install_optional_apps
  print_status_summary
elif command -v dnf >/dev/null 2>&1; then
  packages=(
    hyprland hyprpaper hyprlock hypridle waybar rofi-wayland kitty dolphin mako wlogout
    NetworkManager-applet pipewire wireplumber brightnessctl playerctl grim slurp
    wl-clipboard cliphist pavucontrol jq curl libnotify polkit-gnome
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk fastfetch btop wf-recorder qalculate-gtk
  )
  sudo dnf install -y "${packages[@]}" || {
    printf 'Some Fedora packages were unavailable. Install equivalents manually if needed.\n' >&2
  }
  if [[ "${NAVURYX_ASSUME_YES:-0}" == 1 ]]; then
    if [[ "${NAVURYX_INSTALL_FLATPAK:-0}" == 1 ]]; then
      had_flatpak=0
      pkg_present flatpak flatpak && had_flatpak=1
      sudo dnf install -y flatpak || true
      if [[ "$had_flatpak" == 0 ]] && pkg_present flatpak flatpak; then
        record_installed optional-bootstrap flatpak
      fi
      ensure_flathub || true
    fi
  else
    if confirm "Also install Flatpak (optional app fallbacks)?"; then
      had_flatpak=0
      pkg_present flatpak flatpak && had_flatpak=1
      if sudo dnf install -y flatpak; then
        if [[ "$had_flatpak" == 0 ]] && pkg_present flatpak flatpak; then
          record_installed optional-bootstrap flatpak
        fi
      fi
      ensure_flathub || true
    fi
  fi
  select_browsers
  select_discord_clients
  select_vpns
  install_selected_browsers
  install_optional_apps
  print_status_summary
elif command -v zypper >/dev/null 2>&1; then
  packages=(
    hyprland hyprpaper hyprlock hypridle waybar rofi kitty dolphin mako wlogout
    NetworkManager-applet pipewire wireplumber brightnessctl playerctl grim slurp
    wl-clipboard cliphist pavucontrol jq curl libnotify-tools polkit-gnome
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk fastfetch btop wf-recorder qalculate
  )
  sudo zypper install -y "${packages[@]}" || {
    printf 'Some openSUSE packages were unavailable. Install equivalents manually if needed.\n' >&2
  }
  if [[ "${NAVURYX_ASSUME_YES:-0}" == 1 ]]; then
    if [[ "${NAVURYX_INSTALL_FLATPAK:-0}" == 1 ]]; then
      had_flatpak=0
      pkg_present flatpak flatpak && had_flatpak=1
      sudo zypper install -y flatpak || true
      if [[ "$had_flatpak" == 0 ]] && pkg_present flatpak flatpak; then
        record_installed optional-bootstrap flatpak
      fi
      ensure_flathub || true
    fi
  else
    if confirm "Also install Flatpak (optional app fallbacks)?"; then
      had_flatpak=0
      pkg_present flatpak flatpak && had_flatpak=1
      if sudo zypper install -y flatpak; then
        if [[ "$had_flatpak" == 0 ]] && pkg_present flatpak flatpak; then
          record_installed optional-bootstrap flatpak
        fi
      fi
      ensure_flathub || true
    fi
  fi
  select_browsers
  select_discord_clients
  select_vpns
  install_selected_browsers
  install_optional_apps
  print_status_summary
else
  cat <<'EOF'
Navuryx targets Arch Linux (pacman). Automatic dependency installation supports pacman first.
Install the commands reported by scripts/preflight.sh, then run install.sh again.

On Arch the installer:
  - Always installs base-devel, git, and yay (required AUR helper)
  - Optionally prompts for paru and Flatpak (skipped with --yes unless
    NAVURYX_INSTALL_PARU=1 / NAVURYX_INSTALL_FLATPAK=1)
  - Installs core desktop packages via pacman
  - Installs AUR apps via yay: wlogout, browsers, matugen, etc.
  - Zen Browser: yay -S zen-browser-bin
  - Spotify with Flatpak fallback when Flatpak was installed
  - Navify CLI from https://github.com/navify/navify-cli releases
  - Navtop from https://github.com/Navcord/Navtop (release build, or a source build with bun)
  - Records theme packages in ~/.local/share/navuryx/installed-packages

Interactive multi-select prompts run unless --yes is used:
  browsers        default Firefox      NAVURYX_BROWSERS=firefox,chromium,brave,zen
  Discord clients default Discord      NAVURYX_DISCORD=discord,vesktop,navtop,legcord,webcord
  VPN clients     default none         NAVURYX_VPNS=proton,mullvad,wireguard,openvpn,tailscale
EOF
fi

printf '\nDependency step finished.\n'
printf 'Any failures listed above are optional and do not block the Navuryx configuration install.\n'
exit 0
