#!/usr/bin/env bash
# Navuryx package catalog. Package availability is checked at install time.

NAVURYX_BUNDLE_NAMES=(daily privacy developer gaming creator ai communication media system all none custom)
NAVURYX_APP_IDS=(
  firefox chromium brave zen chrome edge floorp librewolf vivaldi opera
  navtop discord vesktop discord-canary webcord armcord
  spotify cider youtube-music nuclear vlc mpv
  wireguard openvpn protonvpn mullvad nordvpn surfshark pia
  ollama openwebui lmstudio anythingllm
  code vscode vscodium zed neovim cursor github-cli docker rust node bun python
  steam heroic lutris mangohud gamemode protonplus
  dolphin thunar nautilus pcmanfm
  kitty ghostty alacritty foot wezterm
  obs-studio kdenlive gimp inkscape blender
  flatseal appimage printing
)

catalog_label() {
  case "$1" in
    firefox) echo "Firefox";; chromium) echo "Chromium";; brave) echo "Brave";; zen) echo "Zen Browser";; chrome) echo "Google Chrome";; edge) echo "Microsoft Edge";; floorp) echo "Floorp";; librewolf) echo "LibreWolf";; vivaldi) echo "Vivaldi";; opera) echo "Opera";;
    navtop) echo "Navtop (Navcord Discord client)";; discord) echo "Discord";; vesktop) echo "Vesktop";; discord-canary) echo "Discord Canary";; webcord) echo "WebCord";; armcord) echo "ArmCord";;
    spotify) echo "Spotify";; cider) echo "Cider";; youtube-music) echo "YouTube Music Desktop";; nuclear) echo "Nuclear";; vlc) echo "VLC";; mpv) echo "mpv";;
    wireguard) echo "WireGuard tools";; openvpn) echo "OpenVPN + NetworkManager plugin";; protonvpn) echo "Proton VPN";; mullvad) echo "Mullvad VPN";; nordvpn) echo "NordVPN";; surfshark) echo "Surfshark";; pia) echo "Private Internet Access";;
    ollama) echo "Ollama";; openwebui) echo "Open WebUI";; lmstudio) echo "LM Studio";; anythingllm) echo "AnythingLLM Desktop";;
    code) echo "Code - OSS";; vscode) echo "Visual Studio Code";; vscodium) echo "VSCodium";; zed) echo "Zed";; neovim) echo "Neovim";; cursor) echo "Cursor";; github-cli) echo "GitHub CLI";; docker) echo "Docker";; rust) echo "Rust toolchain";; node) echo "Node.js + npm";; bun) echo "Bun";; python) echo "Python + pip";;
    steam) echo "Steam";; heroic) echo "Heroic Games Launcher";; lutris) echo "Lutris";; mangohud) echo "MangoHud";; gamemode) echo "GameMode";; protonplus) echo "ProtonPlus";;
    dolphin) echo "Dolphin";; thunar) echo "Thunar";; nautilus) echo "Nautilus";; pcmanfm) echo "PCManFM-Qt";;
    kitty) echo "Kitty";; ghostty) echo "Ghostty";; alacritty) echo "Alacritty";; foot) echo "Foot";; wezterm) echo "WezTerm";;
    obs-studio) echo "OBS Studio";; kdenlive) echo "Kdenlive";; gimp) echo "GIMP";; inkscape) echo "Inkscape";; blender) echo "Blender";;
    flatseal) echo "Flatseal";; appimage) echo "AppImage support";; printing) echo "Printing support";;
    *) echo "$1";;
  esac
}

catalog_bundle_apps() {
  case "$1" in
    daily) echo "firefox,navtop,vlc,dolphin,kitty";;
    privacy) echo "brave,navtop,wireguard,openvpn,protonvpn";;
    communication) echo "navtop,discord,vesktop,webcord,armcord";;
    media) echo "spotify,vlc,mpv";;
    developer) echo "code,neovim,github-cli,docker,rust,node,bun,python";;
    gaming) echo "steam,heroic,lutris,mangohud,gamemode,protonplus";;
    creator) echo "obs-studio,kdenlive,gimp,inkscape,blender";;
    ai) echo "ollama,openwebui";;
    system) echo "flatseal,appimage,printing";;
    all) (IFS=,; echo "${NAVURYX_APP_IDS[*]}");;
    none|custom|"") echo "";;
    *) return 1;;
  esac
}

