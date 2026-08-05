# This script is meant to be sourced.
# It's not for directly running.

export GIT_TERMINAL_PROMPT=0
export GCM_INTERACTIVE=never
export GIT_ASKPASS=/bin/false

install-yay(){
  x sudo pacman -S --needed --noconfirm base-devel curl tar
  x rm -rf /tmp/buildyay
  x mkdir -p /tmp/buildyay
  x curl -fL --retry 3 --connect-timeout 15 \
    https://aur.archlinux.org/cgit/aur.git/snapshot/yay-bin.tar.gz \
    -o /tmp/buildyay/yay-bin.tar.gz
  x tar -xzf /tmp/buildyay/yay-bin.tar.gz -C /tmp/buildyay
  x cd /tmp/buildyay/yay-bin
  x makepkg -si --needed --noconfirm
  x cd ${REPO_ROOT}
  rm -rf /tmp/buildyay
}

# Navuryx never removes, replaces, or reclassifies existing packages during installation.

#####################################################################################
if ! command -v pacman >/dev/null 2>&1; then
  printf "${STY_RED}[$0]: pacman not found, it seems that the system is not ArchLinux or Arch-based distros. Aborting...${STY_RST}\n"
  exit 1
fi

# Keep makepkg from resetting sudo credentials
if [[ -z "${PACMAN_AUTH:-}" ]]; then
  export PACMAN_AUTH="sudo"
fi

# Issue #363
case $SKIP_SYSUPDATE in
  true) true;;
  *) v sudo pacman -Syu;;
esac

# Use the selected AUR helper without clean builds or package removals.
if ! command -v yay >/dev/null 2>&1;then
  echo -e "${STY_YELLOW}[$0]: \"yay\" not found.${STY_RST}"
  showfun install-yay
  v install-yay
fi

# https://github.com/Navuryx/dots-hyprland/issues/581
# yay -Bi is kinda hit or miss, instead cd into the relevant directory and manually source and install deps
install-local-pkgbuild() {
  local location=$1
  local installflags=$2

  x pushd $location

  source ./PKGBUILD
  x yay -S --sudoloop $installflags "${depends[@]}"
  # man makepkg:
  # -A, --ignorearch: Ignore a missing or incomplete arch field in the build script.
  # -s, --syncdeps: Install missing dependencies using pacman. When build-time or run-time dependencies are not found, pacman will try to resolve them.
  # -f, --force: build a package even if it already exists in the PKGDEST
  # -i, --install: Install or upgrade the package after a successful build using pacman(8).
  # In https://github.com/Navuryx/dots-hyprland/issues/823#issuecomment-3394774645 it's suggested to use `sudo pacman -U --noconfirm *.pkg.tar.zst` instead of `makepkg -i`, however it's possible that multiple *.pkg.tar.zst exist, which makes this command not reliable.
  x makepkg -Asi --noconfirm
  x popd
}

# Install core dependencies from the meta-packages
metapkgs=(./sdata/dist-arch/illogical-impulse-{audio,backlight,basic,fonts-themes,kde,portal,python,screencapture,toolkit,widgets})
metapkgs+=(./sdata/dist-arch/illogical-impulse-hyprland)
metapkgs+=(./sdata/dist-arch/illogical-impulse-microtex-git)
metapkgs+=(./sdata/dist-arch/illogical-impulse-quickshell-git)
metapkgs+=(./sdata/dist-arch/illogical-impulse-bibata-modern-classic-bin)

for i in "${metapkgs[@]}"; do
  metainstallflags="--needed"
  $ask && showfun install-local-pkgbuild || metainstallflags="$metainstallflags --noconfirm"
  v install-local-pkgbuild "$i" "$metainstallflags"
done

## Optional dependencies
if pacman -Qs ^plasma-browser-integration$ ;then SKIP_PLASMAINTG=true;fi
case $SKIP_PLASMAINTG in
  true) true;;
  *)
    if $ask;then
      echo -e "${STY_YELLOW}[$0]: NOTE: The size of \"plasma-browser-integration\" is ~600 KiB, but if you don't yet have KDE on your system it'll pull an extra ~600MiB of packages.${STY_RST}"
      echo -e "${STY_YELLOW}It is needed if you want playtime of media in Firefox to be shown on the music controls widget.${STY_RST}"
      echo -e "${STY_YELLOW}Install it? [y/N]${STY_RST}"
      read -p "====> " p
    else
      p=y
    fi
    case $p in
      y) x sudo pacman -S --needed --noconfirm plasma-browser-integration ;;
      *) echo "Ok, won't install"
    esac
    ;;
esac
