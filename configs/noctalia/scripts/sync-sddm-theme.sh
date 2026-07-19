#!/usr/bin/env bash
set -uo pipefail

readonly SYNC_DIR="/var/cache/niri-rice"
readonly WALLPAPER_PATH="$SYNC_DIR/wallpaper"
readonly THEME_CONF="$SYNC_DIR/theme.conf.user"
readonly THEME_LINK="/usr/share/sddm/themes/sugar-candy/theme.conf"

mkdir -p "$SYNC_DIR" 2>/dev/null || true

sync_wallpaper() {
    local src="$1"
    [ -n "$src" ] && [ -f "$src" ] || return 1
    local tmp="${WALLPAPER_PATH}.tmp.$$"
    cp -- "$src" "$tmp" || return 1
    chmod 0644 "$tmp"
    mv -f -- "$tmp" "$WALLPAPER_PATH"
}

if [ -n "${NOCTALIA_WALLPAPER_PATH:-}" ] && sync_wallpaper "$NOCTALIA_WALLPAPER_PATH"; then
    :
else
    attempt=0
    ok=false
    while [ "$attempt" -lt 5 ]; do
        wallpaper="$(qs -c noctalia-shell ipc call wallpaper get "" 2>/dev/null || true)"
        if sync_wallpaper "$wallpaper"; then
            ok=true
            break
        fi
        attempt=$((attempt + 1))
        sleep 0.2
    done
    $ok || printf 'sync-sddm-theme: no valid wallpaper after retries\n' >&2
fi

if [ -f "$THEME_CONF" ]; then
    chmod 0644 "$THEME_CONF"
else
    printf 'sync-sddm-theme: %s missing\n' "$THEME_CONF" >&2
fi

if [ -L "$THEME_LINK" ]; then
    t="$(readlink -f "$THEME_LINK" 2>/dev/null || true)"
    [ "$t" = "$(readlink -f "$THEME_CONF" 2>/dev/null || true)" ] || printf 'sync-sddm-theme: WARNING - %s does not point at %s\n' "$THEME_LINK" "$THEME_CONF" >&2
else
    printf 'sync-sddm-theme: WARNING - %s is not a symlink, re-run installer\n' "$THEME_LINK" >&2
fi
exit 0
