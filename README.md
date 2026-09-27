# Insomnia 🌙

A tiny macOS menu bar app that toggles `pmset -a disablesleep` — keep your Mac
awake with the lid closed, with one click.

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![swift](https://img.shields.io/badge/Swift-5-orange)

## What it does

- 🌙 **moon.stars.fill** = sleep disabled (Mac stays awake, even with the lid closed)
- 💤 **moon.zzz** = sleep allowed (normal macOS behavior); dimmed while on battery
- State is re-read from `pmset -g` every time the menu opens, so it never lies

## Features

- **One-click toggle** (`⌘T`) — first use asks for the admin password once, then
  installs a narrowly-scoped sudoers rule (`/etc/sudoers.d/insomnia`) that allows
  exactly `pmset -a disablesleep 1` and `0` without a password. Every later
  toggle is instant and silent.
- **Auto-Sleep on Battery** (on by default) — when unplugged, sleep is
  automatically re-enabled so your Mac doesn't drain in a bag; back on AC,
  insomnia resumes. Uses IOKit power-source notifications.
- **Launch at Login** (`⌘L`) — via `SMAppService` (macOS 13+).
- No Dock icon, no window — pure menu bar (LSUIElement).

## Install (no release download needed)

Requires macOS 12+ and [Xcode Command Line Tools](https://developer.apple.com/download/all/)
(`xcode-select --install` if you don't have them).

```bash
curl -fsSL https://raw.githubusercontent.com/Panoplos/Insomnia/main/install-from-source.sh | bash
```

This clones the repo to a temp dir, builds `Insomnia.app`, installs it to
`/Applications`, and launches it. On first toggle you'll enter your password
once; after that everything is passwordless.

## Build manually

```bash
git clone https://github.com/Panoplos/Insomnia.git
cd Insomnia
./build.sh      # builds Insomnia.app and runs self-checks
./install.sh    # optional: installs to /Applications
```

## Uninstall

1. Menu: uncheck **Launch at Login**, then Quit
2. Remove the app: `rm -rf /Applications/Insomnia.app`
3. Remove the sudoers rule: `sudo rm /etc/sudoers.d/insomnia`
4. Reset preferences: `defaults delete local.makoto.Insomnia`

## How it works

- **Read:** `pmset -g` → parse the `SleepDisabled` line
- **Write:** `sudo -n pmset -a disablesleep 1|0` (passwordless via the sudoers
  rule; the rule is created through a one-time admin prompt and validated with
  `visudo` before it sticks)
- **Battery watch:** `IOPSNotificationCreateRunLoopSource` from IOKit

Note: `disablesleep` is a single system-wide switch — it cannot be scoped to
"AC only" via pmset, which is why the battery handling lives in the app.

## Project layout

```
main.swift                  # the entire app (~170 lines)
build.sh                    # builds Insomnia.app, runs self-checks
install.sh                  # installs the built app to /Applications
install-from-source.sh      # curl|bash bootstrap: clone + build + install
```
