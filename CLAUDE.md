# Project guidance

This macOS utility monitors K5 RX input audio and selects the default input using CoreAudio. Read README.md before changing behavior. Exact-zero audio readiness is **not** transmitter power status. Hardware mute and transmitter-off are indistinguishable on the tested unit; the configured policy treats both as unavailable and triggers fallback.

- `auto-switch-audio.swift`: only daemon implementation; includes pure `--self-test`, read-only `--probe`, and `--status`.
- `auto-switch-audio.sh`: installed entry wrapper; builds the installed Swift source into a per-machine cache when needed. Never regenerate the former name-only polling loop.
- `install.sh`: compile/test first, save rollback, install source and wrapper, then load `com.user.auto-switch-audio`.
- `uninstall.sh`: stop service/remove installed entry and source; retain logs and rollback history.
- The tracked `auto-switch-audio-daemon` is an old binary, not an installation input. Do not edit or distribute it.

Runtime: `~/.local/bin/auto-switch-audio`, `~/.local/share/auto-switch-audio/auto-switch-audio.swift`; binary cache under `~/Library/Caches/auto-switch-audio`. Follow global chezmoi rules for deployment and multi-machine sync. Do not include unrelated WIP.

Validate meaningful state timing and error/retry behavior. Real microphone permission and actual default-input readback must be checked after deployment. Do not save audio. Preserve exact-zero semantics; ordinary low volume must not count as disconnection. On invalid/missing data, use unknown rather than silence.

Selection priority: ready BOYA > connected DJI > UID-confirmed Mac internal microphone (lid open only) > generic Bluetooth/BLE input > other recognized physical inputs/wired headset > Continuity Capture. Never use an AirPods-name whitelist. Built-in transport does not prove a laptop microphone; use UID and allow known wired-headset UIDs with the lid closed. Within the same rank retain the current input, then use stable UID ordering. Exclude virtual/aggregate/unknown inputs and unready BOYA from generic fallback.
