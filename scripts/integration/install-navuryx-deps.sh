#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=${1:?repository root required}
# shellcheck source=scripts/install/package-manager.sh
source "$ROOT/scripts/install/package-manager.sh"

log(){ printf '[navuryx/dependencies] %s\n' "$*"; }
warn(){ printf '[navuryx/dependencies] warning: %s\n' "$*" >&2; }

# Consolidated lists replace the old nested dependency installer. Packages are
# resolved once, installed in batches, and already-installed items are skipped.
REPO_DEPS=(
  bc coreutils cmake curl wget ripgrep jq yq xdg-user-dirs rsync
  cava pavucontrol-qt wireplumber pipewire-pulse libdbusmenu-gtk3 playerctl
  geoclue brightnessctl ddcutil
  breeze fontconfig kitty fish eza starship ttf-jetbrains-mono-nerd
  bluedevil gnome-keyring networkmanager plasma-nm polkit-kde-agent dolphin
  xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
  clang uv gtk4 libadwaita libsoup3 libportal-gtk4 gobject-introspection
  slurp swappy tesseract tesseract-data-eng wf-recorder
  upower wtype ydotool fuzzel glib2 imagemagick hypridle hyprlock hyprpicker
  libqalculate hyprland hyprsunset wl-clipboard
  qt6-5compat qt6-avif-image-plugin qt6-imageformats qt6-multimedia qt6-positioning
  qt6-quicktimeline qt6-sensors qt6-svg qt6-tools qt6-translations qt6-virtualkeyboard
  qt6-wayland kirigami kdialog syntax-highlighting
  tinyxml2 gtkmm3 gtksourceviewmm cairomm
)

# These packages may be in an enabled repository or the AUR depending on the
# system and date. The package manager checks repositories first, then uses the
# selected helper in one batch.
FLEX_DEPS=(
  adw-gtk-theme-git darkly-bin matugen otf-space-grotesk
  ttf-material-symbols-variable-git ttf-readex-pro ttf-rubik-vf ttf-twemoji
  hyprshot songrec translate-shell wlogout
)

install_microtex() {
  [[ -x /opt/MicroTeX/LaTeX ]] && { log 'MicroTeX already installed'; return 0; }

  local work archive source_dir build_dir jobs
  work=$(mktemp -d)
  archive="$work/microtex.tar.gz"
  jobs=$(nproc 2>/dev/null || echo 2)
  log 'Downloading the verified public MicroTeX source archive'

  if [[ ${NAVURYX_DRY_RUN:-0} == 1 ]]; then
    printf '+ curl -fL https://github.com/NanoMichael/MicroTeX/archive/refs/heads/master.tar.gz -o %q\n' "$archive"
    printf '+ cmake configure/build MicroTeX with %q jobs\n' "$jobs"
    printf '+ sudo install MicroTeX into /opt/MicroTeX\n'
    rm -rf "$work"
    return 0
  fi

  curl -fL --retry 3 --retry-delay 2 --connect-timeout 15 \
    https://github.com/NanoMichael/MicroTeX/archive/refs/heads/master.tar.gz \
    -o "$archive"
  tar -xzf "$archive" -C "$work"
  source_dir=$(find "$work" -mindepth 1 -maxdepth 1 -type d -name 'MicroTeX-*' | head -n1)
  [[ -n $source_dir ]] || { rm -rf "$work"; echo 'MicroTeX archive layout was unexpected.' >&2; return 1; }

  # Compatibility patches are applied only when the old strings exist.
  sed -i 's/gtksourceviewmm-3.0/gtksourceviewmm-4.0/g' "$source_dir/CMakeLists.txt" 2>/dev/null || true
  sed -i 's/tinyxml2\.so\.10/tinyxml2.so.11/g' "$source_dir/CMakeLists.txt" 2>/dev/null || true
  # Patch known upstream build breakages on newer Arch toolchains.
  if [[ -f "$source_dir/src/platform/cairo/graphic_cairo.cpp" ]]; then
    sed -i 's/\<fCFreeTypeQuery\>/FcFreeTypeQuery/g' "$source_dir/src/platform/cairo/graphic_cairo.cpp" 2>/dev/null || true
    if ! grep -q 'fontconfig/fcfreetype.h' "$source_dir/src/platform/cairo/graphic_cairo.cpp"; then
      sed -i '/#include <fontconfig\/fontconfig.h>/a #include <fontconfig/fcfreetype.h>' "$source_dir/src/platform/cairo/graphic_cairo.cpp" 2>/dev/null || true
    fi
  fi

  build_dir="$source_dir/build"
  cmake -S "$source_dir" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$build_dir" --parallel "$jobs"
  [[ -x $build_dir/LaTeX ]] || { rm -rf "$work"; echo 'MicroTeX build did not create LaTeX.' >&2; return 1; }
  sudo install -d -m755 /opt/MicroTeX
  sudo install -m755 "$build_dir/LaTeX" /opt/MicroTeX/LaTeX
  sudo rm -rf /opt/MicroTeX/res
  sudo cp -a "$build_dir/res" /opt/MicroTeX/res
  record_package custom-dependency /opt/MicroTeX
  rm -rf "$work"
}

log 'installing the complete Navuryx dependency set in consolidated batches'
PACKAGE_PURPOSE=dependency install_repo_packages "${REPO_DEPS[@]}"
PACKAGE_PURPOSE=dependency install_repo_or_aur_packages "${FLEX_DEPS[@]}"
if ! install_microtex; then
  warn 'MicroTeX failed to build or install; continuing without it. LaTeX rendering will be disabled until MicroTeX is installed.'
fi
log 'dependency installation complete'
