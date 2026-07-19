#!/usr/bin/env bash
set -euo pipefail

COLORS="$HOME/.config/noctalia/colors.json"
OUT="/tmp/niri-regreet-theme"

[ -f "$COLORS" ] || exit 0

mkdir -p "$OUT"

python - "$COLORS" "$OUT" <<'PY'
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

(out / "colors.env").write_text(
    f"PRIMARY={primary}\n"
    f"SURFACE={surface}\n"
    f"TEXT={text}\n"
)
PY
