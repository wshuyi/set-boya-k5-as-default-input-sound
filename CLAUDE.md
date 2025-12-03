# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS utility that automatically sets the BOYA K5 microphone as the default audio input device when connected. Uses a LaunchAgent to run a background service that polls for device changes every 2 seconds.

## Commands

### Installation & Management
```bash
./install.sh      # Install and start the service
./uninstall.sh    # Stop and remove the service
```

### Service Control
```bash
launchctl list | grep auto-switch-audio                              # Check status
launchctl unload ~/Library/LaunchAgents/com.user.auto-switch-audio.plist  # Stop
launchctl load ~/Library/LaunchAgents/com.user.auto-switch-audio.plist    # Start
```

### Audio Device Inspection
```bash
SwitchAudioSource -a -t input    # List all input devices
SwitchAudioSource -t input -c    # Show current input device
```

### Logs
```bash
tail -f /tmp/auto-switch-audio.log  # Output log
tail -f /tmp/auto-switch-audio.err  # Error log
```

## Architecture

- `install.sh` - Installation script that:
  1. Checks/installs SwitchAudioSource via Homebrew
  2. Generates `auto-switch-audio.sh` with embedded device polling logic
  3. Creates LaunchAgent plist at `~/Library/LaunchAgents/`
  4. Loads and starts the service

- `auto-switch-audio.sh` - Background daemon that runs an infinite loop:
  - Polls device list every 2 seconds using SwitchAudioSource
  - Switches to "K5 RX" if connected and not already the default

- `uninstall.sh` - Removes LaunchAgent plist and cleans up logs

## Key Configuration

Device name is hardcoded as `"K5 RX"` in both `install.sh` (line 18) and the generated `auto-switch-audio.sh` (line 6). Modify `DEVICE_NAME` variable to support different devices.

SwitchAudioSource path is hardcoded to `/opt/homebrew/bin/SwitchAudioSource` (Apple Silicon path).
