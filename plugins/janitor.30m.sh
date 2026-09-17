#!/bin/zsh
# <xbar.title>Workbench Janitor</xbar.title>
# <xbar.version>v1.1</xbar.version>
# <xbar.author>hug</xbar.author>
# <xbar.author.github>dernerl</xbar.author.github>
# <xbar.desc>Zeigt den workbench-janitor-Report (Ordner-Status lokal/GitHub) in der Menüleiste.</xbar.desc>
# <xbar.dependencies>python3,git,gh</xbar.dependencies>
#
# Nur der Janitor, ohne Watchdog — Alternative zu combined.15m.sh. Führt bei jedem
# Refresh-Intervall (Dateiname-Suffix, hier 30m) einen echten `janitor.py`-Lauf aus
# (Tags werden angewendet) und rendert state.json als Dropdown. Dies ist der einzige
# "Scheduler" — kein launchd nötig, läuft solange SwiftBar läuft.

source "${0:A:h}/../lib/common.sh"

if ! have_janitor; then
    print "🧹 ⚠️"
    print -- "---"
    print "workbench-janitor nicht gefunden unter $JANITOR_DIR | color=gray"
    print "Pfad in config.sh setzen — siehe config.example.sh | color=gray"
    exit 0
fi

cd "$JANITOR_DIR" || exit 1
python3 janitor.py --no-notify >/dev/null 2>&1

python3 - "$JANITOR_DIR" << 'PYEOF'
import json
import sys
from pathlib import Path
from urllib.parse import quote

janitor_dir = Path(sys.argv[1])

try:
    state = json.loads((janitor_dir / "state.json").read_text(encoding="utf-8"))
except Exception as e:
    print("🧹 ⚠️")
    print("---")
    print(f"state.json nicht lesbar: {e}")
    sys.exit(0)

summary = state.get("summary", {})
projects = state.get("projects", [])
workbench = Path(state.get("workbench", ""))


def clean(s: str) -> str:
    return (s or "").replace("|", "-").replace('"', "'").replace("\n", " ")


def file_url(p: Path) -> str:
    return "file://" + quote(str(p))


CATS = [
    ("remote-gone",  "🔴 Remote fehlt auf GitHub"),
    ("synced-stale", "🟢 Löschbar (gesichert & ruhig)"),
    ("dirty",        "🟡 Ungesicherte Änderungen"),
    ("no-remote",    "🟠 Ohne GitHub-Remote"),
    ("local-stale",  "🔵 Nur lokal & alt"),
]

total = sum(summary.get(c, 0) for c, _ in CATS)
if summary.get("remote-gone", 0):
    badge_color = "color=red"
elif summary.get("dirty", 0):
    badge_color = "color=orange"
elif total:
    badge_color = "color=blue"
else:
    badge_color = ""

title = "🧹" if not total else f"🧹 {total}"
print(f"{title} | {badge_color}".strip())
print("---")

generated = state.get("generated", "")[:16].replace("T", " ")
print(f"Workbench Janitor — Stand {generated} | color=gray")
print(f"Workbench: {workbench} | color=gray")
print("---")

by_cat: dict[str, list[dict]] = {}
for p in projects:
    by_cat.setdefault(p.get("category", ""), []).append(p)

for cat, label in CATS:
    items = sorted(by_cat.get(cat, []), key=lambda x: -x.get("age_days", 0))
    if not items:
        continue
    print(f"{label} ({len(items)})")
    for p in items:
        name = p["name"]
        path = workbench / name
        rec = clean(p.get("recommendation", ""))
        print(f"--{clean(name)} — {rec} | href={file_url(path)}")
    print("---")

with_branches = [p for p in projects if p.get("branches_prunable")]
if with_branches:
    total_b = sum(len(p["branches_prunable"]) for p in with_branches)
    print(f"🌿 Branches löschbar ({total_b} in {len(with_branches)} Repos)")
    for p in sorted(with_branches, key=lambda x: -len(x["branches_prunable"])):
        branches = ", ".join(p["branches_prunable"])
        print(f"--{clean(p['name'])}: {clean(branches)} | href={file_url(workbench / p['name'])}")
    print("---")

print(f"Report öffnen | href={file_url(janitor_dir / 'reports' / 'latest.md')}")
print(f"Workbench öffnen | href={file_url(workbench)}")
print(f"🖥️ Dashboard öffnen | bash={janitor_dir / 'dashboard.sh'} param1=open terminal=false")
print("Jetzt aktualisieren | refresh=true")
PYEOF
