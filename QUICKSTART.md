# 快速使用

1. 运行 `./install.sh`。安装器会先编译验证，再切换后台服务。
2. 执行 `~/.local/bin/auto-switch-audio --status`，确认状态更新时间和 `samplesInWindow`。若提示没有采样，先检查 macOS 麦克风权限。
3. BOYA 连续约 8 秒输出精确全零时，按 DJI、开盖 Mac 内置麦克风、其他可用实体输入的顺序回退；BOYA 恢复信号约 1 秒后切回。

**BOYA 硬件静音也会回退到其他输入。** 需要通话/录制静音时，在对应应用中静音。检测依据是音频就绪，不是电源状态。启动时先用备用设备，再判断 BOYA 是否就绪。

只读观察：`~/.local/bin/auto-switch-audio --probe 15`。自测：`~/.local/bin/auto-switch-audio --self-test`。日志：`~/Library/Logs/auto-switch-audio/`。卸载：`./uninstall.sh`。

本工具只切系统默认输入，不切输出；应用若固定选择某个麦克风，需要改成使用系统默认输入。

其他输入不限定品牌：蓝牙/BLE优先，其次USB等实体输入及有线耳麦，连续互联iPhone最后。同档优先保持当前设备；虚拟、聚合及无法确认的输入不自动接管。合盖限制只针对UID确认的Mac内置麦克风，不针对有线耳麦。
