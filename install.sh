#!/bin/bash

# BOYA K5 自动切换输入设备 - 一键安装脚本
# 适用于 macOS

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 配置变量 - 按优先级排序
DEVICE_NAMES=("K5 RX" "DJI MIC MINI")
LAUNCHAGENT_LABEL="com.user.auto-switch-audio"
LAUNCHAGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCHAGENT_LABEL}.plist"
AUTO_SWITCH_SCRIPT="$SCRIPT_DIR/auto-switch-audio.sh"
SWITCH_AUDIO_SOURCE="/opt/homebrew/bin/SwitchAudioSource"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}BOYA K5 自动切换安装脚本${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "项目目录: $SCRIPT_DIR"
echo ""

# 检查是否已安装 Homebrew
if ! command -v brew &> /dev/null; then
    echo -e "${RED}错误: 未检测到 Homebrew${NC}"
    echo "请先安装 Homebrew: https://brew.sh"
    exit 1
fi

# 检查并安装 SwitchAudioSource
echo -e "${YELLOW}[1/5] 检查 SwitchAudioSource...${NC}"
if ! command -v SwitchAudioSource &> /dev/null; then
    echo "正在安装 SwitchAudioSource..."
    brew install switchaudio-osx
    echo -e "${GREEN}✓ SwitchAudioSource 安装完成${NC}"
else
    echo -e "${GREEN}✓ SwitchAudioSource 已安装${NC}"
fi

# 检查设备是否存在
echo -e "${YELLOW}[2/5] 检查音频设备...${NC}"
FOUND_DEVICE=false
for device in "${DEVICE_NAMES[@]}"; do
    if $SWITCH_AUDIO_SOURCE -a -t input | grep -q "$device"; then
        echo -e "${GREEN}✓ 检测到 '$device' 设备${NC}"
        FOUND_DEVICE=true
    else
        echo -e "${YELLOW}  未检测到 '$device' 设备${NC}"
    fi
done

if [ "$FOUND_DEVICE" = false ]; then
    echo -e "${YELLOW}警告: 未检测到任何目标设备${NC}"
    echo "当前可用的输入设备:"
    $SWITCH_AUDIO_SOURCE -a -t input | sed 's/^/  - /'
    echo ""
    read -p "是否继续安装? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 创建自动切换脚本
echo -e "${YELLOW}[3/5] 创建自动切换脚本...${NC}"
cat > "$AUTO_SWITCH_SCRIPT" << 'EOF'
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
EOF

chmod +x "$AUTO_SWITCH_SCRIPT"
echo -e "${GREEN}✓ 脚本创建完成: $AUTO_SWITCH_SCRIPT${NC}"

# 创建 LaunchAgent plist
echo -e "${YELLOW}[4/5] 配置 LaunchAgent...${NC}"
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$LAUNCHAGENT_PLIST" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCHAGENT_LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>${AUTO_SWITCH_SCRIPT}</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/auto-switch-audio.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/auto-switch-audio.err</string>
</dict>
</plist>
EOF

echo -e "${GREEN}✓ LaunchAgent 配置完成: $LAUNCHAGENT_PLIST${NC}"

# 停止旧服务（如果存在）
if launchctl list | grep -q "$LAUNCHAGENT_LABEL"; then
    echo "停止旧服务..."
    launchctl unload "$LAUNCHAGENT_PLIST" 2>/dev/null || true
fi

# 启动服务
echo -e "${YELLOW}[5/5] 启动服务...${NC}"
launchctl load "$LAUNCHAGENT_PLIST"

# 等待服务启动
sleep 2

# 验证服务状态
if launchctl list | grep -q "$LAUNCHAGENT_LABEL"; then
    echo -e "${GREEN}✓ 服务启动成功${NC}"
else
    echo -e "${RED}✗ 服务启动失败${NC}"
    exit 1
fi

# 显示当前输入设备
CURRENT_DEVICE=$($SWITCH_AUDIO_SOURCE -t input -c)
echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}安装完成！${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "当前输入设备: $CURRENT_DEVICE"
echo ""
echo "管理命令:"
echo "  查看状态: launchctl list | grep auto-switch-audio"
echo "  查看日志: tail -f /tmp/auto-switch-audio.log"
echo "  卸载服务: $SCRIPT_DIR/uninstall.sh"
echo ""
echo "服务将在系统启动时自动运行"
echo ""
