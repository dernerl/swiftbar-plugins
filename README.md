# swiftbar-plugins

Menüleisten-Plugins für [SwiftBar](https://github.com/swiftbar/SwiftBar), die den
Zustand meiner lokalen Werkzeuge anzeigen.

Dieses Repo enthält **nur die Darstellungsschicht**. Die eigentliche Logik liegt in
den Tool-Repos, die jeweils eine `state.json` schreiben:

| Plugin | Liest | Tool-Repo |
|---|---|---|
| `combined.15m.sh` | beide | — |
| `janitor.30m.sh` | `$JANITOR_DIR/state.json` | [workbench-janitor](https://github.com/dernerl/workbench-janitor) |
| `token-watchdog.15m.sh` | `$WATCHDOG_DIR/state.json` | [azure-token-watchdog](https://github.com/dernerl/azure-token-watchdog) |

Die Trennung ist Absicht: Die Tools laufen eigenständig auf der Kommandozeile und
wissen nichts von SwiftBar. Umgekehrt sind die Tools hier optional — fehlt eines,
entfällt sein Abschnitt und der Rest funktioniert weiter.

## Installation

```sh
git clone https://github.com/dernerl/swiftbar-plugins.git
cd swiftbar-plugins
./install.sh                        # nur combined (ein Icon für beides)
./install.sh janitor token-watchdog # oder zwei getrennte Icons
./install.sh --list                 # zeigt alle Plugins
```

`install.sh` legt `~/.swiftbar-plugins/` an, verlinkt die gewählten Plugins dorthin,
setzt SwiftBars Plugin-Ordner darauf und startet SwiftBar neu.

### Warum ein eigener Plugin-Ordner?

SwiftBar führt **jede ausführbare Datei** in seinem Plugin-Ordner aus. Eine Endung
wie `.disabled` hilft nicht — das ist eine xbar-Konvention, die SwiftBar nicht kennt.
Zeigt der Plugin-Ordner direkt in ein Repo, wird darum jedes Hilfsskript ungewollt
zum Menüleisten-Icon. `~/.swiftbar-plugins/` enthält nur Symlinks auf genau die
Plugins, die laufen sollen.

## Konfiguration

Standardmäßig werden die Tools unter `~/projects/` gesucht. Liegen sie woanders:

```sh
cp config.example.sh config.sh   # config.sh ist gitignored
```

```sh
JANITOR_DIR="$HOME/code/workbench-janitor"
WATCHDOG_DIR="$HOME/code/azure-token-watchdog"
```

## Aufbau

```
plugins/          von SwiftBar ausgeführt, Dateiname bestimmt das Intervall
lib/common.sh     Pfad-Auflösung, gesourcet — liegt bewusst NICHT in plugins/
config.example.sh Vorlage für config.sh
install.sh        Symlinks setzen, SwiftBar umkonfigurieren und neu starten
```

Ein Plugin macht zwei Dinge: den Check des Tools ausführen (SwiftBars
Refresh-Intervall ist der einzige Scheduler, kein launchd nötig) und dessen
`state.json` als Dropdown rendern.

## Lizenz

MIT
