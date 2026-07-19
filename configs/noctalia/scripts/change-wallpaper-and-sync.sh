#!/usr/bin/env bash
set -uo pipefail
qs -c noctalia-shell ipc call wallpaper toggle
sleep 0.2
"$HOME/.config/noctalia/scripts/sync-sddm-theme.sh"
