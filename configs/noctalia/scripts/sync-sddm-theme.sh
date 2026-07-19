#!/usr/bin/env bash
set -uo pipefail

readonly SYNC_DIR="/var/cache/niri-rice"
readonly WALLPAPER_PATH="$SYNC_DIR/wallpaper"
readonly THEME_CONF="$SYNC_DIR/theme.conf.user"
readonly THEME_LINK="/usr/share/sddm/themes/sugar-candy/theme.conf"
readonly NOCTALIA_SETTINGS="${NOCTALIA_SETTINGS_FILE:-$HOME/.config/noctalia/settings.json}"

mkdir -p "$SYNC_DIR" 2>/dev/null || true

sync_wallpaper() {
    local src="$1"
    [ -n "$src" ] && [ -f "$src" ] || return 1
    local tmp="${WALLPAPER_PATH}.tmp.$$"
    cp -- "$src" "$tmp" || return 1
    chmod 0644 "$tmp"
    mv -f -- "$tmp" "$WALLPAPER_PATH"
}

sync_clock_format() {
    [ -f "$THEME_CONF" ] || return 1
    [ -f "$NOCTALIA_SETTINGS" ] || return 1
    command -v python &>/dev/null || return 1

    python - "$NOCTALIA_SETTINGS" "$THEME_CONF" <<'PY'
import json
import os
import sys
import tempfile

settings_path, theme_path = sys.argv[1:]

try:
    with open(settings_path, encoding="utf-8") as handle:
        settings = json.load(handle)
except (OSError, json.JSONDecodeError):
    raise SystemExit(1)


def find_clock(value):
    if isinstance(value, dict):
        if value.get("id") == "Clock":
            return value
        for child in value.values():
            result = find_clock(child)
            if result is not None:
                return result
    elif isinstance(value, list):
        for child in value:
            result = find_clock(child)
            if result is not None:
                return result
    return None

clock = find_clock(settings)
format_value = clock.get("formatHorizontal") if clock else None
if not isinstance(format_value, str) or not format_value:
    raise SystemExit(1)

escaped = format_value.replace("\\", "\\\\").replace('"', '\\"')
replacement = f'HourFormat="{escaped}"'

with open(theme_path, encoding="utf-8") as handle:
    lines = handle.readlines()

replaced = False
for index, line in enumerate(lines):
    if line.lstrip().startswith("HourFormat="):
        lines[index] = replacement + "\n"
        replaced = True
        break

if not replaced:
    insert_at = None
    for index, line in enumerate(lines):
        if line.strip() == "[General]":
            insert_at = index + 1
            break
    if insert_at is None:
        lines.append("\n[General]\n")
        insert_at = len(lines)
    lines.insert(insert_at, replacement + "\n")

directory = os.path.dirname(theme_path) or "."
fd, temporary = tempfile.mkstemp(prefix=".theme.conf.user.", dir=directory, text=True)
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.writelines(lines)
    os.chmod(temporary, 0o644)
    os.replace(temporary, theme_path)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
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
    if sync_clock_format; then
        :
    else
        printf 'sync-sddm-theme: could not synchronize Noctalia clock format\n' >&2
    fi
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
