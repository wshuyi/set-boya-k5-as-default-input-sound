#!/bin/bash
set -euo pipefail
if [[ $# -gt 0 && "${1:-}" != "--yes" ]]; then echo "Usage: install.sh [--yes]" >&2; exit 2; fi
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
label="com.user.auto-switch-audio"
entry="$HOME/.local/bin/auto-switch-audio"
runtime="$HOME/.local/share/auto-switch-audio"
cache="$HOME/Library/Caches/auto-switch-audio"
plist="$HOME/Library/LaunchAgents/$label.plist"
logs="$HOME/Library/Logs/auto-switch-audio"
domain="gui/$(id -u)"
mkdir -p "$cache" "$logs" "$runtime" "$(dirname "$entry")" "$(dirname "$plist")"
stage="$(mktemp -d "$cache/install.XXXXXX")"
# Compile and validate BEFORE touching the live service or deployed source.
/usr/bin/xcrun swiftc -O "$project_dir/auto-switch-audio.swift" -o "$stage/auto-switch-audio-daemon"
"$stage/auto-switch-audio-daemon" --self-test
# Use plutil to avoid XML path escaping problems.
/usr/bin/plutil -create xml1 "$stage/agent.plist"
/usr/bin/plutil -insert Label -string "$label" "$stage/agent.plist"
/usr/bin/plutil -insert ProgramArguments -json "[]" "$stage/agent.plist"
/usr/bin/plutil -insert ProgramArguments.0 -string "$entry" "$stage/agent.plist"
/usr/bin/plutil -insert RunAtLoad -bool YES "$stage/agent.plist"
/usr/bin/plutil -insert KeepAlive -bool YES "$stage/agent.plist"
/usr/bin/plutil -insert ThrottleInterval -integer 10 "$stage/agent.plist"
/usr/bin/plutil -insert StandardOutPath -string "$logs/stdout.log" "$stage/agent.plist"
/usr/bin/plutil -insert StandardErrorPath -string "$logs/stderr.log" "$stage/agent.plist"
/usr/bin/plutil -lint "$stage/agent.plist"
backup="$cache/backup-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$backup"
[[ ! -f "$plist" ]] || cp -p "$plist" "$backup/agent.plist"
[[ ! -f "$entry" ]] || cp -p "$entry" "$backup/entry"
[[ ! -f "$runtime/auto-switch-audio.swift" ]] || cp -p "$runtime/auto-switch-audio.swift" "$backup/source.swift"
[[ ! -f "$cache/auto-switch-audio-daemon" ]] || cp -p "$cache/auto-switch-audio-daemon" "$backup/binary"
# Migrating the old in-repository shell: its live process still contains the old
# loop, but the repository entry now contains the new wrapper. Preserve the
# committed legacy loop as a separate rollback executable before stopping it.
if [[ -f "$backup/agent.plist" ]]; then
  old_program="$(/usr/libexec/PlistBuddy -c 'Print :ProgramArguments:0' "$backup/agent.plist" 2>/dev/null || true)"
  if [[ "$old_program" == "$project_dir/auto-switch-audio.sh" && ! -f "$backup/source.swift" ]]; then
    git -C "$project_dir" show HEAD:auto-switch-audio.sh > "$backup/legacy-loop.sh"
    if ! /usr/bin/grep -q 'CHECK_INTERVAL=' "$backup/legacy-loop.sh"; then
      echo "Cannot verify the legacy rollback loop; service left running." >&2; exit 1
    fi
    chmod 755 "$backup/legacy-loop.sh"
    /usr/bin/plutil -replace ProgramArguments.0 -string "$backup/legacy-loop.sh" "$backup/agent.plist"
  fi
fi
rollback() {
  echo "Install failed; restoring previous files/service from $backup" >&2
  launchctl bootout "$domain/$label" 2>/dev/null || true
  if [[ -f "$backup/entry" ]]; then cp -p "$backup/entry" "$entry"; else rm -f "$entry"; fi
  if [[ -f "$backup/source.swift" ]]; then cp -p "$backup/source.swift" "$runtime/auto-switch-audio.swift"; else rm -f "$runtime/auto-switch-audio.swift"; fi
  if [[ -f "$backup/binary" ]]; then cp -p "$backup/binary" "$cache/auto-switch-audio-daemon"; else rm -f "$cache/auto-switch-audio-daemon"; fi
  if [[ -f "$backup/agent.plist" ]]; then cp -p "$backup/agent.plist" "$plist"; launchctl bootstrap "$domain" "$plist" || true; else rm -f "$plist"; fi
}
trap 'rollback' ERR
launchctl bootout "$domain/$label" 2>/dev/null || true
cp "$project_dir/auto-switch-audio.swift" "$runtime/auto-switch-audio.swift"
cp "$project_dir/auto-switch-audio.sh" "$entry"
chmod 755 "$entry"
mv -f "$stage/auto-switch-audio-daemon" "$cache/auto-switch-audio-daemon"
# Ensure cache timestamp reflects the installed source version.
touch "$cache/auto-switch-audio-daemon"
cp "$stage/agent.plist" "$plist"
launchctl bootstrap "$domain" "$plist"
launchctl kickstart "$domain/$label"
sleep 2
launchctl print "$domain/$label" >/dev/null
trap - ERR
rm -rf "$stage"
echo "Installed $entry; rollback files: $backup"
echo "Check actual microphone access: $entry --status"
echo "Logs: $logs/stdout.log and $logs/stderr.log"
echo "Hardware mute ALSO falls back after 8 seconds of exact zeros. This is audio readiness, not power detection."
