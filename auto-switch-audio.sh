#!/bin/bash
set -euo pipefail
# Stable installed entry point. The portable Swift source is managed; the executable is a per-Mac cache.
source_file="$HOME/.local/share/auto-switch-audio/auto-switch-audio.swift"
cache_dir="$HOME/Library/Caches/auto-switch-audio"
binary="$cache_dir/auto-switch-audio-daemon"
if [[ ! -f "$source_file" ]]; then
  echo "Missing runtime source: $source_file. Run install.sh from the source repository." >&2
  exit 1
fi
mkdir -p "$cache_dir"
if [[ ! -x "$binary" || "$source_file" -nt "$binary" ]]; then
  build_file="$cache_dir/.build.$$"
  trap 'rm -f "$build_file"' EXIT
  /usr/bin/xcrun swiftc -O "$source_file" -o "$build_file"
  "$build_file" --self-test >&2
  mv -f "$build_file" "$binary"
fi
if [[ "${1:-}" == "--build-only" ]]; then
  echo "$binary"
  exit 0
fi
exec "$binary" "$@"
