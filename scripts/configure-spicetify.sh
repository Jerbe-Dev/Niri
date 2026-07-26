#!/usr/bin/env bash
set -euo pipefail

log() { printf '[spicetify] %s\n' "$*"; }

command -v spotify >/dev/null 2>&1 || { log 'Spotify is not installed.'; exit 0; }
command -v spicetify >/dev/null 2>&1 || { log 'Spicetify is not installed.'; exit 0; }

spotify_dir="$(spicetify config spotify_path 2>/dev/null | sed -n 's/^spotify_path[[:space:]]*=[[:space:]]*//p' | tail -n1)"
spotify_dir="${spotify_dir:-/opt/spotify}"

if [[ ! -d "$spotify_dir" ]]; then
    log "Spotify directory not found: $spotify_dir"
    exit 1
fi

log "Preparing Spotify: $spotify_dir"
sudo chmod -R a+wr "$spotify_dir"
spicetify config spotify_path "$spotify_dir" >/dev/null

config_dir="$(spicetify config-dir 2>/dev/null)"
marketplace_dir="$config_dir/CustomApps/marketplace"

if [[ ! -d "$marketplace_dir" ]]; then
    log "Installing Marketplace..."
    curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh
fi

spicetify config custom_apps marketplace >/dev/null

if pgrep -x spotify >/dev/null 2>&1; then
    log "Spotify is already running; closing it before applying."
    pkill -x spotify || true
    for _ in {1..50}; do
        pgrep -x spotify >/dev/null 2>&1 || break
        sleep 0.1
    done
fi

log "Launching Spotify once to initialize client resources..."
spotify >/dev/null 2>&1 &
spotify_pid=$!

for _ in {1..100}; do
    if pgrep -x spotify >/dev/null 2>&1; then
        sleep 2
        break
    fi
    sleep 0.1
done

log "Stopping Spotify once before applying Spicetify..."
pkill -x spotify || true
for _ in {1..50}; do
    pgrep -x spotify >/dev/null 2>&1 || break
    sleep 0.1
done
wait "$spotify_pid" 2>/dev/null || true

log "Applying Spicetify..."
spicetify backup apply
spicetify config custom_apps | grep -qw marketplace
log "Spotify and Marketplace configured successfully."
