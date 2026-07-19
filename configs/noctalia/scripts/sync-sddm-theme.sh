#!/usr/bin/env bash
set -euo pipefail

readonly SYNC_DIR="/var/cache/niri-rice"
readonly WALLPAPER_PATH="$SYNC_DIR/wallpaper"
readonly WALLPAPER_SOURCE="${NOCTALIA_WALLPAPER_PATH:-}"

# Noctalia owns the current wallpaper. The SDDM cache is deliberately kept
# outside $HOME so the greeter can read it before the user session starts.
if [[ -n "$WALLPAPER_SOURCE" && -f "$WALLPAPER_SOURCE" ]]; then
    tmp_wallpaper="${WALLPAPER_PATH}.tmp.$$"
    cp -- "$WALLPAPER_SOURCE" "$tmp_wallpaper"
    chmod 0644 "$tmp_wallpaper"
    mv -f -- "$tmp_wallpaper" "$WALLPAPER_PATH"
else
    wallpaper="$(qs -c noctalia-shell ipc call wallpaper get '' 2>/dev/null || true)"
    if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
        tmp_wallpaper="${WALLPAPER_PATH}.tmp.$$"
        cp -- "$wallpaper" "$tmp_wallpaper"
        chmod 0644 "$tmp_wallpaper"
        mv -f -- "$tmp_wallpaper" "$WALLPAPER_PATH"
    fi
fi

# The generated theme.conf.user is written by Noctalia's user-template engine.
# Keep the generated file readable by SDDM without modifying the packaged theme.
if [[ -f "$SYNC_DIR/theme.conf.user" ]]; then
    chmod 0644 "$SYNC_DIR/theme.conf.user"
fi
