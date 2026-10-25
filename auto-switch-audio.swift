import Foundation
import CoreAudio
import IOKit

let version = "2026.10.25.3"
func log(_ s: String) { print("\(ISO8601DateFormatter().string(from: Date())) \(s)"); fflush(stdout) }

struct Readiness {
    enum State: String { case unknown, ready, zeroStream = "zero-stream" }
    var state: State = .unknown
    var zeroSeconds = 0.0
    var signalSeconds = 0.0
    mutating func update(samples: Int, nonzero: Int, elapsed: Double) {
        guard samples > 0, elapsed > 0, elapsed < 2 else {
            state = .unknown; zeroSeconds = 0; signalSeconds = 0; return
        }
        if nonzero > 0 {
            zeroSeconds = 0; signalSeconds += elapsed
            if signalSeconds >= 1 { state = .ready }
        } else {
            signalSeconds = 0; zeroSeconds += elapsed
            if zeroSeconds >= 2 { state = .zeroStream }
        }
    }
}

func selfTest() {
    var s = Readiness()
    for _ in 0..<2 { s.update(samples: 24000, nonzero: 1, elapsed: 0.5) }
    precondition(s.state == .ready, "Even one tiny nonzero sample counts as signal")
    for _ in 0..<3 { s.update(samples: 24000, nonzero: 0, elapsed: 0.5) }
    precondition(s.state == .ready, "Short zero gaps must not switch")
    s.update(samples: 24000, nonzero: 0, elapsed: 0.5)
    precondition(s.state == .zeroStream, "Two seconds of exact zeros must fall back")
    s.update(samples: 24000, nonzero: 1, elapsed: 0.5)
    precondition(s.state == .zeroStream, "One recovery window is insufficient")
    s.update(samples: 24000, nonzero: 1, elapsed: 0.5)
    precondition(s.state == .ready)
    s.update(samples: 0, nonzero: 0, elapsed: 0.5)
    precondition(s.state == .unknown && s.zeroSeconds == 0, "Missing samples are not silence")
    s.update(samples: 24000, nonzero: 0, elapsed: 10)
    precondition(s.state == .unknown && s.zeroSeconds == 0, "Sleep/gaps must reset evidence")
    for _ in 0..<4 { s.update(samples: 24000, nonzero: 0, elapsed: 0.5) }
    precondition(s.state == .zeroStream)
    let boya = Device(id: 1, name: "K5 RX", uid: "usb-boya", transport: kAudioDeviceTransportTypeUSB)
    let bt = Device(id: 2, name: "Any Brand Headset", uid: "bt-a", transport: kAudioDeviceTransportTypeBluetooth)
    let dji = Device(id: 3, name: "DJI MIC MINI", uid: "usb-dji", transport: kAudioDeviceTransportTypeUSB)
    let builtin = Device(id: 4, name: "Localized Mic", uid: "BuiltInMicrophoneDevice", transport: kAudioDeviceTransportTypeBuiltIn)
    let wired = Device(id: 5, name: "Headset Microphone", uid: "BuiltInHeadphoneInputDevice", transport: kAudioDeviceTransportTypeBuiltIn)
    let usb = Device(id: 6, name: "USB Microphone", uid: "usb-a", transport: kAudioDeviceTransportTypeUSB)
    let bt2 = Device(id: 7, name: "Another Brand", uid: "bt-b", transport: kAudioDeviceTransportTypeBluetoothLE)
    let virtual = Device(id: 8, name: "Virtual Mic", uid: "virtual-a", transport: kAudioDeviceTransportTypeVirtual)
    let aggregate = Device(id: 9, name: "Combined Inputs", uid: "aggregate-a", transport: kAudioDeviceTransportTypeAggregate)
    let continuity = Device(id: 10, name: "Phone Mic", uid: "phone-a", transport: kAudioDeviceTransportTypeContinuityCaptureWireless)
    let unknown = Device(id: 11, name: "Unknown", uid: "unknown", transport: 0)
    let unknownBuiltin = Device(id: 12, name: "Unknown built-in path", uid: "unknown-built-in", transport: kAudioDeviceTransportTypeBuiltIn)
    precondition(selectDevice([bt, builtin, dji, boya], readiness: .ready, lidClosed: false)?.id == boya.id)
    precondition(selectDevice([bt, builtin, dji, boya], readiness: .zeroStream, lidClosed: false)?.id == dji.id)
    precondition(selectDevice([bt, builtin, boya], readiness: .unknown, lidClosed: false)?.id == builtin.id)
    precondition(selectDevice([bt, builtin, boya], readiness: .unknown, lidClosed: true)?.id == bt.id)
    precondition(selectDevice([builtin, boya], readiness: .unknown, lidClosed: true) == nil)
    precondition(selectDevice([wired, builtin], readiness: .unknown, lidClosed: true)?.id == wired.id)
    precondition(selectDevice([usb, bt2], readiness: .unknown, lidClosed: true, current: usb.id)?.id == bt2.id)
    precondition(selectDevice([bt, bt2], readiness: .unknown, lidClosed: true, current: bt2.id)?.id == bt2.id)
    precondition(selectDevice([bt2, bt], readiness: .unknown, lidClosed: true)?.id == bt.id)
    precondition(selectDevice([bt, bt2], readiness: .unknown, lidClosed: true)?.id == bt.id)
    precondition(selectDevice([virtual, aggregate, unknown, unknownBuiltin], readiness: .unknown, lidClosed: true) == nil)
    precondition(selectDevice([continuity, usb], readiness: .unknown, lidClosed: true, current: continuity.id)?.id == usb.id)
    precondition(selectDevice([continuity, virtual], readiness: .unknown, lidClosed: true)?.id == continuity.id)
    print("PASS: zero/recovery timing, tiny signal, missing data, sleep gap; BOYA/DJI/built-in priority, generic Bluetooth/BLE/USB/wired fallback, closed-lid UID distinction, current-device stability, deterministic order, virtual/aggregate/unknown exclusion, continuity last")
}

