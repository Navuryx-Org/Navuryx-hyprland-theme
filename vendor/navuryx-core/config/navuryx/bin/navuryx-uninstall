#!/usr/bin/env bash
set -Eeuo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
NAV_STATE="$DATA_HOME/navuryx"
PKG_MANIFEST="$NAV_STATE/installed-packages"
MODE=""
BACKUP=""
ASSUME_YES=0
PURGE_STATE=0
REMOVE_PACKAGES=""
PURGE_BOOTSTRAP=0

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh --restore|--remove-only [options]
       ~/.config/navuryx/bin/navuryx-uninstall --restore|--remove-only [options]

  --restore            Remove Navuryx and restore the pre-install snapshot
                       (or stock Hyprland defaults when no prior config existed)
  --remove-only        Remove Navuryx-managed folders without restoring old ones
  --backup PATH        Restore a particular Navuryx backup
  --purge-state        Also remove ~/.local/share/navuryx and ~/.local/state/navuryx
                       (keeps the uninstall snapshot written by this run)
  --remove-packages    Remove packages recorded in
                       ~/.local/share/navuryx/installed-packages
  --keep-packages      Leave system packages installed
  --purge-bootstrap    Also remove optional paru/Flatpak if Navuryx installed them
                       (never removes yay)
  --yes, -y            Do not ask for confirmation (also removes recorded theme
                       packages unless --keep-packages; skips optional paru/Flatpak
                       unless --purge-bootstrap)
EOF
}

while (($#)); do
  case "$1" in
    --restore) MODE=restore ;;
    --remove-only) MODE=remove ;;
    --backup) shift; BACKUP="${1:-}" ;;
    --purge-state) PURGE_STATE=1 ;;
    --remove-packages) REMOVE_PACKAGES=1 ;;
    --keep-packages) REMOVE_PACKAGES=0 ;;
    --purge-bootstrap) PURGE_BOOTSTRAP=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
  shift
done

[[ -n "$MODE" ]] || { usage; exit 2; }

if [[ "$MODE" == restore && -z "$BACKUP" ]]; then
  [[ -f "$NAV_STATE/last-backup" ]] || { printf 'No recorded Navuryx backup was found.\n' >&2; exit 1; }
  BACKUP="$(cat "$NAV_STATE/last-backup")"
fi
if [[ "$MODE" == restore ]]; then
  [[ -f "$BACKUP/manifest" ]] || { printf 'Invalid backup: %s\n' "$BACKUP" >&2; exit 1; }
  mapfile -t items < <(cut -d'|' -f1 "$BACKUP/manifest")
else
  if [[ -f "$NAV_STATE/installed-items" ]]; then
    mapfile -t items < "$NAV_STATE/installed-items"
  else
    items=(hypr waybar rofi kitty mako wlogout navuryx fastfetch gtk-3.0 gtk-4.0 quickshell)
  fi
fi

declare -A seen_items=()
unique_items=()
for item in "${items[@]}"; do
  [[ -z "$item" ]] && continue
  [[ -n "${seen_items[$item]:-}" ]] && continue
  seen_items[$item]=1
  unique_items+=("$item")
done
items=("${unique_items[@]}")

for extra in gtk-3.0 gtk-4.0 quickshell; do
  if [[ -e "$XDG_CONFIG_HOME/$extra" || -L "$XDG_CONFIG_HOME/$extra" ]]; then
    if [[ -z "${seen_items[$extra]:-}" ]]; then
      items+=("$extra")
      seen_items[$extra]=1
    fi
  fi
done

snapshot="$NAV_STATE/uninstall-snapshots/$(date +%Y%m%d-%H%M%S)"
printf 'Current Navuryx folders will first be copied to:\n  %s\n' "$snapshot"
[[ "$MODE" == restore ]] && printf 'Then the previous snapshot will be restored from:\n  %s\n' "$BACKUP"
[[ "$MODE" == restore ]] && printf 'Folders that did not exist before Navuryx will use stock Hyprland defaults where needed.\n'
printf 'Navify CLI (~/.navify) and related PATH entries will be removed.\n'
if [[ -f "$PKG_MANIFEST" ]]; then
  printf 'Package manifest found:\n  %s\n' "$PKG_MANIFEST"