catalog_repo_packages() {
  case "$1" in
    firefox) echo "firefox";; chromium) echo "chromium";; vivaldi) echo "vivaldi";; opera) echo "opera";;
    discord) echo "discord";;
    vlc) echo "vlc";; mpv) echo "mpv";;
    wireguard) echo "wireguard-tools";; openvpn) echo "openvpn networkmanager-openvpn";; protonvpn) echo "proton-vpn-gtk-app";;
    ollama) echo "ollama";;
    code) echo "code";; zed) echo "zed";; neovim) echo "neovim";; github-cli) echo "github-cli";; docker) echo "docker docker-compose";; rust) echo "rustup";; node) echo "nodejs npm";; bun) echo "bun";; python) echo "python python-pip";;
    steam) echo "steam";; lutris) echo "lutris";; mangohud) echo "mangohud lib32-mangohud";; gamemode) echo "gamemode lib32-gamemode";; protonplus) echo "protonplus";;
    dolphin) echo "dolphin";; thunar) echo "thunar";; nautilus) echo "nautilus";; pcmanfm) echo "pcmanfm-qt";;
    kitty) echo "kitty";; ghostty) echo "ghostty";; alacritty) echo "alacritty";; foot) echo "foot";; wezterm) echo "wezterm";;
    obs-studio) echo "obs-studio";; kdenlive) echo "kdenlive";; gimp) echo "gimp";; inkscape) echo "inkscape";; blender) echo "blender";;
    appimage) echo "fuse2";; printing) echo "cups system-config-printer";;
    *) echo "";;
  esac
}

catalog_aur_package() {
  case "$1" in
    brave) echo "brave-bin";; zen) echo "zen-browser-bin";; chrome) echo "google-chrome";; edge) echo "microsoft-edge-stable-bin";; floorp) echo "floorp-bin";; librewolf) echo "librewolf-bin";;
    vesktop) echo "vesktop";; discord-canary) echo "discord-canary";; webcord) echo "webcord-bin";; armcord) echo "armcord-bin";;
    spotify) echo "spotify";; cider) echo "cider-2-bin";; youtube-music) echo "youtube-music-bin";; nuclear) echo "nuclear-player-bin";;
    mullvad) echo "mullvad-vpn";; nordvpn) echo "nordvpn-bin";; surfshark) echo "surfshark-client";; pia) echo "private-internet-access-vpn";;
    openwebui) echo "open-webui";; lmstudio) echo "lmstudio";; anythingllm) echo "anythingllm-desktop-bin";;
    vscode) echo "visual-studio-code-bin";; vscodium) echo "vscodium-bin";; cursor) echo "cursor-bin";;
    heroic) echo "heroic-games-launcher-bin";;
    *) echo "";;
  esac
}

catalog_flatpak_id() {
  case "$1" in
    firefox) echo "org.mozilla.firefox";; chromium) echo "org.chromium.Chromium";; brave) echo "com.brave.Browser";; chrome) echo "com.google.Chrome";; edge) echo "com.microsoft.Edge";; floorp) echo "one.ablaze.floorp";; librewolf) echo "io.gitlab.librewolf-community";; vivaldi) echo "com.vivaldi.Vivaldi";; opera) echo "com.opera.Opera";;
    discord) echo "com.discordapp.Discord";; vesktop) echo "dev.vencord.Vesktop";; webcord) echo "io.github.spacingbat3.webcord";; armcord) echo "xyz.armcord.ArmCord";;
    spotify) echo "com.spotify.Client";; cider) echo "sh.cider.Cider";; vlc) echo "org.videolan.VLC";;
    protonvpn) echo "com.protonvpn.www";;
    code|vscode) echo "com.visualstudio.code";; vscodium) echo "com.vscodium.codium";; zed) echo "dev.zed.Zed";;
    steam) echo "com.valvesoftware.Steam";; heroic) echo "com.heroicgameslauncher.hgl";; lutris) echo "net.lutris.Lutris";;
    obs-studio) echo "com.obsproject.Studio";; kdenlive) echo "org.kde.kdenlive";; gimp) echo "org.gimp.GIMP";; inkscape) echo "org.inkscape.Inkscape";; blender) echo "org.blender.Blender";;
    flatseal) echo "com.github.tchx84.Flatseal";;
    *) echo "";;
  esac
}

catalog_custom_installer() {
  case "$1" in
    navtop) echo "navtop";;
    *) echo "";;
  esac
}

catalog_print() {
  local i=1 id
  for id in "${NAVURYX_APP_IDS[@]}"; do
    printf '%2d) %-18s %s\n' "$i" "$id" "$(catalog_label "$id")"
    ((i++))
  done
}
