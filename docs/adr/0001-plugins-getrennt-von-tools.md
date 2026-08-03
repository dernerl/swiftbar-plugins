# 1. SwiftBar-Plugins getrennt von den Tools

Datum: 2026-08-03

## Status

Akzeptiert

## Kontext

`workbench-janitor` und `azure-token-watchdog` sind eigenständige CLI-Tools, die je
eine `state.json` schreiben. Für die Menüleiste kam eine SwiftBar-Schicht dazu, die
zunächst organisch gewachsen ist:

- SwiftBars Plugin-Ordner zeigte direkt auf `workbench-janitor/swiftbar/`, also in
  ein Git-Working-Tree.
- Das kombinierte Plugin lag physisch im Watchdog-Ordner, wurde aber von dort in
  das Janitor-Repo symlinkt und hatte den Janitor-Pfad hartkodiert.
- Der Watchdog selbst lag in einer als wegwerfbar deklarierten Sandbox.

Daraus folgten drei konkrete Probleme:

1. **Kein Repo war eigenständig.** Der Janitor brauchte eine Datei aus dem
   Watchdog-Ordner, der Watchdog kannte den Janitor-Pfad.
2. **Jede Datei im Plugin-Ordner wurde zum Menüleisten-Icon.** Ein deaktiviertes
   Plugin `janitor.30m.sh.disabled` lief weiter und erzeugte ein zweites Icon —
   `.disabled` ist eine xbar-Konvention, die SwiftBar nicht kennt. SwiftBar führt
   jede ausführbare Datei in seinem Plugin-Ordner aus.
3. **Die Tools waren nicht ohne SwiftBar denkbar**, obwohl sie es fachlich sind.

## Entscheidung

Die Darstellungsschicht wird in ein eigenes Repo `swiftbar-plugins` getrennt.

- **Tool-Repos** enthalten keinen SwiftBar-Code. Ihr Vertrag nach außen ist die
  `state.json`, die sie neben ihren Entry-Point schreiben.
- **Dieses Repo** enthält ausschließlich Plugins, die solche `state.json` lesen.
  Die Tools werden über `JANITOR_DIR` / `WATCHDOG_DIR` gefunden (Env vor
  `config.sh` vor Default unter `~/projects`).
- **Fehlt ein Tool**, entfällt sein Abschnitt statt das Plugin scheitern zu lassen.
- **SwiftBar zeigt nie in ein Repo**, sondern auf `~/.swiftbar-plugins/` mit
  Symlinks auf genau die gewünschten Plugins. `install.sh` richtet das ein.

## Konsequenzen

Beide Tools laufen und sind installierbar ohne dieses Repo; dieses Repo läuft mit
beliebiger Teilmenge der Tools. Ein zusätzliches Hilfsskript im Repo kann kein
Icon mehr erzeugen, weil der Plugin-Ordner nur Symlinks enthält.

Der Preis: ein drittes Repo, und eine Pfad-Konfiguration, die es vorher nicht
brauchte. Bei einem Umzug eines Tool-Ordners muss `config.sh` nachgezogen werden —
vorher hätte ein hartkodierter Pfad im Plugin gebrochen, was ebenfalls Handarbeit
gewesen wäre, aber ohne vorgesehenen Ort dafür.

`lib/` liegt bewusst außerhalb von `plugins/`, damit ein künftiges direktes
Verlinken des Ordners nicht dieselbe Falle wie Punkt 2 aufreißt.