fi

if [[ "$ASSUME_YES" != 1 ]]; then
  read -r -p 'Continue? [y/N] ' answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 0
fi

mkdir -p "$snapshot/config"
for item in "${items[@]}"; do
  target="$XDG_CONFIG_HOME/$item"
  if [[ -e "$target" || -L "$target" ]]; then
    cp -a "$target" "$snapshot/config/$item"
  fi
  rm -rf "$target"
done

install_stock_hyprland() {
  local dest="$XDG_CONFIG_HOME/hypr"
  mkdir -p "$dest"
  local src=""
  for candidate in \
    /usr/share/hyprland/hyprland.conf \
    /usr/share/hypr/hyprland.conf \
    /usr/share/hyprland/examples/hyprland.conf \
    /etc/hypr/hyprland.conf
  do
    if [[ -f "$candidate" ]]; then
      src="$candidate"
      break
    fi
  done
  if [[ -n "$src" ]]; then
    cp -a "$src" "$dest/hyprland.conf"
    printf 'Installed stock Hyprland config from %s\n' "$src"
  else
    cat > "$dest/hyprland.conf" <<'EOF'
monitor=,preferred,auto,auto

exec-once = waybar
exec-once = mako

general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 8
    blur {
        enabled = true
        size = 3
        passes = 1
    }
}

animations {
    enabled = true
}

dwindle {
    preserve_split = true
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
}

$input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = false
    }
}

bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, dolphin
bind = SUPER, V, togglefloating,
bind = SUPER, SPACE, exec, rofi -show drun
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,
bind = SUPER, left, movefocus, l
bind = SUPER, right, movefocus, r
bind = SUPER, up, movefocus, u
bind = SUPER, down, movefocus, d
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER, 6, workspace, 6
bind = SUPER, 7, workspace, 7
bind = SUPER, 8, workspace, 8
bind = SUPER, 9, workspace, 9
bind = SUPER, 0, workspace, 10
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER SHIFT, 6, movetoworkspace, 6
bind = SUPER SHIFT, 7, movetoworkspace, 7
bind = SUPER SHIFT, 8, movetoworkspace, 8
bind = SUPER SHIFT, 9, movetoworkspace, 9
bind = SUPER SHIFT, 0, movetoworkspace, 10
bind = SUPER, mouse_down, workspace, e+1
bind = SUPER, mouse_up, workspace, e-1
bindm = SUPER, mouse:272, movewindow
bindm = SUPER, mouse:273, resizewindow
EOF
    printf 'Installed minimal stock Hyprland config (no packaged example found).\n'
  fi
}

restored_hypr=0
if [[ "$MODE" == restore ]]; then
  while IFS='|' read -r item existed; do
    [[ -z "$item" ]] && continue
    if [[ "$existed" == 1 && -e "$BACKUP/config/$item" ]]; then
      cp -a "$BACKUP/config/$item" "$XDG_CONFIG_HOME/$item"
      [[ "$item" == hypr ]] && restored_hypr=1
    fi
  done < "$BACKUP/manifest"

  if [[ "$restored_hypr" != 1 ]]; then
    install_stock_hyprland
  fi
fi

pkill -x waybar >/dev/null 2>&1 || true
pkill -x mako >/dev/null 2>&1 || true
pkill -x hyprpaper >/dev/null 2>&1 || true
pkill -x swww-daemon >/dev/null 2>&1 || true
pkill -x quickshell >/dev/null 2>&1 || true
pkill -f 'navuryx-' >/dev/null 2>&1 || true

rm -f "$XDG_CONFIG_HOME/navuryx/current-wallpaper" 2>/dev/null || true
rm -rf "$STATE_HOME/navuryx" 2>/dev/null || true

