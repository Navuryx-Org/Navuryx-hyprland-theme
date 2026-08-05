#!/usr/bin/env bash
# shellcheck shell=bash

# Public downloads must fail instead of opening an interactive Git credential
# prompt. The installer may ask for the local sudo password, but never GitHub
# credentials.
export GIT_TERMINAL_PROMPT=0
export GCM_INTERACTIVE=never
export GIT_ASKPASS=/bin/false
export SSH_ASKPASS=/bin/false

log_pkg() { printf '[packages] %s\n' "$*"; }
warn_pkg() { printf '[packages/warn] %s\n' "$*" >&2; }

run_pkg() {
  if [[ ${NAVURYX_DRY_RUN:-0} == 1 ]]; then
    printf '+ '; printf '%q ' "$@"; printf '\n'
  else
    "$@"
  fi
}

is_arch_system() { command -v pacman >/dev/null 2>&1; }

# Loading the repository package list once is significantly faster than a
# separate `pacman -Si` network/database lookup for every package.
declare -A NAVURYX_REPO_INDEX=()
NAVURYX_REPO_INDEX_READY=0
load_repo_index() {
  [[ $NAVURYX_REPO_INDEX_READY == 1 ]] && return 0
  is_arch_system || return 1
  local pkg
  while IFS= read -r pkg; do
    [[ -n $pkg ]] && NAVURYX_REPO_INDEX[$pkg]=1
  done < <(pacman -Slq 2>/dev/null | sort -u)
  NAVURYX_REPO_INDEX_READY=1
}

repo_available() {
  load_repo_index || return 1
  [[ ${NAVURYX_REPO_INDEX[$1]:-0} == 1 ]]
}

record_package() {
  local kind=$1 name=$2 target
  [[ -n ${PACKAGE_MANIFEST:-} ]] || return 0
  target="${PACKAGE_MANIFEST}.tmp"
  mkdir -p "$(dirname "$PACKAGE_MANIFEST")"
  printf '%s\t%s\n' "$kind" "$name" >> "$target"
}

