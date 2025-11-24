#!/bin/bash

# BOYA K5 自动切换输入设备 - 卸载脚本
# 适用于 macOS

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
LAUNCHAGENT_LABEL="com.user.auto-switch-audio"
LAUNCHAGENT_PLIST="$HOME/Library/LaunchAgents/${LAUNCHAGENT_LABEL}.plist"

echo -e "${YELLOW}======================================${NC}"
echo -e "${YELLOW}BOYA K5 自动切换卸载脚本${NC}"
echo -e "${YELLOW}======================================${NC}"
echo ""

# 检查服务是否存在
if [ ! -f "$LAUNCHAGENT_PLIST" ]; then
    echo -e "${YELLOW}服务未安装，无需卸载${NC}"
    exit 0
fi

# 停止并卸载服务
echo -e "${YELLOW}[1/3] 停止服务...${NC}"
if launchctl list | grep -q "$LAUNCHAGENT_LABEL"; then
    launchctl unload "$LAUNCHAGENT_PLIST"
    echo -e "${GREEN}✓ 服务已停止${NC}"
else
    echo -e "${YELLOW}服务未运行${NC}"
fi

# 删除 LaunchAgent plist
echo -e "${YELLOW}[2/3] 删除配置文件...${NC}"
rm -f "$LAUNCHAGENT_PLIST"
echo -e "${GREEN}✓ 已删除: $LAUNCHAGENT_PLIST${NC}"

# 清理日志文件
echo -e "${YELLOW}[3/3] 清理日志文件...${NC}"
rm -f /tmp/auto-switch-audio.log
rm -f /tmp/auto-switch-audio.err
echo -e "${GREEN}✓ 日志已清理${NC}"

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}卸载完成！${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "注意:"
echo "  - 项目目录未删除，如需删除请手动操作"
echo "  - SwitchAudioSource 工具未卸载，如需卸载请运行:"
echo "    brew uninstall switchaudio-osx"
echo ""
