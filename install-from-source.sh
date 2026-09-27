#!/bin/bash
# One-shot installer for new users: clone, build, install.
# Usage: curl -fsSL https://raw.githubusercontent.com/Panoplos/Insomnia/main/install-from-source.sh | bash
set -euo pipefail

REPO=https://github.com/Panoplos/Insomnia.git

if ! xcode-select -p >/dev/null 2>&1; then
    echo "Xcode Command Line Tools not found. Run:  xcode-select --install"
    echo "...then re-run this script."
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 "$REPO" "$TMP/Insomnia"
cd "$TMP/Insomnia"
./build.sh
./install.sh
