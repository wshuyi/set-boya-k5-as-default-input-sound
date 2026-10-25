#!/bin/bash
set -euo pipefail
label="com.user.auto-switch-audio"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$label.plist"
rm -f "$HOME/.local/bin/auto-switch-audio"
rm -f "$HOME/.local/share/auto-switch-audio/auto-switch-audio.swift"
rm -f "$HOME/Library/Caches/auto-switch-audio/auto-switch-audio-daemon"
echo "Service stopped and installed entry/source removed. Logs, last status and rollback backups were retained."