remove_navify() {
  printf 'Removing Navify CLI...\n'
  rm -rf "$HOME/.navify"
  rm -f "$HOME/.local/bin/navify"
  local rc
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.bash_profile"; do
    [[ -f "$rc" ]] || continue
    if grep -qF '$HOME/.navify' "$rc" 2>/dev/null; then
      local tmp
      tmp="$(mktemp)"
      grep -vF '$HOME/.navify' "$rc" > "$tmp" || true
      mv "$tmp" "$rc"
    fi
  done
}

remove_navify

remove_navtop_local_install() {
  local navtop_home="$DATA_HOME/navtop"
  local navtop_bin="$HOME/.local/bin/navtop"
  local navtop_desktop="$DATA_HOME/applications/navtop.desktop"
  if [[ ! -e "$navtop_home" && ! -e "$navtop_bin" && ! -L "$navtop_bin" && ! -e "$navtop_desktop" ]]; then
    return 0
  fi
  printf 'Removing Navtop files installed from a release build...\n'
  rm -rf "$navtop_home"
  rm -f "$navtop_bin" "$navtop_desktop"
}

remove_recorded_files() {
  local path
  for path in "$@"; do
    [[ -z "$path" ]] && continue
    case "$path" in
      "$HOME"/*) ;;
      *)
        printf 'Skipping recorded path outside the home directory: %s\n' "$path"
        continue
        ;;
    esac
    [[ -e "$path" || -L "$path" ]] || continue
    printf 'Removing recorded file: %s\n' "$path"
    rm -rf "$path"
  done
}

rm -rf /tmp/yay-* /tmp/paru-* 2>/dev/null || true

decide_remove_packages() {
  if [[ -n "$REMOVE_PACKAGES" ]]; then
    return 0
  fi
  if [[ "$ASSUME_YES" == 1 ]]; then
    REMOVE_PACKAGES=1
    return 0
  fi
  if [[ ! -f "$PKG_MANIFEST" ]]; then
    REMOVE_PACKAGES=0
    return 0
  fi
  read -r -p 'Also remove packages Navuryx recorded during install-deps? [y/N] ' answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    REMOVE_PACKAGES=1
  else
    REMOVE_PACKAGES=0
  fi
}

remove_recorded_packages() {
  [[ -f "$PKG_MANIFEST" ]] || {
    printf 'No package manifest found; skipping package removal.\n'
    return 0
  }

  local pkgs=() flatpaks=() bootstraps=() files=()
  local kind name
  while IFS='|' read -r kind name; do
    [[ -z "$kind" || -z "$name" ]] && continue
    case "$kind" in
      pkg) pkgs+=("$name") ;;
      flatpak) flatpaks+=("$name") ;;
      optional-bootstrap) bootstraps+=("$name") ;;
      file) files+=("$name") ;;
      asset) ;;
      *) ;;
    esac
  done < "$PKG_MANIFEST"

  declare -A seen_pkg=()
  local unique_pkgs=() p
  if ((${#pkgs[@]} > 0)); then
    for p in "${pkgs[@]}"; do
      [[ -z "$p" ]] && continue
      [[ "$p" == yay ]] && continue
      [[ -n "${seen_pkg[$p]:-}" ]] && continue
      seen_pkg[$p]=1
      unique_pkgs+=("$p")
    done
  fi
  pkgs=()
  if ((${#unique_pkgs[@]} > 0)); then
    pkgs=("${unique_pkgs[@]}")
  fi

  if ((${#pkgs[@]})); then
    printf 'Removing recorded packages:\n'
    printf '  %s\n' "${pkgs[@]}"
    if command -v yay >/dev/null 2>&1; then
      yay -Rns --noconfirm "${pkgs[@]}" 2>/dev/null || true
    elif command -v paru >/dev/null 2>&1; then
      paru -Rns --noconfirm "${pkgs[@]}" 2>/dev/null || true
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -Rns --noconfirm "${pkgs[@]}" 2>/dev/null || true
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf remove -y "${pkgs[@]}" 2>/dev/null || true
    elif command -v zypper >/dev/null 2>&1; then
      sudo zypper remove -y "${pkgs[@]}" 2>/dev/null || true
    fi
  fi

  if ((${#flatpaks[@]})) && command -v flatpak >/dev/null 2>&1; then
    local app
    for app in "${flatpaks[@]}"; do
      printf 'Removing Flatpak app: %s\n' "$app"
      flatpak uninstall -y "$app" 2>/dev/null || true
    done
  fi

  if ((${#files[@]})); then
    remove_recorded_files "${files[@]}"
  fi
  remove_navtop_local_install

  local do_bootstrap=0
  if ((${#bootstraps[@]})); then
    if [[ "$PURGE_BOOTSTRAP" == 1 ]]; then
      do_bootstrap=1
    elif [[ "$ASSUME_YES" == 1 ]]; then
      do_bootstrap=0
      printf 'Leaving optional bootstrap tools installed (paru/Flatpak). Use --purge-bootstrap to remove them.\n'
    else
      read -r -p 'Also remove optional paru/Flatpak that Navuryx installed? (yay is never removed) [y/N] ' answer
      [[ "$answer" =~ ^[Yy]$ ]] && do_bootstrap=1
    fi
  fi

  if [[ "$do_bootstrap" == 1 ]]; then
    local b
    for b in "${bootstraps[@]}"; do
      [[ "$b" == yay ]] && continue
      printf 'Removing optional bootstrap: %s\n' "$b"
      if command -v pacman >/dev/null 2>&1; then
        sudo pacman -Rns --noconfirm "$b" 2>/dev/null || true
      elif command -v dnf >/dev/null 2>&1; then
        sudo dnf remove -y "$b" 2>/dev/null || true
      elif command -v zypper >/dev/null 2>&1; then
        sudo zypper remove -y "$b" 2>/dev/null || true
      fi
    done
  fi

  if [[ "$PURGE_STATE" == 1 ]]; then
    rm -f "$PKG_MANIFEST"
  else
    : > "$PKG_MANIFEST"
  fi
}

decide_remove_packages
if [[ "$REMOVE_PACKAGES" == 1 ]]; then
  remove_recorded_packages
else
  printf 'Recorded packages were left installed.\n'
fi

if [[ "$PURGE_STATE" == 1 ]]; then
  keep="$snapshot"
  if [[ -d "$NAV_STATE" ]]; then
    find "$NAV_STATE" -mindepth 1 -maxdepth 1 ! -path "$keep" ! -path "$NAV_STATE/uninstall-snapshots" -exec rm -rf {} + 2>/dev/null || true
    if [[ -d "$NAV_STATE/uninstall-snapshots" ]]; then
      find "$NAV_STATE/uninstall-snapshots" -mindepth 1 -maxdepth 1 ! -path "$keep" -exec rm -rf {} + 2>/dev/null || true
    fi
  fi
  printf 'Purged Navuryx state (kept uninstall snapshot).\n'
fi

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
fi

printf '\nNavuryx was removed.\n'
printf 'The configuration present immediately before removal is saved in:\n  %s\n' "$snapshot"
if [[ "$MODE" == restore ]]; then
  if [[ "$restored_hypr" == 1 ]]; then
    printf 'Your previous theme/configuration was restored.\n'
  else
    printf 'Stock Hyprland defaults were installed (no prior hypr config in the backup).\n'
  fi
fi
printf 'yay was left installed (required AUR helper).\n'
if [[ "$REMOVE_PACKAGES" == 1 ]]; then
  printf 'Theme packages from the install-deps manifest were removed when present.\n'
else
  printf 'Theme packages from the install-deps manifest were left installed.\n'
fi
printf '\nIMPORTANT: Fully log out of Hyprland and log back in so the session loads the restored config.\n'
printf 'A soft reload is not enough when switching away from Navuryx.\n'
