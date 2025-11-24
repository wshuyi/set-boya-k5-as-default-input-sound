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

# 配置变量
DEVICE_NAME="K5 RX"
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
if ! $SWITCH_AUDIO_SOURCE -a -t input | grep -q "$DEVICE_NAME"; then
    echo -e "${YELLOW}警告: 未检测到 '$DEVICE_NAME' 设备${NC}"
    echo "当前可用的输入设备:"
    $SWITCH_AUDIO_SOURCE -a -t input | sed 's/^/  - /'
    echo ""
    read -p "是否继续安装? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ 检测到 '$DEVICE_NAME' 设备${NC}"
fi

# 创建自动切换脚本
echo -e "${YELLOW}[3/5] 创建自动切换脚本...${NC}"
cat > "$AUTO_SWITCH_SCRIPT" << 'EOF'
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
