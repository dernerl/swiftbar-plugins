#!/bin/zsh
# <xbar.title>Workbench (Janitor + Token Watchdog)</xbar.title>
# <xbar.version>v0.2</xbar.version>
# <xbar.author>hug</xbar.author>
# <xbar.author.github>dernerl</xbar.author.github>
# <xbar.desc>Ein Menüleisten-Icon für workbench-janitor und azure-token-watchdog.</xbar.desc>
# <xbar.dependencies>python3,git,gh,az</xbar.dependencies>
#
# Fasst beide Tools zu EINEM Icon mit zwei Abschnitten zusammen. Führt bei jedem
# Refresh-Intervall die zugrundeliegenden Checks aus und rendert deren state.json.
# Fehlt eines der Tools, entfällt sein Abschnitt — das Plugin bleibt nutzbar.

source "${0:A:h}/../lib/common.sh"

have_watchdog && ( cd "$WATCHDOG_DIR" && python3 token_watchdog.py >/dev/null 2>&1 )
have_janitor  && ( cd "$JANITOR_DIR"  && python3 janitor.py --no-notify >/dev/null 2>&1 )

python3 - "$(watchdog_arg)" "$(janitor_arg)" << 'PYEOF'
import json
import sys
from pathlib import Path
from urllib.parse import quote

watchdog_dir = Path(sys.argv[1]) if sys.argv[1] else None
janitor_dir = Path(sys.argv[2]) if sys.argv[2] else None

if watchdog_dir is None and janitor_dir is None:
    print("| sfimage=key.fill sfcolor=red")
    print("---")
    print("Kein Tool gefunden | color=gray")
    print("Pfade in config.sh setzen — siehe config.example.sh | color=gray")
    sys.exit(0)


def clean(s: str) -> str:
    return (s or "").replace("|", "-").replace('"', "'").replace("\n", " ")


def file_url(p: Path) -> str:
    return "file://" + quote(str(p))


def load(path):
    try:
        return json.loads(path.read_text(encoding="utf-8")), None
    except Exception as e:
        return None, str(e)


watchdog_state, watchdog_err = load(watchdog_dir / "state.json") if watchdog_dir else (None, None)
janitor_state, janitor_err = load(janitor_dir / "state.json") if janitor_dir else (None, None)

# --- combined severity for the single icon ---
SEV_RANK = {"green": 0, None: 0, "blue": 1, "orange": 2, "red": 3}
watchdog_sev = watchdog_state.get("severity") if watchdog_state else None

janitor_summary = (janitor_state or {}).get("summary", {})
if janitor_state is None:
    janitor_sev = None
elif janitor_summary.get("remote-gone"):
    janitor_sev = "red"
elif janitor_summary.get("dirty"):
    janitor_sev = "orange"
elif sum(janitor_summary.values()):
    janitor_sev = "blue"
else:
    janitor_sev = "green"

worst = max([watchdog_sev, janitor_sev], key=lambda s: SEV_RANK.get(s, 0))

# total open items across both tools, for the small numeric badge
watchdog_issues = 0
if watchdog_state:
    watchdog_issues += 1 if watchdog_state.get("no_default_set") else 0
    ds = watchdog_state.get("default_subscription")
    watchdog_issues += 1 if (ds and ds.get("dead")) else 0
    watchdog_issues += 1 if watchdog_state.get("drift") else 0
    watchdog_issues += sum(
        1 for i in watchdog_state.get("identities", []) if i["status"] in ("dead", "partial")
    )
    for ctx in watchdog_state.get("contexts", []):
        watchdog_issues += 1 if ctx.get("no_default_set") else 0
        cds = ctx.get("default_subscription")
        watchdog_issues += 1 if (cds and cds.get("dead")) else 0
        watchdog_issues += 1 if ctx.get("drift") else 0
janitor_issues = sum(janitor_summary.values()) if janitor_summary else 0
total = watchdog_issues + janitor_issues

