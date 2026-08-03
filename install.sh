#!/bin/zsh
# Aktiviert ausgewählte Plugins, ohne SwiftBar auf ein Git-Working-Tree zeigen zu lassen.
#
#   ./install.sh                      # nur combined (Default)
#   ./install.sh janitor token-watchdog
#   ./install.sh --list
#
# SwiftBar führt JEDE ausführbare Datei in seinem Plugin-Ordner aus — auch eine
# mit .disabled-Endung (das ist eine xbar-Konvention, keine von SwiftBar). Zeigt
# der Plugin-Ordner direkt ins Repo, wird darum jede Hilfsdatei zum Menüleisten-
# Icon. Deshalb ein neutraler Ordner mit Symlinks auf genau die gewünschten Plugins.
set -e

REPO="${0:A:h}"
TARGET="$HOME/.swiftbar-plugins"

available() { print -l "$REPO"/plugins/*.sh(:t) }

if [[ "$1" == "--list" ]]; then
    print "Verfügbare Plugins:"
    for f in $(available); do print "  ${f%%.*}  ($f)"; done
    exit 0
fi

selected=("${@:-combined}")

mkdir -p "$TARGET"

# Alte Symlinks dieses Repos entfernen, fremde Dateien nicht anfassen.
for link in "$TARGET"/*(N@); do
    [[ "${link:A}" == "$REPO"/* ]] && rm "$link"
done

for name in $selected; do
    match=("$REPO"/plugins/${name}.*.sh(N))
    if (( ${#match} == 0 )); then
        print -u2 "Kein Plugin für '$name' — verfügbar: $(available | sed 's/\..*//' | tr '\n' ' ')"
        exit 1
    fi
    ln -sf "${match[1]}" "$TARGET/${match[1]:t}"
    print "aktiviert: ${match[1]:t}"
done

defaults write com.ameba.SwiftBar PluginDirectory "$TARGET"

if pgrep -qx SwiftBar; then
    osascript -e 'quit app "SwiftBar"' && sleep 2
fi
open -a SwiftBar

print "\nPlugin-Ordner: $TARGET"
print "SwiftBar neu gestartet."
