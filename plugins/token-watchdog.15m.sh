#!/bin/zsh
# <xbar.title>Azure Token Watchdog</xbar.title>
# <xbar.version>v0.3</xbar.version>
# <xbar.author>hug</xbar.author>
# <xbar.author.github>dernerl</xbar.author.github>
# <xbar.desc>Zeigt den Live-Gesundheitszustand des lokalen az-CLI-Token-Caches in der Menüleiste.</xbar.desc>
# <xbar.dependencies>python3,az</xbar.dependencies>
#
# Nur der Watchdog, ohne Janitor — Alternative zu combined.15m.sh. Führt bei
# jedem Refresh einen echten token_watchdog.py-Lauf aus (fordert pro Identität/
# Tenant ARM- und Graph-Tokens an, ~10s) und rendert dessen state.json.

source "${0:A:h}/../lib/common.sh"

if ! have_watchdog; then
    print "🔑 ⚠️"
    print -- "---"
    print "azure-token-watchdog nicht gefunden unter $WATCHDOG_DIR | color=gray"
    print "Pfad in config.sh setzen — siehe config.example.sh | color=gray"
    exit 0
fi

cd "$WATCHDOG_DIR" || exit 1
python3 token_watchdog.py >/dev/null 2>&1

python3 - "$WATCHDOG_DIR" << 'PYEOF'
import json
import sys
from pathlib import Path
from urllib.parse import quote

watchdog_dir = Path(sys.argv[1])

try:
    state = json.loads((watchdog_dir / "state.json").read_text(encoding="utf-8"))
except Exception as e:
    print("🔑 ⚠️")
    print("---")
    print(f"state.json nicht lesbar: {e}")
    sys.exit(0)


def clean(s: str) -> str:
    return (s or "").replace("|", "-").replace('"', "'").replace("\n", " ")


def file_url(p: Path) -> str:
    return "file://" + quote(str(p))


SEVERITY_COLOR = {"red": "color=red", "orange": "color=orange", "green": ""}
STATUS_MARK = {"dead": "🔴", "partial": "🟠", "ok": "🟢", "no-subscription-context": "⚪"}
STATUS_LABEL = {
    "dead": "kein ARM-Token mehr — az login nötig",
    "partial": "einzelne ARM-/Graph-Tokens fehlen",
    "ok": "ARM- und Graph-Tokens in allen Tenants",
    "no-subscription-context": "kein Subscription-Kontext gecacht",
}

severity = state.get("severity", "green")
badge = {"red": "🔑 !", "orange": "🔑 ?"}.get(severity, "🔑")
print(f"{badge} | {SEVERITY_COLOR.get(severity, '')}".strip())
print("---")

generated = state.get("generated", "")[:16].replace("T", " ")
print(f"Azure Token Watchdog — Stand {generated} | color=gray")
print("---")

ds = state.get("default_subscription")
if state.get("no_default_set"):
    print("🟠 Keine Default Subscription gesetzt")
    print("--az account set --subscription <name> | color=gray")
elif ds:
    mark = "🔴" if ds.get("dead") else "🟢"
    print(f"{mark} Default: {clean(ds.get('name'))} ({clean(ds.get('user'))})")
    if ds.get("dead"):
        print(f"--{clean(', '.join(ds.get('error') or []))} | color=gray")
    elif ds.get("expires_on"):
        print(f"--ARM-Token gültig bis {clean(str(ds['expires_on'])[:16])} | color=gray")
print("---")

SEVERITY_MARK = {"red": "🔴", "orange": "🟠", "green": "🟢"}
contexts = state.get("contexts", [])
print("📁 Projekt-Kontexte (isoliert)")
if not contexts:
    print("--(keine gefunden unter ~/.azure-contexts/) | color=gray")
for ctx in contexts:
    mark = SEVERITY_MARK.get(ctx["severity"], "⚪")
    label = ctx.get("project_root") or ctx["name"]
    print(f"--{mark} {clean(label)}")
    cds = ctx.get("default_subscription")
    if ctx.get("no_default_set"):
        print("----Keine Default Subscription gesetzt | color=gray")
    elif cds:
        cmark = "🔴" if cds.get("dead") else "🟢"
        status = "tot: " + ", ".join(cds.get("error") or []) if cds.get("dead") else "lebt"
        print(f"----{cmark} Default: {clean(cds.get('name'))} ({clean(status)}) | color=gray")
    if ctx.get("project_root"):
        print(f"----Projekt öffnen | href={file_url(Path(ctx['project_root']))}")
print("---")

concurrent = state.get("concurrent_az_processes") or []
if concurrent:
    print(f"⚠️ {len(concurrent)} laufende az/azd-Prozess(e) — Race-Risiko")
    for p in concurrent:
        print(f"--{clean(p)} | color=gray")
    print("---")

print("Identitäten im Cache")
for ident in state.get("identities", []):
    mark = STATUS_MARK.get(ident["status"], "⚪")
    label = STATUS_LABEL.get(ident["status"], "")
    print(f"--{mark} {clean(ident['username'])} — {label}")
    for t in ident.get("tenants", []):
        for resource in ("arm", "graph"):
            probe = t.get(resource) or {}
            if not probe.get("ok", True):
                print(f"----{clean(t.get('tenant'))} {resource.upper()}: {clean(', '.join(probe.get('error') or []))} | color=gray")
print("---")

print(f"Report öffnen | href={file_url(watchdog_dir / 'reports' / 'latest.md')}")
print(f"~/.azure öffnen | href={file_url(Path.home() / '.azure')}")
print("Jetzt aktualisieren | refresh=true")
PYEOF