func address(_ selector: AudioObjectPropertySelector, scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
}
func uintProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> UInt32? {
    var a = address(selector); var value: UInt32 = 0; var size = UInt32(MemoryLayout<UInt32>.size)
    return AudioObjectGetPropertyData(id, &a, 0, nil, &size, &value) == noErr ? value : nil
}
func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var a = address(selector); var value: Unmanaged<CFString>?; var size = UInt32(MemoryLayout<CFString?>.size)
    guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &value) == noErr, let value else { return nil }
    return value.takeRetainedValue() as String
}
func nameProperty(_ id: AudioObjectID) -> String { stringProperty(id, kAudioObjectPropertyName) ?? "device-\(id)" }
struct Device { let id: AudioDeviceID; let name: String; let uid: String; let transport: UInt32 }
func inputDevices() -> [Device] {
    var a = address(kAudioHardwarePropertyDevices); var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &ids) == noErr else { return [] }
    return ids.compactMap { id in
        guard uintProperty(id, kAudioDevicePropertyDeviceIsAlive) == 1 else { return nil }
        var p = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioObjectPropertyScopeInput); var n: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &p, 0, nil, &n) == noErr, n > 0 else { return nil }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(n), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &p, 0, nil, &n, raw) == noErr else { return nil }
        let channels = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + Int($1.mNumberChannels) }
        guard channels > 0 else { return nil }
        return Device(id: id, name: nameProperty(id), uid: stringProperty(id, kAudioDevicePropertyDeviceUID) ?? "", transport: uintProperty(id, kAudioDevicePropertyTransportType) ?? 0)
    }
}
func lidClosed() -> Bool {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard service != 0 else { return true } // unknown lid state must not select the built-in microphone
    defer { IOObjectRelease(service) }
    return (IORegistryEntryCreateCFProperty(service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Bool) ?? true
}
func selectDevice(_ devices: [Device], readiness: Readiness.State, lidClosed: Bool, current: AudioDeviceID? = nil) -> Device? {
    // inputDevices has already verified alive status and at least one input channel.
    // A built-in transport alone is not a laptop microphone: the wired headset port uses it too.
    func rank(_ d: Device) -> Int? {
        if d.name == "K5 RX" { return readiness == .ready ? 0 : nil }
        if d.name.localizedCaseInsensitiveContains("DJI MIC MINI") { return 1 }
        if d.uid == "BuiltInMicrophoneDevice" { return lidClosed ? nil : 2 }
        switch d.transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return 3
        case kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypePCI,
             kAudioDeviceTransportTypeFireWire, kAudioDeviceTransportTypeThunderbolt,
             kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return 4
        case kAudioDeviceTransportTypeBuiltIn:
            return ["BuiltInHeadphoneInputDevice", "BuiltInLineInputDevice"].contains(d.uid) ? 4 : nil
        case kAudioDeviceTransportTypeContinuityCaptureWired, kAudioDeviceTransportTypeContinuityCaptureWireless,
             0x63636170: return 5 // legacy 'ccap' Continuity Capture transport
        default: return nil // virtual, aggregate, network, or unknown input: never claim automatically
        }
    }
    return devices.compactMap { d -> (Device, Int)? in rank(d).map { (d, $0) } }.sorted {
        if $0.1 != $1.1 { return $0.1 < $1.1 }
        if ($0.0.id == current) != ($1.0.id == current) { return $0.0.id == current }
        if $0.0.uid != $1.0.uid { return $0.0.uid < $1.0.uid }
        if $0.0.name != $1.0.name { return $0.0.name < $1.0.name }
        return $0.0.id < $1.0.id
    }.first?.0
}

