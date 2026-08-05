#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=${1:?repository root required}
CONFIG_HOME=${2:?config home required}
DATA_HOME=${3:?data home required}
STATE_HOME=${4:?state home required}
MANIFEST_TMP=${5:?manifest temp path required}

COMPONENTS="$ROOT/vendor"
COMPONENT_DEST="$DATA_HOME/navuryx/components"
PROFILE_DEST="$CONFIG_HOME/navuryx/profiles"
mkdir -p "$COMPONENT_DEST" "$PROFILE_DEST" "$CONFIG_HOME/quickshell"

log(){ printf '[navuryx/integration] %s\n' "$*"; }
record_tree(){
  local path=$1
  [[ -e $path ]] || return 0
  find "$path" \( -type f -o -type l \) -print >> "$MANIFEST_TMP"
}
copy_component(){
  local name=$1 src=$2 dst="$COMPONENT_DEST/$name"
  [[ -d $src ]] || return 0
  rm -rf "$dst"
  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
  rm -rf "$dst/.git"
  record_tree "$dst"
}

copy_component shell "$COMPONENTS/navuryx-shell"
copy_component core "$COMPONENTS/navuryx-core"

# Install the complete Navuryx Quickshell desktop as the only full shell.
FULL_QS="$COMPONENTS/navuryx-shell/dots/.config/quickshell/ii"
if [[ -d $FULL_QS ]]; then
  rm -rf "$CONFIG_HOME/quickshell/navuryx"
  cp -a "$FULL_QS" "$CONFIG_HOME/quickshell/navuryx"
  record_tree "$CONFIG_HOME/quickshell/navuryx"
  log 'installed complete Navuryx Quickshell desktop'
fi

# Merge application-level theme and desktop integrations without replacing
# files already installed by the primary Navuryx configuration layer.
for rel in matugen fontconfig fuzzel kde-material-you-colors xdg-desktop-portal; do
  src="$COMPONENTS/navuryx-shell/dots/.config/$rel"
  dst="$CONFIG_HOME/$rel"
  [[ -d $src ]] || continue
  mkdir -p "$dst"
  cp -an "$src"/. "$dst"/ 2>/dev/null || true
  record_tree "$dst"
done

cat > "$PROFILE_DEST/full.env" <<'PROFILE'
NAVURYX_PROFILE=full
NAVURYX_SHELL=navuryx
NAVURYX_THEME_ENGINE=unified
NAVURYX_FEATURE_SET=complete
PROFILE
cat > "$PROFILE_DEST/lite.env" <<'PROFILE'
NAVURYX_PROFILE=lite
NAVURYX_SHELL=navuryx
NAVURYX_THEME_ENGINE=unified
NAVURYX_FEATURE_SET=core
PROFILE
cat > "$PROFILE_DEST/recovery.env" <<'PROFILE'
NAVURYX_PROFILE=recovery
NAVURYX_SHELL=waybar
NAVURYX_THEME_ENGINE=unified
NAVURYX_FEATURE_SET=recovery
PROFILE
record_tree "$PROFILE_DEST"

mkdir -p "$STATE_HOME/navuryx"
printf '%s\n' full > "$STATE_HOME/navuryx/profile"
cat > "$STATE_HOME/navuryx/components.tsv" <<STATUS
shell\tbundled
core\tbundled
STATUS

log 'unified Navuryx profile installed'
