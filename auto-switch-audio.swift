import CoreAudio
import Foundation

// === Configuration ===
let preferredDevices = ["K5 RX", "DJI MIC MINI"]
let builtinMic = "MacBook Pro Microphone"
let switchAudioSource = "/opt/homebrew/bin/SwitchAudioSource"
let safetyCheckInterval: TimeInterval = 30  // fallback periodic check

// === Logging ===
func log(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    let timestamp = formatter.string(from: Date())
    print("[\(timestamp)] \(message)")
    fflush(stdout)
}

// === Audio device helpers ===
func runCommand(_ path: String, _ args: [String]) -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: path)
    task.arguments = args
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = FileHandle.nullDevice
    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        return nil
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

func getCurrentInputDevice() -> String? {
    return runCommand(switchAudioSource, ["-t", "input", "-c"])
}

func getAvailableInputDevices() -> [String] {
    guard let output = runCommand(switchAudioSource, ["-a", "-t", "input"]) else {
        return []
    }
    return output.components(separatedBy: "\n").filter { !$0.isEmpty }
}

func isClamshell() -> Bool {
    guard let output = runCommand("/usr/sbin/ioreg", ["-r", "-k", "AppleClamshellState", "-d", "4"]) else {
        return false
    }
    return output.contains("\"AppleClamshellState\" = Yes")
}

func switchToPreferred() {
    let available = getAvailableInputDevices()
    let current = getCurrentInputDevice()

    // Find highest priority external device
    var target: String? = nil
    for device in preferredDevices {
        if available.contains(where: { $0.contains(device) }) {
            target = device
            break
        }
    }

    // Fallback to builtin mic if lid is open
    if target == nil && !isClamshell() {
        if available.contains(where: { $0.contains(builtinMic) }) {
            target = builtinMic
        }
    }

    guard let target = target else { return }
    guard current != target else { return }

    // Switch and verify
    let result = runCommand(switchAudioSource, ["-t", "input", "-s", target])
    if let result = result, result.contains("set to") {
        log("已切换输入设备到: \(target)")
    } else {
        log("切换失败: \(target) (设备可能已断开)")
    }
}

// === CoreAudio event listeners ===
// Debounce: ignore rapid-fire events within 100ms
var lastSwitchTime: Date = .distantPast
let debounceInterval: TimeInterval = 0.1

func debouncedSwitch() {
    let now = Date()
    guard now.timeIntervalSince(lastSwitchTime) > debounceInterval else { return }
    lastSwitchTime = now

    // Small delay to let the system settle, then switch
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        switchToPreferred()
    }
}

// Listen for default input device changes
var defaultInputAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultInputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)

let defaultInputStatus = AudioObjectAddPropertyListenerBlock(
    AudioObjectID(kAudioObjectSystemObject),
    &defaultInputAddress,
    DispatchQueue.main
) { _, _ in
    debouncedSwitch()
}

if defaultInputStatus != noErr {
    log("警告: 无法注册默认输入设备监听 (error: \(defaultInputStatus))")
}

// Listen for device list changes (connect/disconnect)
var deviceListAddress = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDevices,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)

let deviceListStatus = AudioObjectAddPropertyListenerBlock(
    AudioObjectID(kAudioObjectSystemObject),
    &deviceListAddress,
    DispatchQueue.main
) { _, _ in
    // Slightly longer delay for device list changes (device needs time to initialize)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        switchToPreferred()
    }
}

if deviceListStatus != noErr {
    log("警告: 无法注册设备列表监听 (error: \(deviceListStatus))")
}

// === Startup ===
log("音频输入设备守护进程启动 (事件驱动模式)")
log("优先设备: \(preferredDevices.joined(separator: " > "))")
log("内置麦克风: \(builtinMic) (仅开盖时)")

// Initial switch
switchToPreferred()
if let current = getCurrentInputDevice() {
    log("当前输入设备: \(current)")
}

// Safety net: periodic check every 30 seconds
let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
timer.schedule(deadline: .now() + safetyCheckInterval, repeating: safetyCheckInterval)
timer.setEventHandler {
    switchToPreferred()
}
timer.resume()

// Keep running
RunLoop.main.run()
