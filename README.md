# Navuryx Hyprland Theme

Navuryx is a complete Hyprland desktop environment with a unified Quickshell interface, Waybar/Rofi recovery mode, guided application setup, AI and gaming integrations, theme management, backups, repair tools and a complete managed uninstaller.

## Install

```bash
git clone https://github.com/navuryx-org/navuryx-hyprland-theme.git
cd navuryx-hyprland-theme
chmod +x install.sh uninstall.sh navuryx
./install.sh
```

Running `./install.sh --install-deps` opens the same guided installer.

The installer currently provides first-class automatic package installation for Arch Linux and compatible Pacman-based distributions.

## What the guided installer asks

- Installation profile: Full, Custom, Recovery or configuration-only
- One or more browsers
- One or more Discord clients, including Navtop
- One or more VPN tools
- Development tools
- Media and creator applications
- Optional Flatpak and user-level Flathub
- Required Yay installation
- Optional Paru installation

Full installations include the Navuryx AI and gaming foundations.

### Multi-selection

The application menus accept:

```text
1
1,3,5
1 3 5
1-4
a       select all
n       select none
Enter   accept the displayed default
```

## Password prompts

The installer may request your **local Linux password** through `sudo` when installing system packages.

It does **not** require a GitHub username, GitHub password or access token. Git credential prompts are disabled. If a public dependency URL is unavailable, installation stops with an error instead of asking for GitHub credentials.

## Faster installation

Version 6.4 consolidates package resolution and installation:

- The Pacman repository index is loaded once instead of queried separately for every package.
- Duplicate package requests are removed.
- Repository and AUR packages are installed in batches.
- Yay and Paru use public AUR snapshot archives rather than Git clones.
- The complete desktop dependency graph no longer starts a second nested installer.
- MicroTeX uses the verified public source archive.
- Already-installed packages are skipped.

Preview the package plan without modifying the system:

```bash
./install.sh --plan
```

## Automated examples

Full installation with Flatpak and Paru:

```bash
./install.sh --full --install-deps --with-flatpak --with-paru
```

Noninteractive package confirmation:

```bash
./install.sh --full --install-deps --with-flatpak --with-paru --yes
```

Choose applications directly:

```bash
./install.sh \
  --full \
  --install-deps \
  --apps firefox,zen,navtop,wireguard,openvpn \
  --with-paru
```

## Backups and recovery

Before configuration activation, Navuryx stores a timestamped copy of existing managed configuration under:

```text
~/.local/state/navuryx/backups/
```

Check the installation:

```bash
./install.sh --verify
navuryx doctor
```

Repair managed files without replacing personal overrides:

```bash
./install.sh --repair
```

## Spotify and Navify

When Spotify is selected, the installer automatically downloads the matching public Navify CLI release and installs it to `~/.local/bin/navify`. It does not run Navify against Spotify automatically; use `navify backup apply` after Spotify is installed when you are ready.

## Uninstall

The default uninstaller removes everything Navuryx recorded as newly installed, restores the newest pre-Navuryx configuration when available, removes Navify installed for Spotify, and deletes Navuryx state and backups after restoration:

```bash
./uninstall.sh
```

Skip confirmation:

```bash
./uninstall.sh --yes
```

Keep selected parts with flags such as `--keep-installed-apps`, `--keep-dependencies`, `--keep-helpers`, `--keep-flatpak`, `--keep-backups`, or `--no-restore`. Packages that existed before Navuryx are not recorded and are not removed.

## Main commands

```text
navuryx shell
navuryx spotlight
navuryx ai
navuryx overview
navuryx task-view
navuryx control-center
navuryx notifications
navuryx wallpaper
navuryx theme
navuryx settings
navuryx capture
navuryx record
navuryx vpn
navuryx gaming
navuryx lock
navuryx power
navuryx doctor
```

## Website

The static project website is stored in `website/` and uses plain HTML, CSS and JavaScript. The included GitHub Pages workflow deploys it automatically from the default branch.

## License

Copyright © 2026 Navuryx / HitBoyXx23. See `LICENSE`.
