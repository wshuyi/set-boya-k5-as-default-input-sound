# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS utility that automatically sets preferred microphones as the default audio input device when connected. Supports multiple devices with priority order: K5 RX > DJI MIC MINI > MacBook Pro Microphone (lid open only). Uses a LaunchAgent to run a background service that polls for device changes every 2 seconds.

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
  - Switches to highest priority available device (K5 RX > DJI MIC MINI)
  - Falls back to MacBook Pro Microphone when lid is open and no external mics connected
  - Uses `ioreg` to detect clamshell (closed lid) state

- `uninstall.sh` - Removes LaunchAgent plist and cleans up logs

## Key Configuration

Device priority list is defined in `DEVICE_NAMES` array in both `install.sh` (line 18) and `auto-switch-audio.sh` (line 7):
```bash
DEVICE_NAMES=("K5 RX" "DJI MIC MINI")
```
First matching device in the array is selected. Add/remove/reorder devices as needed.

SwitchAudioSource path is hardcoded to `/opt/homebrew/bin/SwitchAudioSource` (Apple Silicon path).
