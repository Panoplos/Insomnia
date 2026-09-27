#!/bin/bash
# Fully removes Insomnia: app, preferences, sudoers rule.
# Run from a clone of the repo, or anywhere — it only touches /Applications
# and per-user/global settings.
set -euo pipefail

pkill -x Insomnia 2>/dev/null || true

rm -rf /Applications/Insomnia.app
rm -rf ~/Downloads/Insomnia.app

# Preferences (auto-sleep toggle state, etc.)
defaults delete local.makoto.Insomnia 2>/dev/null || true

# The passwordless pmset rule needs root.
if sudo -n test -f /etc/sudoers.d/insomnia 2>/dev/null || [ -f /etc/sudoers.d/insomnia ]; then
    osascript -e 'do shell script "rm -f /etc/sudoers.d/insomnia" with administrator privileges with prompt "Insomnia uninstall: removing the passwordless pmset rule requires admin access."' \
        || echo "Could not remove /etc/sudoers.d/insomnia — delete it manually with: sudo rm /etc/sudoers.d/insomnia"
fi

# If "Launch at Login" was enabled, macOS may still list a dead "Insomnia"
# entry under System Settings > Login Items. It is inert once the bundle is
# gone; remove it there manually if you see it.

echo "Insomnia removed (app, preferences, sudoers rule)."
