#!/bin/bash

# 自动切换 BOYA K5 为默认输入设备
# 当 K5 RX 连接时，自动将其设置为默认音频输入设备

DEVICE_NAME="K5 RX"
CHECK_INTERVAL=2
SWITCH_AUDIO_SOURCE="/opt/homebrew/bin/SwitchAudioSource"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

while true; do
    # 获取所有输入设备列表
    DEVICES=$($SWITCH_AUDIO_SOURCE -a -t input 2>/dev/null)

    # 检查 K5 RX 是否在设备列表中
    if echo "$DEVICES" | grep -q "$DEVICE_NAME"; then
        # 获取当前输入设备
        CURRENT=$($SWITCH_AUDIO_SOURCE -t input -c 2>/dev/null)

        # 如果当前设备不是 K5 RX，则切换
        if [ "$CURRENT" != "$DEVICE_NAME" ]; then
            $SWITCH_AUDIO_SOURCE -t input -s "$DEVICE_NAME" 2>/dev/null
            log "已切换输入设备到: $DEVICE_NAME"
        fi
    fi

    sleep $CHECK_INTERVAL
done
