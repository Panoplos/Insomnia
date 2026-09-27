#!/bin/bash
# Builds Insomnia.app in the project directory.
set -euo pipefail
cd "$(dirname "$0")"

APP=Insomnia.app
mkdir -p "$APP/Contents/MacOS"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Insomnia</string>
    <key>CFBundleIdentifier</key><string>local.makoto.Insomnia</string>
    <key>CFBundleName</key><string>Insomnia</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
</dict>
</plist>
EOF

# Pin minimum macOS to 12.0 — otherwise swiftc sets min OS to the local SDK
# version and the app won't launch on older Macs (LSOpen error -10825).
swiftc -O -target "$(uname -m)-apple-macos12.0" -o "$APP/Contents/MacOS/Insomnia" main.swift
codesign --force --sign - "$APP"

# Self-check the state parser against the real pmset output.
"$APP/Contents/MacOS/Insomnia" --check

echo "Built $APP — open it to get the menu bar moon."