install_repo_packages() {
  is_arch_system || { warn_pkg "Native package installation currently supports Arch/pacman systems."; return 1; }
  local pkg
  local -A seen=()
  local available=() unavailable=()
  for pkg in "$@"; do
    [[ -n $pkg && -z ${seen[$pkg]:-} ]] || continue
    seen[$pkg]=1
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      log_pkg "$pkg already installed"
    elif repo_available "$pkg"; then
      available+=("$pkg")
    else
      unavailable+=("$pkg")
    fi
  done
  if ((${#available[@]})); then
    local cmd=(sudo pacman -S --needed)
    [[ ${YES:-0} == 1 ]] && cmd+=(--noconfirm)
    cmd+=("${available[@]}")
    run_pkg "${cmd[@]}"
    for pkg in "${available[@]}"; do record_package "repo-${PACKAGE_PURPOSE:-dependency}" "$pkg"; done
  fi
  ((${#unavailable[@]} == 0)) || warn_pkg "Not found in enabled repositories: ${unavailable[*]}"
}

# Download an AUR snapshot over HTTPS instead of cloning its Git repository.
# This is faster for one-off package builds and cannot prompt for a username.
install_aur_helper() {
  local helper=$1 package build_root archive source_dir
  [[ $helper == yay || $helper == paru ]] || return 0
  command -v "$helper" >/dev/null 2>&1 && { log_pkg "$helper already installed"; return 0; }
  is_arch_system || { warn_pkg "$helper installation is available only on Arch/pacman systems."; return 1; }
  package="${helper}-bin"
  PACKAGE_PURPOSE=dependency install_repo_packages base-devel git curl tar

  build_root=$(mktemp -d)
  archive="$build_root/$package.tar.gz"
  log_pkg "Downloading the public AUR snapshot for $package"
  if [[ ${NAVURYX_DRY_RUN:-0} == 1 ]]; then
    run_pkg curl -fL --retry 3 --connect-timeout 15 \
      "https://aur.archlinux.org/cgit/aur.git/snapshot/${package}.tar.gz" -o "$archive"
    printf '+ tar -xzf %q -C %q\n' "$archive" "$build_root"
    printf '+ (cd %q && makepkg -si --needed%s)\n' "$build_root/$package" "$([[ ${YES:-0} == 1 ]] && echo ' --noconfirm')"
    rm -rf "$build_root"
    return 0
  fi

  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
    "https://aur.archlinux.org/cgit/aur.git/snapshot/${package}.tar.gz" -o "$archive"
  tar -xzf "$archive" -C "$build_root"
  source_dir="$build_root/$package"
  [[ -f $source_dir/PKGBUILD ]] || { rm -rf "$build_root"; warn_pkg "AUR snapshot did not contain PKGBUILD: $package"; return 1; }

  printf '\nAUR packages are user-maintained. PKGBUILD:\n  %s\n\n' "$source_dir/PKGBUILD"
  if [[ ${YES:-0} != 1 ]]; then
    local answer
    read -r -p "Build and install $package? [Y/n] " answer
    [[ ! $answer =~ ^[Nn]$ ]] || { rm -rf "$build_root"; return 1; }
  fi
  (
    cd "$source_dir"
    if [[ ${YES:-0} == 1 ]]; then makepkg -si --needed --noconfirm; else makepkg -si --needed; fi
  )
  command -v "$helper" >/dev/null 2>&1 || { rm -rf "$build_root"; warn_pkg "$helper was not available after installation."; return 1; }
  record_package aur-helper "$package"
  rm -rf "$build_root"
}

install_flatpak_support() {
  local newly_installed=0 remote_existed=0
  if ! command -v flatpak >/dev/null 2>&1; then
    PACKAGE_PURPOSE=runtime install_repo_packages flatpak || return 1
    newly_installed=1
  fi
  if command -v flatpak >/dev/null 2>&1; then
    flatpak remotes --user --columns=name 2>/dev/null | grep -Fxq flathub && remote_existed=1 || true
  fi
  run_pkg flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  [[ $newly_installed == 1 ]] && record_package repo-runtime flatpak
  [[ $remote_existed == 0 ]] && record_package flatpak-remote flathub
}

choose_aur_command() {
  case "${AUR_HELPER:-none}" in
    paru|both) echo paru;;
    yay) echo yay;;
    *) echo "";;
  esac
}

install_aur_packages() {
  local helper pkg
  helper=$(choose_aur_command)
  [[ -n $helper ]] || { warn_pkg "AUR packages requested, but no AUR helper was selected."; return 1; }
  local -A seen=()
  local pending=()
  for pkg in "$@"; do
    [[ -n $pkg && -z ${seen[$pkg]:-} ]] || continue
    seen[$pkg]=1
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      log_pkg "$pkg already installed"
    else
      pending+=("$pkg")
    fi
  done
  ((${#pending[@]})) || return 0
  local cmd=("$helper" -S --needed)
  [[ ${YES:-0} == 1 ]] && cmd+=(--noconfirm)
  cmd+=("${pending[@]}")
  run_pkg "${cmd[@]}"
  for pkg in "${pending[@]}"; do record_package "aur-${PACKAGE_PURPOSE:-app}" "$pkg"; done
}

install_repo_or_aur_packages() {
  local pkg
  local repo=() aur=()
  for pkg in "$@"; do
    [[ -n $pkg ]] || continue
    if pacman -Q "$pkg" >/dev/null 2>&1; then
      log_pkg "$pkg already installed"
    elif repo_available "$pkg"; then
      repo+=("$pkg")
    else
      aur+=("$pkg")
    fi
  done
  ((${#repo[@]} == 0)) || install_repo_packages "${repo[@]}"
  if ((${#aur[@]})); then
    PACKAGE_PURPOSE=${PACKAGE_PURPOSE:-dependency} install_aur_packages "${aur[@]}"
  fi
}

install_flatpak_apps() {
  local app
  local -A seen=()
  local pending=()
  for app in "$@"; do
    [[ -n $app && -z ${seen[$app]:-} ]] || continue
    seen[$app]=1
    if flatpak info --user "$app" >/dev/null 2>&1; then
      log_pkg "$app already installed"
    else
      pending+=("$app")
    fi
  done
  ((${#pending[@]})) || return 0
  local cmd=(flatpak install --user flathub)
  [[ ${YES:-0} == 1 ]] && cmd+=(-y)
  cmd+=("${pending[@]}")
  run_pkg "${cmd[@]}"
  for app in "${pending[@]}"; do record_package flatpak-app "$app"; done
}

safe_public_git_clone() {
  local url=$1 destination=$2
  [[ $url == https://github.com/* || $url == https://aur.archlinux.org/* ]] || {
    warn_pkg "Refusing unapproved Git source: $url"
    return 1
  }
  if [[ ${NAVURYX_DRY_RUN:-0} == 1 ]]; then
    run_pkg env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git clone --depth 1 "$url" "$destination"
    return 0
  fi
  log_pkg "Verifying public repository: $url"
  timeout 30 env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GIT_ASKPASS=/bin/false \
    git ls-remote "$url" HEAD >/dev/null 2>&1 || {
      warn_pkg "Public repository is unavailable; no credentials were requested: $url"
      return 1
    }
  env GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GIT_ASKPASS=/bin/false \
    git clone --depth 1 "$url" "$destination"
}

install_navtop() {
  if command -v navtop >/dev/null 2>&1 || (command -v pacman >/dev/null 2>&1 && pacman -Q navtop >/dev/null 2>&1); then
    log_pkg "Navtop already installed"
    return 0
  fi

  is_arch_system || {
    warn_pkg "Navtop automatic installation currently supports Arch/pacman systems. Use a Navtop AppImage on other distributions."
    return 1
  }

  local deps=(
    gtk3 libnotify nss libxss libxtst xdg-utils at-spi2-core libsecret
    pipewire libappindicator-gtk3 curl jq git base-devel python pkgconf glib2 bun
  )
  PACKAGE_PURPOSE=app-dependency install_repo_packages "${deps[@]}"

  if [[ ${NAVURYX_DRY_RUN:-0} == 1 ]]; then
    run_pkg curl -fsSL https://api.github.com/repos/Navcord/Navtop/releases/latest
    printf '+ download matching Navtop pacman release for %q\n' "$(uname -m)"
    printf '+ sudo pacman -U --needed NAVTOP_RELEASE_PACKAGE\n'
    printf '+ fallback: verified public clone https://github.com/Navcord/Navtop.git\n'
    return 0
  fi

  local work api_json urls asset_url arch pkg_file
  work=$(mktemp -d)
  arch=$(uname -m)
  api_json="$work/release.json"

  log_pkg "Checking the latest Navtop GitHub release"
  if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 \
      https://api.github.com/repos/Navcord/Navtop/releases/latest -o "$api_json"; then
    urls=$(jq -r '.assets[]?.browser_download_url // empty' "$api_json")
    case "$arch" in
      aarch64|arm64)
        asset_url=$(printf '%s\n' "$urls" | grep -Ei '(arm64|aarch64).*(\.pacman|\.pkg\.tar\.(zst|xz|gz))$' | head -n1 || true)
        ;;
      x86_64|amd64)
        asset_url=$(printf '%s\n' "$urls" | grep -Ei '(\.pacman|\.pkg\.tar\.(zst|xz|gz))$' | grep -Evi '(arm64|aarch64)' | head -n1 || true)
        ;;
      *) asset_url="" ;;
    esac
  else
    asset_url=""
  fi

  if [[ -n $asset_url ]]; then
    pkg_file="$work/${asset_url##*/}"
    log_pkg "Downloading Navtop release: ${asset_url##*/}"
    curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 "$asset_url" -o "$pkg_file"
    local cmd=(sudo pacman -U --needed)
    [[ ${YES:-0} == 1 ]] && cmd+=(--noconfirm)
    cmd+=("$pkg_file")
    run_pkg "${cmd[@]}"
  else
    warn_pkg "No compatible Navtop package was found; using the verified public source repository."
    safe_public_git_clone https://github.com/Navcord/Navtop.git "$work/Navtop" || { rm -rf "$work"; return 1; }
    (
      cd "$work/Navtop"
      run_pkg bun install --frozen-lockfile
      run_pkg bun package:linux:arch
    )
    pkg_file=$(find "$work/Navtop/dist" -maxdepth 1 -type f \
      \( -name 'navtop-*.pacman' -o -name 'navtop-*.pkg.tar.zst' -o -name 'navtop-*.pkg.tar.xz' \) \
      | head -n1)
    [[ -n $pkg_file ]] || { rm -rf "$work"; warn_pkg "Navtop build completed without a pacman package."; return 1; }
    local cmd=(sudo pacman -U --needed)
    [[ ${YES:-0} == 1 ]] && cmd+=(--noconfirm)
    cmd+=("$pkg_file")
    run_pkg "${cmd[@]}"
  fi

  if ! command -v navtop >/dev/null 2>&1 && ! pacman -Q navtop >/dev/null 2>&1; then
    rm -rf "$work"
    warn_pkg "Navtop installation did not produce a detectable navtop command/package."
    return 1
  fi

  record_package github-app navtop
  rm -rf "$work"
  log_pkg "Navtop installed with native Wayland/PipeWire dependencies"
}

install_navify() {
  local existing=""
  if command -v navify >/dev/null 2>&1; then
    existing=$(command -v navify)
    log_pkg "Navify already installed at $existing"
    return 0
  fi

  local target_dir=${BIN_HOME:-$HOME/.local/bin}
  local target="$target_dir/navify"
  local arch asset_pattern work api_json asset_url archive binary version

  case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) warn_pkg "Navify does not provide a Linux build for $(uname -m)."; return 1 ;;
  esac

  if is_arch_system; then
    PACKAGE_PURPOSE=app-dependency install_repo_packages curl jq tar
  fi
  for required in curl jq tar; do
    command -v "$required" >/dev/null 2>&1 || {
      warn_pkg "Navify installation requires: $required"
      return 1
    }
  done

  if [[ ${NAVURYX_DRY_RUN:-0} == 1 ]]; then
    printf '+ curl -fsSL https://api.github.com/repos/Navify/navify-cli/releases/latest\n'
    printf '+ download latest navify-linux-%s release\n' "$arch"
    printf '+ install -Dm755 navify %q\n' "$target"
    return 0
  fi

  work=$(mktemp -d)
  api_json="$work/release.json"
  archive="$work/navify.tar.gz"
  log_pkg "Installing Navify for the selected Spotify client"

  curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 \
    https://api.github.com/repos/Navify/navify-cli/releases/latest -o "$api_json" || {
      rm -rf "$work"
      warn_pkg "Could not read the latest Navify release."
      return 1
    }

  asset_pattern="navify-[0-9][0-9.]*-linux-${arch}\\.tar\\.gz$"
  asset_url=$(jq -r '.assets[]?.browser_download_url // empty' "$api_json" \
    | grep -E "$asset_pattern" | head -n1 || true)
  version=$(jq -r '.tag_name // empty' "$api_json" | sed 's/^v//')
  [[ -n $asset_url ]] || {
    rm -rf "$work"
    warn_pkg "No compatible Navify Linux release was found for $arch."
    return 1
  }

  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 "$asset_url" -o "$archive"
  tar -xzf "$archive" -C "$work"
  binary=$(find "$work" -type f -name navify -perm -u+x -print -quit)
  if [[ -z $binary ]]; then
    binary=$(find "$work" -type f -name navify -print -quit)
  fi
  [[ -n $binary ]] || {
    rm -rf "$work"
    warn_pkg "The Navify archive did not contain the navify binary."
    return 1
  }

  install -Dm755 "$binary" "$target"
  mkdir -p "${NAV_STATE:-$HOME/.local/state/navuryx}"
  printf '%s\n' "$target" > "${NAV_STATE:-$HOME/.local/state/navuryx}/navify-installed"
  printf '%s\n' "${version:-unknown}" > "${NAV_STATE:-$HOME/.local/state/navuryx}/navify-version"
  record_package custom-app "$target"
  rm -rf "$work"

  "$target" --version >/dev/null 2>&1 || warn_pkg "Navify installed, but its version check did not return successfully."
  log_pkg "Navify ${version:-latest} installed to $target"
}

install_custom_app() {
  case "$1" in
    navtop) install_navtop ;;
    *) warn_pkg "Unknown custom installer: $1"; return 1 ;;
  esac
}

install_app_ids() {
  local id repo aur flat source custom p
  local repo_pkgs=() aur_pkgs=() flat_apps=() custom_apps=() unresolved=()
  for id in "$@"; do
    [[ -n $id ]] || continue
    custom=$(catalog_custom_installer "$id")
    if [[ -n $custom ]]; then
      custom_apps+=("$custom")
      continue
    fi

    repo=$(catalog_repo_packages "$id")
    aur=$(catalog_aur_package "$id")
    flat=$(catalog_flatpak_id "$id")
    source=${APP_SOURCE:-auto}

    if [[ $source == flatpak && ${WITH_FLATPAK:-0} == 1 && -n $flat ]]; then
      flat_apps+=("$flat")
      continue
    fi

    if [[ -n $repo ]] && is_arch_system; then
      local all_available=1
      for p in $repo; do repo_available "$p" || { all_available=0; break; }; done
      if [[ $all_available == 1 ]]; then
        # shellcheck disable=SC2206
        local expanded=( $repo )
        repo_pkgs+=("${expanded[@]}")
        continue
      fi
    fi

    if [[ $source != flatpak && -n $aur && ${AUR_HELPER:-none} != none ]]; then
      aur_pkgs+=("$aur")
    elif [[ ${WITH_FLATPAK:-0} == 1 && -n $flat ]]; then
      flat_apps+=("$flat")
    elif [[ -n $repo ]]; then
      # shellcheck disable=SC2206
      local expanded=( $repo )
      repo_pkgs+=("${expanded[@]}")
    else
      unresolved+=("$id")
    fi
  done

  if ((${#repo_pkgs[@]})); then PACKAGE_PURPOSE=app install_repo_packages "${repo_pkgs[@]}"; fi
  if ((${#aur_pkgs[@]})); then PACKAGE_PURPOSE=app install_aur_packages "${aur_pkgs[@]}"; fi
  if ((${#flat_apps[@]})); then
    install_flatpak_support
    install_flatpak_apps "${flat_apps[@]}"
  fi
  for custom in "${custom_apps[@]}"; do install_custom_app "$custom"; done
  ((${#unresolved[@]} == 0)) || warn_pkg "No enabled source was found for: ${unresolved[*]}"
}