// The callback retains only aggregate counters. No audio buffer or recording leaves this callback.
final class Monitor {
    let device: AudioDeviceID
    private var proc: AudioDeviceIOProcID?
    private let lock = NSLock()
    private var samples = 0, nonzero = 0
    private(set) var error: String?
    init(device: AudioDeviceID) { self.device = device }
    func start() -> Bool {
        var fmt = AudioStreamBasicDescription(); var size = UInt32(MemoryLayout.size(ofValue: fmt))
        var p = address(kAudioDevicePropertyStreamFormat, scope: kAudioObjectPropertyScopeInput)
        let result = AudioObjectGetPropertyData(device, &p, 0, nil, &size, &fmt)
        guard result == noErr, fmt.mFormatID == kAudioFormatLinearPCM,
              fmt.mFormatFlags & kAudioFormatFlagIsFloat != 0, fmt.mBitsPerChannel == 32 else {
            error = "unsupported-format-or-read-error:\(result)"; return false
        }
        let create = AudioDeviceCreateIOProcIDWithBlock(&proc, device, nil) { [weak self] _, input, _, _, _ in
            guard let self else { return }
            var count = 0, nz = 0
            for buffer in UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input)) {
                guard let data = buffer.mData else { continue }
                let values = data.assumingMemoryBound(to: Float.self)
                for i in 0..<Int(buffer.mDataByteSize) / MemoryLayout<Float>.size {
                    let value = values[i]
                    // Invalid samples are not evidence of zero or valid signal.
                    guard value.isFinite else { continue }
                    count += 1
                    if value != 0 { nz += 1 }
                }
            }
            self.lock.lock(); self.samples += count; self.nonzero += nz; self.lock.unlock()
        }
        guard create == noErr, let proc else { error = "create:\(create)"; return false }
        let start = AudioDeviceStart(device, proc)
        guard start == noErr else { error = "start:\(start)"; stop(); return false }
        return true
    }
    func take() -> (Int, Int) {
        lock.lock(); defer { lock.unlock() }
        let result = (samples, nonzero); samples = 0; nonzero = 0; return result
    }
    func stop() {
        if let proc { AudioDeviceStop(device, proc); AudioDeviceDestroyIOProcID(device, proc); self.proc = nil }
    }
    deinit { stop() }
}

