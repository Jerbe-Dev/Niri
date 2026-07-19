#!/usr/bin/env bash
set -euo pipefail

COLORS="$HOME/.config/noctalia/colors.json"
OUT="/tmp/niri-regreet-theme"

[ -f "$COLORS" ] || exit 0

mkdir -p "$OUT"

python - "$COLORS" "$OUT" <<'PYTHON'
import json
import sys
from pathlib import Path

src = Path(sys.argv[1])
out = Path(sys.argv[2])
data = json.loads(src.read_text())

def color(name, default):
    value = data.get(name, default)
    return value if isinstance(value, str) else default

primary = color("mPrimary", "#6750A4")
surface = color("mSurface", "#1C1B1F")
text = color("mOnSurface", "#E6E1E5")
on_primary = color("mOnPrimary", "#FFFFFF")

(out / "colors.env").write_text(
    f"PRIMARY={primary}\n"
    f"SURFACE={surface}\n"
    f"TEXT={text}\n"
    f"ON_PRIMARY={on_primary}\n"
)

(out / "regreet.css").write_text(f"""window {{
    background-color: {surface};
    color: {text};
}}

entry {{
    background-color: {surface};
    color: {text};
    border-color: {primary};
}}

button {{
    background-color: {primary};
    color: {on_primary};
}}

button:hover {{
    background-color: {on_primary};
    color: {primary};
}}
""")
PYTHON

if command -v sudo >/dev/null 2>&1 && [ -d /etc/greetd ]; then
    sudo install -Dm644 "$OUT/regreet.css" /etc/greetd/regreet.css

    cat > "$OUT/regreet.toml" <<EOF
[GTK]
application_prefer_dark_theme = true
cursor_theme_name = "Bibata-Modern-Classic"

[stylesheet]
path = "/etc/greetd/regreet.css"

[commands]
reboot = ["systemctl", "reboot"]
poweroff = ["systemctl", "poweroff"]
EOF

    sudo install -Dm644 "$OUT/regreet.toml" /etc/greetd/regreet.toml
fi
