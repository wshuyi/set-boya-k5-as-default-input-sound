#!/bin/bash

# 自动切换优选麦克风为默认输入设备
# 按优先级顺序检测：K5 RX > DJI MIC MINI

# 按优先级排序的设备列表
DEVICE_NAMES=("K5 RX" "DJI MIC MINI")
CHECK_INTERVAL=2
SWITCH_AUDIO_SOURCE="/opt/homebrew/bin/SwitchAudioSource"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

while true; do
    # 获取所有输入设备列表
    DEVICES=$($SWITCH_AUDIO_SOURCE -a -t input 2>/dev/null)

    # 获取当前输入设备
    CURRENT=$($SWITCH_AUDIO_SOURCE -t input -c 2>/dev/null)

    # 按优先级查找可用设备
    TARGET=""
    for device in "${DEVICE_NAMES[@]}"; do
        if echo "$DEVICES" | grep -q "$device"; then
            TARGET="$device"
            break
        fi
    done

    # 如果找到目标设备且不是当前设备，则切换
    if [ -n "$TARGET" ] && [ "$CURRENT" != "$TARGET" ]; then
        $SWITCH_AUDIO_SOURCE -t input -s "$TARGET" 2>/dev/null
        log "已切换输入设备到: $TARGET"
    fi

    sleep $CHECK_INTERVAL
done
