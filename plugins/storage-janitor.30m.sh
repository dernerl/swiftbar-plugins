#!/bin/zsh
# <xbar.title>Storage Janitor</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>hug</xbar.author>
# <xbar.author.github>dernerl</xbar.author.github>
# <xbar.desc>Zeigt den storage-janitor-Report (Cache-Hygiene, Speicherplatz) in der Menüleiste.</xbar.desc>
# <xbar.dependencies>python3</xbar.dependencies>
#
# Führt bei jedem Refresh-Intervall (Dateiname-Suffix, hier 30m) einen echten
# `storage-janitor.py`-Lauf aus (Tier auto-safe wird angewendet) und rendert state.json
# als Dropdown. Dies ist der einzige "Scheduler" — kein launchd nötig, läuft solange
# SwiftBar läuft.

source "${0:A:h}/../lib/common.sh"

if ! have_storage_janitor; then
    print "🧺 ⚠️"
    print -- "---"
    print "storage-janitor nicht gefunden unter $STORAGE_JANITOR_DIR | color=gray"
    print "Pfad in config.sh setzen — siehe config.example.sh | color=gray"
    exit 0
fi

cd "$STORAGE_JANITOR_DIR" || exit 1
python3 storage-janitor.py --no-notify >/dev/null 2>&1

python3 - "$STORAGE_JANITOR_DIR" << 'PYEOF'
import json
import sys
from pathlib import Path
from urllib.parse import quote

tool_dir = Path(sys.argv[1])

try:
    state = json.loads((tool_dir / "state.json").read_text(encoding="utf-8"))
except Exception as e:
    print("🧺 ⚠️")
    print("---")
    print(f"state.json nicht lesbar: {e}")
    sys.exit(0)

summary = state.get("summary", {})
free_gb = state.get("disk_free_gb", 0)
warn_gb = state.get("warn_gb", 20)
critical_gb = state.get("critical_gb", 8)


def clean(s: str) -> str:
    return (s or "").replace("|", "-").replace('"', "'").replace("\n", " ")


def file_url(p: Path) -> str:
    return "file://" + quote(str(p))


orphans = summary.get("orphan_candidates", 0)
if free_gb <= critical_gb:
    badge_color = "color=red"
elif free_gb <= warn_gb or orphans:
    badge_color = "color=orange"
elif summary.get("trimmed", 0):
    badge_color = "color=blue"
else:
    badge_color = ""

title = "🧺" if not orphans else f"🧺 {orphans}"
print(f"{title} | {badge_color}".strip())
print("---")

generated = state.get("generated", "")[:16].replace("T", " ")
print(f"Storage Janitor — Stand {generated} | color=gray")
print(f"Frei: {free_gb:.1f} GB / {state.get('disk_total_gb', 0):.1f} GB | color=gray")
print("---")

if free_gb <= critical_gb:
    print(f"🔴 Speicherplatz kritisch ({free_gb:.1f} GB frei)")
    print("---")
elif free_gb <= warn_gb:
    print(f"🟡 Speicherplatz knapp ({free_gb:.1f} GB frei)")
    print("---")

trimmed = state.get("trimmed", [])
if trimmed:
    print(f"🧹 Auto-safe getrimmt ({len(trimmed)}, {summary.get('freed_mb', 0):.0f} MB)")
    for t in sorted(trimmed, key=lambda x: -x.get("freed_mb", 0)):
        print(f"--{clean(t['name'])} — {t.get('freed_mb', 0):.0f} MB frei")
    print("---")

skipped = state.get("skipped", [])
if skipped:
    print(f"⏭️ Übersprungen ({len(skipped)})")
    for s in skipped:
        print(f"--{clean(s['name'])} — {clean(s.get('reason', ''))}")
    print("---")

candidates = state.get("orphan_candidates", [])
if candidates:
    print(f"🟠 Verwaiste Kandidaten ({len(candidates)})")
    for c in sorted(candidates, key=lambda x: -x.get("size_mb", 0)):
        print(f"--{clean(c['name'])} ({c.get('size_mb', 0):.0f} MB) — {clean(c.get('reason', ''))}")
    print("---")

print(f"Report öffnen | href={file_url(tool_dir / 'reports' / 'latest.md')}")
print("Jetzt aktualisieren | refresh=true")
PYEOF
