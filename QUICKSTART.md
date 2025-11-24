# 快速开始

## 一键安装

```bash
cd /path/to/set-boya-k5-as-default-input-sound
./install.sh
```

## 验证功能

安装完成后，尝试切换到其他麦克风，2-3 秒后会自动切换回 K5 RX：

```bash
# 切换到 MacBook 内置麦克风
SwitchAudioSource -t input -s "MacBook Pro Microphone"

# 等待 3 秒，自动切回 K5 RX
sleep 3 && SwitchAudioSource -t input -c
```

## 卸载

```bash
./uninstall.sh
```

## 在其他 Mac 上使用

1. 将整个项目文件夹复制到新 Mac
2. 进入项目目录
3. 运行 `./install.sh`

就这么简单！
