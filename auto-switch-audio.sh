#!/bin/bash

# 自动切换优选麦克风为默认输入设备
# 按优先级顺序检测：K5 RX > DJI MIC MINI > MacBook Pro Microphone（仅开盖时）

# 按优先级排序的外接设备列表
DEVICE_NAMES=("K5 RX" "DJI MIC MINI")
# 内置麦克风（仅在开盖时使用）
BUILTIN_MIC="MacBook Pro Microphone"
CHECK_INTERVAL=2
SWITCH_AUDIO_SOURCE="/opt/homebrew/bin/SwitchAudioSource"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# 检测是否合盖模式
is_clamshell() {
    ioreg -r -k AppleClamshellState -d 4 2>/dev/null | grep -q '"AppleClamshellState" = Yes'
}

while true; do
    # 获取所有输入设备列表
    DEVICES=$($SWITCH_AUDIO_SOURCE -a -t input 2>/dev/null)

    # 获取当前输入设备
    CURRENT=$($SWITCH_AUDIO_SOURCE -t input -c 2>/dev/null)

    # 按优先级查找可用的外接设备
    TARGET=""
    for device in "${DEVICE_NAMES[@]}"; do
        if echo "$DEVICES" | grep -q "$device"; then
            TARGET="$device"
            break
        fi
    done

    # 如果没有外接设备，且盖子打开，使用内置麦克风
    if [ -z "$TARGET" ] && ! is_clamshell; then
        if echo "$DEVICES" | grep -q "$BUILTIN_MIC"; then
            TARGET="$BUILTIN_MIC"
        fi
    fi

    # 如果找到目标设备且不是当前设备，则切换
    if [ -n "$TARGET" ] && [ "$CURRENT" != "$TARGET" ]; then
        $SWITCH_AUDIO_SOURCE -t input -s "$TARGET" 2>/dev/null
        log "已切换输入设备到: $TARGET"
    fi

    sleep $CHECK_INTERVAL
done
