# BOYA K5 / 通用输入自动切换

macOS 接着 K5 RX USB 接收器时，即使 BOYA 发射器关机，系统仍把接收器当作可用输入。本工具直接观察接收器的音频流，让输入在 BOYA、DJI、Mac 内置麦克风和其他可用实体输入之间自动选择。

**这是音频信号就绪检测，不是发射器电源检测。** 2026-10-25 在真实设备上核验：关机和硬件静音都会输出精确全零；公开的 CoreAudio 属性与两个 HID 接口没有提供可区分标志。本工具的策略是“静音也回退备用输入”。因此 BOYA 静音按钮不再代表整台电脑静音；需要整机静音时应在通话/录制应用中静音。

## 规则

- BOYA 已有信号时优先使用 BOYA。连续约 **8 秒精确全零**后回退；普通安静、微弱但非零的底噪不会触发。
- BOYA 信号恢复持续约 **1 秒**后自动切回。
- 顺序：就绪的 `K5 RX` → `DJI MIC MINI` → Mac 真正内置麦克风（仅开盖）→ 其他真实输入设备。备用设备不按品牌或 AirPods 名称识别。
- 其他真实输入中，蓝牙/BLE 耳机或麦克风优先，其次实体 USB、PCI、FireWire、Thunderbolt、HDMI/DisplayPort 输入，以及已识别的有线耳麦/线路输入；连续互联 iPhone 麦克风最后考虑。所有候选都必须由系统报告设备存活且至少有一个输入通道，只有输出的耳机不会入选。
- 同档保留当前输入；否则按设备 UID、名称、ID 稳定排序，避免设备枚举顺序变化导致来回切换。较高档设备恢复时仍会切向较高档。
- 内置麦克风用 UID `BuiltInMicrophoneDevice` 确认，不能仅凭 built-in transport 判断：有线耳麦也可能使用这个 transport。已知 `BuiltInHeadphoneInputDevice` / `BuiltInLineInputDevice` 不因合盖排除。无法确认的内置路径、未知 transport、虚拟设备、聚合设备及网络输入不自动接管；未就绪的 BOYA 不会混入通用备用设备。
- 启动时先选择可用的备用输入，取得足够信号后回 BOYA。设备消失、读取错误、无采样回调都属于 **unknown**，不算“全零”；有备用输入时回退，并每 5 秒重试监视。
- 无合适备用输入时保留系统当前输入并在状态中显示 `target: none`。不会选择合盖的内置麦克风。
- BOYA 接收器被拔插、设备列表变化或睡眠恢复后重新建立监视。只改系统默认**输入**，不改输出；自行固定输入的应用需要选择系统默认输入才能跟随。

程序持续单独打开 BOYA 输入，因此可能显示 macOS 麦克风使用指示。数据只在内存中统计样本和精确非零数量，不保存、上传音频或转写。若系统要求麦克风授权，需要实际批准；安装成功不等于授权或真实采样已成功。

## 安装与状态

需要 macOS 和 Xcode Command Line Tools 的 Swift 编译器，无需 Homebrew 或 SwitchAudioSource。

```sh
./install.sh
~/.local/bin/auto-switch-audio --status
```

安装无需额外确认，`--yes` 也可用于自动化。安装器先编译和自测，再更新服务；启动步骤失败会恢复旧文件和旧 LaunchAgent。历史 shell 服务的回滚脚本会单独保存。回滚备份位于 `~/Library/Caches/auto-switch-audio/backup-*`，安装输出给出准确位置。

正式入口在 `~/.local/bin/auto-switch-audio`，源码在 `~/.local/share/auto-switch-audio/auto-switch-audio.swift`。本机编译缓存位于 `~/Library/Caches/auto-switch-audio/`；入口只在缓存不存在或源码更新时重新编译。源码与入口可由 chezmoi 分发，二进制不跨机器同步。仓库旧的 `auto-switch-audio-daemon` 是历史构建产物，安装器不会使用它。

LaunchAgent 标签沿用 `com.user.auto-switch-audio`。日志在 `~/Library/Logs/auto-switch-audio/`，状态在 `~/Library/Application Support/auto-switch-audio/status.json`；状态含时间戳、进程号、实际输入、目标、就绪状态、样本数和错误，请检查更新时间，旧状态文件不证明服务仍在运行。

```sh
~/.local/bin/auto-switch-audio --version
~/.local/bin/auto-switch-audio --self-test
~/.local/bin/auto-switch-audio --probe 15  # 只观察15秒，不切默认输入，不覆盖服务状态
launchctl print gui/$(id -u)/com.user.auto-switch-audio
./uninstall.sh
```

安装后应核对 `samplesInWindow > 0`。`zero-stream` 表示收到了样本但全零；`unknown` 加 `no-samples` 表示没有成功采样，应检查系统麦克风权限或设备状态。实测应包含关机/静音回退、恢复信号切回，以及使用中的应用是否跟随默认输入。

## 实现与验证

Swift CoreAudio IOProc 直接监视 BOYA，不通过临时切换默认输入采样。每 0.5 秒处理聚合计数，设备事件触发刷新并保留 5 秒周期检查。每次切换都读取系统默认输入核验。IOKit 读取合盖状态；状态未知时不选择内置麦克风。

`--self-test` 验证 8 秒全零、1 秒恢复、短零段、极小非零、无数据、睡眠间隔、通用蓝牙/BLE/USB 与有线耳麦、当前设备稳定性、虚拟/聚合排除、连续互联末档和合盖选择。实际设备测试另核验采样权限、硬件静音/开关机、输入读回；状态机测试不冒充硬件验证。
