#!/bin/zsh
# Kopiere diese Datei nach config.sh, wenn deine Tool-Repos woanders liegen
# als unter ~/projects. config.sh ist gitignored.
#
#   cp config.example.sh config.sh

# := statt = , damit eine bereits gesetzte Umgebungsvariable Vorrang behält.
: ${JANITOR_DIR:="$HOME/projects/workbench-janitor"}
: ${WATCHDOG_DIR:="$HOME/projects/azure-token-watchdog"}
: ${RADAR_DIR:="$HOME/projects/localhost-radar"}
