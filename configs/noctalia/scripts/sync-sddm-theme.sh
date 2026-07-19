#!/usr/bin/env bash
set -euo pipefail

readonly SYNC_DIR="/var/cache/niri-rice"
readonly WALLPAPER_PATH="$SYNC_DIR/wallpaper"

mkdir -p "$SYNC_DIR"

wallpaper="$(qs -c noctalia-shell ipc call wallpaper get '' 2>/dev/null || true)"

if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
    tmp_wallpaper="${WALLPAPER_PATH}.tmp"
    cp -- "$wallpaper" "$tmp_wallpaper"
    chmod 0644 "$tmp_wallpaper"
    mv -f "$tmp_wallpaper" "$WALLPAPER_PATH"
fi
