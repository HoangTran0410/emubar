#!/bin/bash
# Builds EmuBar.app into ~/Applications and starts it at login (a LaunchAgent). Undo: ./build.sh uninstall
set -euo pipefail
cd "$(dirname "$0")"
APP="$HOME/Applications/EmuBar.app"
PLIST="$HOME/Library/LaunchAgents/dev.local.emubar.plist"
if [ "${1:-}" = uninstall ]; then
  launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
  rm -rf "$APP" "$PLIST"; echo "✓ EmuBar removed"; exit 0
fi
mkdir -p "$APP/Contents/MacOS" "$HOME/Library/LaunchAgents"
swiftc -O -o "$APP/Contents/MacOS/EmuBar" main.swift
cat > "$APP/Contents/Info.plist" <<'E'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.local.emubar</string>
<key>CFBundleName</key><string>EmuBar</string>
<key>CFBundleExecutable</key><string>EmuBar</string>
<key>LSUIElement</key><true/>
</dict></plist>
E
cat > "$PLIST" <<E
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>dev.local.emubar</string>
<key>ProgramArguments</key><array><string>$APP/Contents/MacOS/EmuBar</string></array>
<key>RunAtLoad</key><true/>
<key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
</dict></plist>
E
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "✓ EmuBar built and running ($APP); starts at login"
