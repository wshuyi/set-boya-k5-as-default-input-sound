# 自动切换优选麦克风

当优选麦克风连接到 macOS 时，自动将其设置为默认音频输入设备。

支持按优先级检测多个设备：
1. **K5 RX** (BOYA K5) - 第一优先级
2. **DJI MIC MINI** - 第二优先级

## 快速开始

### 一键安装

```bash
./install.sh
```

安装脚本将自动完成以下操作：
1. 检查并安装 SwitchAudioSource 工具
2. 创建自动切换脚本
3. 配置 LaunchAgent 后台服务
4. 启动服务

### 卸载

```bash
./uninstall.sh
```

## 功能特性

- 🎤 自动检测优选麦克风设备连接（K5 RX、DJI MIC MINI）
- 🔄 按优先级自动切换为默认输入设备
- 🚀 开机自动启动
- ⚡ 每 2 秒检查一次设备状态
- 📝 支持日志记录

## 工作原理

1. LaunchAgent 在系统启动时自动运行监听脚本
2. 脚本每 2 秒检查一次音频输入设备列表
3. 按优先级顺序检测设备：K5 RX > DJI MIC MINI
4. 如果检测到优选设备且不是当前默认输入设备，则自动切换
5. 所有操作都会记录到 `/tmp/auto-switch-audio.log`

## 系统要求

- macOS（已在 macOS Sequoia 15.1 测试）
- Homebrew
- 支持的麦克风：BOYA K5 或 DJI MIC MINI

## 在其他 macOS 设备上安装

1. 将此项目克隆或复制到新的 macOS 设备
2. 进入项目目录
3. 运行安装脚本：`./install.sh`

## 管理命令

### 查看服务状态
```bash
launchctl list | grep auto-switch-audio
```

### 停止服务
```bash
launchctl unload ~/Library/LaunchAgents/com.user.auto-switch-audio.plist
```

### 启动服务
```bash
launchctl load ~/Library/LaunchAgents/com.user.auto-switch-audio.plist
```

### 查看日志
```bash
# 查看输出日志
tail -f /tmp/auto-switch-audio.log

# 查看错误日志
tail -f /tmp/auto-switch-audio.err
```

### 查看当前音频设备
```bash
# 查看所有输入设备
SwitchAudioSource -a -t input

# 查看当前输入设备
SwitchAudioSource -t input -c
```

## 文件说明

- `install.sh` - 一键安装脚本
- `uninstall.sh` - 卸载脚本
- `auto-switch-audio.sh` - 自动切换脚本（由 install.sh 自动生成）
- `~/Library/LaunchAgents/com.user.auto-switch-audio.plist` - LaunchAgent 配置（由 install.sh 自动生成）

## 验证功能

安装后可以通过以下命令测试：

```bash
# 查看当前输入设备（应该是优选麦克风之一）
SwitchAudioSource -t input -c

# 手动切换到其他设备
SwitchAudioSource -t input -s "MacBook Pro Microphone"

# 等待 2-5 秒后再次查看（应该自动切换回优选麦克风）
sleep 5 && SwitchAudioSource -t input -c
```

## 故障排除

### 服务未运行
```bash
# 查看服务状态
launchctl list | grep auto-switch-audio

# 重新安装
./uninstall.sh
./install.sh
```

### 设备名称不匹配或添加新设备
如果你的设备显示名称不同，或想添加其他设备：

1. 查看实际设备名：
   ```bash
   SwitchAudioSource -a -t input
   ```

2. 编辑 `auto-switch-audio.sh`，修改 `DEVICE_NAMES` 数组（按优先级排序）：
   ```bash
   DEVICE_NAMES=("K5 RX" "DJI MIC MINI" "其他设备名")
   ```

3. 重新加载服务：
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.user.auto-switch-audio.plist
   launchctl load ~/Library/LaunchAgents/com.user.auto-switch-audio.plist
   ```

### 查看错误日志
```bash
cat /tmp/auto-switch-audio.err
```

## 注意事项

- 此功能会在系统启动时自动运行
- 优选麦克风连接后会始终保持为默认输入设备（K5 RX 优先于 DJI MIC MINI）
- 如果需要临时使用其他麦克风，需要先停止服务
- 项目目录可以放在任意位置，脚本会自动检测

## License

MIT
