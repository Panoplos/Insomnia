#!/bin/bash
# Installs the built Insomnia.app to /Applications on this Mac.
# Run after copying Insomnia.app (and this script) to the target machine.
set -euo pipefail
cd "$(dirname "$0")"

[ -d Insomnia.app ] || { echo "Insomnia.app not found next to this script"; exit 1; }

pkill -x Insomnia 2>/dev/null || true
rm -rf /Applications/Insomnia.app
cp -R Insomnia.app /Applications/
xattr -cr /Applications/Insomnia.app   # clear quarantine from file transfer
open /Applications/Insomnia.app

echo "Installed. First toggle asks for the admin password once."
