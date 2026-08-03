#!/bin/zsh
# Gemeinsame Pfad-Auflösung für alle Plugins in diesem Repo.
# Wird von den Plugins gesourcet und ist selbst kein Plugin — deshalb liegt
# die Datei außerhalb von plugins/, sonst würde SwiftBar sie auszuführen versuchen.

# SwiftBar erbt kein Login-Shell-Environment, PATH muss explizit gesetzt werden.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# ${(%):-%x} ist der Pfad DIESER Datei (nicht des aufrufenden Scripts),
# :A löst Symlinks auf — die Plugins werden aus ~/.swiftbar-plugins verlinkt.
SWIFTBAR_REPO="${${(%):-%x}:A:h:h}"

# Optionale lokale Überschreibung; ohne sie gelten die Defaults darunter.
[[ -f "$SWIFTBAR_REPO/config.sh" ]] && source "$SWIFTBAR_REPO/config.sh"

: ${JANITOR_DIR:="$HOME/projects/workbench-janitor"}
: ${WATCHDOG_DIR:="$HOME/projects/azure-token-watchdog"}

# Ein Tool gilt als vorhanden, wenn sein Entry-Point existiert. Die Plugins
# rendern nur Abschnitte für tatsächlich installierte Tools.
have_janitor()  { [[ -f "$JANITOR_DIR/janitor.py" ]] }
have_watchdog() { [[ -f "$WATCHDOG_DIR/token_watchdog.py" ]] }

# Gibt den Pfad aus, wenn das Tool da ist, sonst nichts — als Argument für die
# Render-Skripte, die einen leeren String als "nicht installiert" lesen.
janitor_arg()  { have_janitor  && print -r -- "$JANITOR_DIR" }
watchdog_arg() { have_watchdog && print -r -- "$WATCHDOG_DIR" }
