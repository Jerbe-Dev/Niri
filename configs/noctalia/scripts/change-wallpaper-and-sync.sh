#!/usr/bin/env bash
set -euo pipefail

# Change the wallpaper through Noctalia, then mirror the resolved wallpaper
# into the SDDM Sugar Candy cache used by the login screen.
qs -c noctalia-shell ipc call wallpaper toggle

# Give Noctalia a moment to commit the new wallpaper state before reading it.
sleep 0.2

"$HOME/.config/noctalia/scripts/sync-sddm-theme.sh"