let args = Array(CommandLine.arguments.dropFirst())
let statusURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/auto-switch-audio/status.json")
if args.contains("--help") {
    print("auto-switch-audio \(version)\n--self-test  Run pure state/selection tests.\n--probe [seconds]  Observe BOYA and proposed target without changing default input or daemon status.\n--status  Read the running daemon's last status (includes timestamp).\n--version  Print version.\nDefault: monitor BOYA exact-zero signal and select input. Hardware mute ALSO triggers fallback after 2 seconds; this does not detect transmitter power. No audio is saved.")
    exit(0)
}
if args.contains("--version") { print(version); exit(0) }
if args.contains("--self-test") { selfTest(); exit(0) }
if args.contains("--status") {
    guard let data = try? Data(contentsOf: statusURL) else { fputs("No daemon status available.\n", stderr); exit(1) }
    FileHandle.standardOutput.write(data); print(); exit(0)
}
let dryRun = args.first == "--probe"
let duration = dryRun ? (args.count > 1 ? Double(args[1]) ?? 15 : 15) : 0
if (!args.isEmpty && !dryRun) || duration < 0 { fputs("Unknown arguments; use --help.\n", stderr); exit(2) }
var monitor: Monitor?
var observedBoyaID: AudioDeviceID?
var readiness = Readiness()
var devices: [Device] = []
var nextRefresh = 0.0, nextRetry = 0.0, nextStatus = 0.0, lastTick = ProcessInfo.processInfo.systemUptime
var lastState = "", lastTarget: AudioDeviceID?, lastError = "", missingSeconds = 0.0
let started = lastTick
var refreshRequested = true
var listProperty = address(kAudioHardwarePropertyDevices)
AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &listProperty, DispatchQueue.main) { _, _ in refreshRequested = true }
log("start version=\(version) mode=\(dryRun ? "probe" : "daemon") policy=exact-zero-2s/recovery-1s hardware-mute-also-falls-back no-recording")
let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
timer.setEventHandler {
    let now = ProcessInfo.processInfo.systemUptime
    let elapsed = now - lastTick; lastTick = now
    if refreshRequested || now >= nextRefresh {
        devices = inputDevices(); nextRefresh = now + 5; refreshRequested = false
    }
    let boya = devices.first(where: { $0.name == "K5 RX" })
    if observedBoyaID != boya?.id || elapsed >= 2 {
        observedBoyaID = boya?.id
        monitor?.stop(); monitor = nil; readiness = Readiness(); missingSeconds = 0; nextRetry = now
    }
    if monitor == nil, let boya, now >= nextRetry {
        let candidate = Monitor(device: boya.id)
        if candidate.start() { monitor = candidate; lastError = ""; log("monitor-start device=\(boya.id)") }
        else { lastError = candidate.error ?? "unknown-start-error"; log("monitor-error \(lastError)") }
        nextRetry = now + 5
    }
    let (samples, nonzero) = monitor?.take() ?? (0, 0)
    readiness.update(samples: samples, nonzero: nonzero, elapsed: elapsed)
    if samples == 0, monitor != nil {
        missingSeconds += elapsed
        lastError = "no-samples (check microphone permission or device availability)"
        if missingSeconds >= 5 {
            monitor?.stop(); monitor = nil; nextRetry = now + 5; missingSeconds = 0
        }
    } else if samples > 0 { missingSeconds = 0; lastError = "" }
    if boya == nil { lastError = "BOYA receiver absent" }
    let stateKey = "\(readiness.state.rawValue)|\(lastError)"
    if stateKey != lastState { log("readiness=\(readiness.state.rawValue) detail=\(lastError)"); lastState = stateKey }
    let current = uintProperty(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice)
    let target = selectDevice(devices, readiness: readiness.state, lidClosed: lidClosed(), current: current)
    if dryRun {
        if target?.id != lastTarget { log("proposed-input=\(target?.name ?? "none; keep current")"); lastTarget = target?.id }
    } else if let target, current != target.id {
        var p = address(kAudioHardwarePropertyDefaultInputDevice); var id = target.id
        let set = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &p, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id)
        let readback = uintProperty(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice)
        log("switch target=\(target.name) id=\(target.id) result=\(set) verified=\(readback == target.id)")
        if set != noErr || readback != target.id { refreshRequested = true }
    }
    if now >= nextStatus {
        nextStatus = now + 2
        let status: [String: Any] = ["version": version, "pid": ProcessInfo.processInfo.processIdentifier,
            "updatedAt": ISO8601DateFormatter().string(from: Date()), "readiness": readiness.state.rawValue,
            "zeroSeconds": readiness.zeroSeconds, "signalSeconds": readiness.signalSeconds,
            "samplesInWindow": samples, "nonzeroInWindow": nonzero, "monitorDeviceID": monitor?.device ?? 0,
            "error": lastError, "target": target?.name ?? "none", "defaultInput": nameProperty(uintProperty(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice) ?? 0),
            "policy": "2s exact-zero fallback; hardware mute also falls back; 1s signal recovery; not power detection"]
        if let data = try? JSONSerialization.data(withJSONObject: status, options: [.prettyPrinted, .sortedKeys]), !dryRun {
            try? FileManager.default.createDirectory(at: statusURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: statusURL, options: .atomic)
        }
        if dryRun { log("sample-window samples=\(samples) nonzero=\(nonzero) zeroSeconds=\(String(format: "%.1f", readiness.zeroSeconds))") }
    }
    if dryRun && now - started >= duration { monitor?.stop(); log("probe-completed"); exit(0) }
}
timer.resume()
RunLoop.main.run()