# Native SF Symbol look: monochrome template icon, only tinted when something
# needs attention (matches the plain shield/gear/arrow icons in the menu bar
# rather than a colorful emoji badge).
SF_COLOR = {"red": "sfcolor=red", "orange": "sfcolor=orange"}
sf_color = SF_COLOR.get(worst, "")
title = f" {total}" if total else ""
print(f"{title} | sfimage=key.fill {sf_color}".strip())
print("---")

# --- Section 1: Workbench Janitor ---
if janitor_dir is not None:
    print("🧹 Workbench Janitor | color=gray")
    if janitor_err:
        print(f"--state.json nicht lesbar: {clean(janitor_err)}")
        print("--Einmal `python3 janitor.py` laufen lassen | color=gray")
    else:
        workbench = Path(janitor_state.get("workbench", ""))
        generated = janitor_state.get("generated", "")[:16].replace("T", " ")
        print(f"--Workbench Janitor — Stand {generated} | color=gray")
        print(f"--Workbench: {clean(str(workbench))} | color=gray")
        projects = janitor_state.get("projects", [])
        CATS = [
            ("remote-gone",  "🔴 Remote fehlt auf GitHub"),
            ("synced-stale", "🟢 Löschbar (gesichert & ruhig)"),
            ("dirty",        "🟡 Ungesicherte Änderungen"),
            ("no-remote",    "🟠 Ohne GitHub-Remote"),
            ("local-stale",  "🔵 Nur lokal & alt"),
        ]
        by_cat = {}
        for p in projects:
            by_cat.setdefault(p.get("category", ""), []).append(p)
        for cat, label in CATS:
            items = sorted(by_cat.get(cat, []), key=lambda x: -x.get("age_days", 0))
            if not items:
                continue
            print(f"--{label} ({len(items)})")
            for p in items:
                name = p["name"]
                path = workbench / name
                rec = clean(p.get("recommendation", ""))
                print(f"----{clean(name)} — {rec} | href={file_url(path)}")
        with_branches = [p for p in projects if p.get("branches_prunable")]
        if with_branches:
            total_b = sum(len(p["branches_prunable"]) for p in with_branches)
            print(f"--🌿 Branches löschbar ({total_b} in {len(with_branches)} Repos)")
            for p in sorted(with_branches, key=lambda x: -len(x["branches_prunable"])):
                branches = ", ".join(p["branches_prunable"])
                print(f"----{clean(p['name'])}: {clean(branches)} | href={file_url(workbench / p['name'])}")
        print(f"--Report öffnen | href={file_url(janitor_dir / 'reports' / 'latest.md')}")
        print(f"--Workbench öffnen | href={file_url(workbench)}")
    print("---")

# --- Section 2: Azure Token Watchdog ---
if watchdog_dir is not None:
    print("🔑 Azure Token Watchdog | color=gray")
    if watchdog_err:
        print(f"--state.json nicht lesbar: {clean(watchdog_err)}")
        print("--Einmal `python3 token_watchdog.py` laufen lassen | color=gray")
    else:
        if watchdog_state.get("no_default_set"):
            print("--🟠 Keine Default Subscription gesetzt")
        ds = watchdog_state.get("default_subscription")
        if ds:
            mark = "🔴" if ds.get("dead") else "🟢"
            print(f"--{mark} Default: {clean(ds.get('name'))} ({clean(ds.get('user'))})")
        STATUS_MARK = {"dead": "🔴", "partial": "🟠", "ok": "🟢", "no-subscription-context": "⚪"}
        for ident in watchdog_state.get("identities", []):
            mark = STATUS_MARK.get(ident["status"], "⚪")
            print(f"--{mark} {clean(ident['username'])}")
        SEVERITY_MARK = {"red": "🔴", "orange": "🟠", "green": "🟢"}
        contexts = watchdog_state.get("contexts", [])
        if contexts:
            print("--📁 Projekt-Kontexte (isoliert)")
            for ctx in contexts:
                mark = SEVERITY_MARK.get(ctx["severity"], "⚪")
                label = ctx.get("project_root") or ctx["name"]
                print(f"----{mark} {clean(label)}")
        print(f"--Report öffnen | href={file_url(watchdog_dir / 'reports' / 'latest.md')}")
    print("---")

print("Jetzt aktualisieren | refresh=true")
PYEOF
