# EmuBar

A macOS menu-bar icon that counts the Android emulators running on your Mac, **hidden ones included** (`-no-window` / `-headless`), and closes them from a dropdown.

Why: a headless emulator left running in the background can quietly burn 600%+ CPU for hours with no window to remind you.

```
📱 2 (2 hidden)
 ├ tvremote_gtv  · hidden · 14 min · 9% CPU   ▸ Close
 ├ tvremote_test · hidden · 13 min · 2% CPU   ▸ Close
 ├ Close all
 └ Quit EmuBar
```

- Refreshes every 5 s. CPU is measured between two refreshes, not averaged over the emulator's life.
- The icon turns red and you get one notification when an emulator has been hidden for 60 min or more, or uses 300% CPU or more.
- **Close** runs `adb -s <serial> emu kill`, which shuts the emulator down cleanly (no stale `.lock`, no "closed unexpectedly" dialog the next time it starts). If it is still running after 30 s, EmuBar sends SIGTERM.
- The menu is in Vietnamese. Edit the strings in `main.swift` if you want another language.

## Install

You need macOS (tested on macOS 26), the Xcode command line tools (`swiftc`), and the Android SDK's `adb` at `~/Library/Android/sdk/platform-tools/adb`.

```sh
./build.sh            # builds ~/Applications/EmuBar.app, starts it, starts at login (LaunchAgent)
./build.sh uninstall  # removes the app and the LaunchAgent
```

## From the terminal

```sh
~/Applications/EmuBar.app/Contents/MacOS/EmuBar --list          # what the menu would show
~/Applications/EmuBar.app/Contents/MacOS/EmuBar --close <avd>   # what the menu's Close does
```

MIT license.
