#!/usr/bin/env bash
set -euo pipefail

readonly SYNC_DIR="/var/cache/niri-rice"
readonly WALLPAPER_PATH="$SYNC_DIR/wallpaper"
readonly WALLPAPER_SOURCE="${NOCTALIA_WALLPAPER_PATH:-}"

# Noctalia owns the current wallpaper. Keep a readable copy outside $HOME so
# SDDM can load it before the user session starts.
wallpaper=""
if [[ -n "$WALLPAPER_SOURCE" && -f "$WALLPAPER_SOURCE" ]]; then
    wallpaper="$WALLPAPER_SOURCE"
else
    wallpaper="$(qs -c noctalia-shell ipc call wallpaper get '' 2>/dev/null || true)"
fi

if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
    tmp_wallpaper="${WALLPAPER_PATH}.tmp.$$"
    cp -- "$wallpaper" "$tmp_wallpaper"
    chmod 0644 "$tmp_wallpaper"
    mv -f -- "$tmp_wallpaper" "$WALLPAPER_PATH"
fi

# Noctalia writes the generated theme.conf.user directly into SYNC_DIR.
# The installer creates a symlink from Sugar Candy's theme directory to it.
if [[ -f "$SYNC_DIR/theme.conf.user" ]]; then
    chmod 0644 "$SYNC_DIR/theme.conf.user"
fi
