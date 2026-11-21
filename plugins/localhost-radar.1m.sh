#!/bin/zsh
# <xbar.title>localhost-radar</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>hug</xbar.author>
# <xbar.author.github>dernerl</xbar.author.github>
# <xbar.desc>Zeigt alle aktuell lauschenden localhost-Ports in der Menüleiste, mit Klick-zum-Öffnen.</xbar.desc>
# <xbar.dependencies>python3,lsof</xbar.dependencies>
#
# Eigenständig, nicht Teil von combined.15m.sh — Ports ändern sich schneller als
# Git-/Token-Status, darum 1 Minute statt 15/30. lsof ist billig genug dafür.
# Führt bei jedem Refresh einen echten localhost_radar.py-Lauf aus und rendert
# dessen state.json.

source "${0:A:h}/../lib/common.sh"

if ! have_radar; then
    print "| sfimage=network sfcolor=red"
    print -- "---"
    print "localhost-radar nicht gefunden unter $RADAR_DIR | color=gray"
    print "Pfad in config.sh setzen — siehe config.example.sh | color=gray"
    exit 0
fi

cd "$RADAR_DIR" || exit 1
python3 localhost_radar.py >/dev/null 2>&1

python3 - "$RADAR_DIR" << 'PYEOF'
import json
import sys
from pathlib import Path
from urllib.parse import quote

radar_dir = Path(sys.argv[1])

try:
    state = json.loads((radar_dir / "state.json").read_text(encoding="utf-8"))
except Exception as e:
    print("| sfimage=network sfcolor=red")
    print("---")
    print(f"state.json nicht lesbar: {e}")
    sys.exit(0)


def clean(s: str) -> str:
    return (s or "").replace("|", "-").replace('"', "'").replace("\n", " ")


def file_url(p: Path) -> str:
    return "file://" + quote(str(p))


# Nur lokale Web-Apps; Hintergrund-Sockets installierter Programme stehen im Report.
ports = [p for p in state.get("ports", []) if p.get("kind", "app") == "app"]
count = len(ports)
severity = state.get("severity", "green")
color = "sfcolor=orange" if severity == "orange" else ""
title = f" {count}" if count else ""
print(f"{title} | sfimage=network {color}".strip())
print("---")

generated = state.get("generated", "")[:16].replace("T", " ")
print(f"localhost-radar — Stand {generated} | color=gray")
print("---")

if not ports:
    print("Keine lokalen Apps aktiv | color=gray")
else:
    for p in ports:
        port = p["port"]
        project = p.get("project")
        command = clean(p.get("command", "?"))
        sym = "globe" if p.get("bind") == "exposed" else "house"
        label = clean(project) if project else command
        print(f"{label}  :{port} | href=http://localhost:{port} sfimage={sym}")
        if p.get("cwd") and p["cwd"] != "/":
            print(f"--Ordner öffnen | href={file_url(Path(p['cwd']))}")
        print(f"--PID {p['pid']} · User {clean(p.get('user') or '?')} | color=gray")
print("---")

print(f"Report öffnen | href={file_url(radar_dir / 'reports' / 'latest.md')}")
print("Jetzt aktualisieren | refresh=true")
PYEOF
