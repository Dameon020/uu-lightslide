import Cocoa
import ApplicationServices

final class ScrollEngine {
    var mode = ScrollMode.automatic
    var fraction = 0.1 { didSet { scaler.reset() } }
    var originalUntil: TimeInterval = 0
    private(set) var observed = 0, uuObserved = 0, adjusted = 0
    private(set) var lastUUTime: TimeInterval = 0
    private(set) var lastSource = "尚未收到滚动"
    private(set) var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var scaler = ScrollScaler()
    private var sourceCache: [Int32: (time: TimeInterval, isUU: Bool, name: String)] = [:]

    var running: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }
    var temporaryOriginal: Bool { ProcessInfo.processInfo.systemUptime < originalUntil }

    @discardableResult func start() -> Bool {
        if running { return true }
        guard AXIsProcessTrusted() else { return false }
        stop()
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        tap = CGEvent.tapCreate(tap: .cgAnnotatedSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<ScrollEngine>.fromOpaque(info).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    engine.scaler.reset()
                    if let tap = engine.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
                return engine.process(event) ? Unmanaged.passUnretained(event) : nil
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return false }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil; scaler.reset()
    }

    private func identify(_ pid: Int32, now: TimeInterval) -> (Bool, String) {
        guard pid > 0 else { return (false, "系统输入（来源未标记）") }
        if let cached = sourceCache[pid], now - cached.time < 2 { return (cached.isUU, cached.name) }
        // PROC_PIDPATHINFO_MAXSIZE is a C expression macro not imported by Swift.
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let size = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        let path = size > 0 ? String(cString: buffer) : ""
        let isUU = UUSource.isUUExecutable(path)
        let name = path.isEmpty ? "未知来源" : URL(fileURLWithPath: path).lastPathComponent
        if sourceCache.count > 64 { sourceCache.removeAll() }
        sourceCache[pid] = (now, isUU, name)
        return (isUU, name)
    }

    // Reads only wheel metadata; never reads keystrokes, page content, or UU accounts.
    @discardableResult func process(_ event: CGEvent) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        let pid = Int32(clamping: event.getIntegerValueField(.eventSourceUnixProcessID))
        let (isUU, name) = identify(pid, now: now)
        observed += 1; lastSource = name
        if isUU { uuObserved += 1; lastUUTime = now }
        let modified = !event.flags.intersection([.maskControl, .maskCommand, .maskAlternate]).isEmpty
        guard ScrollPolicy.shouldScale(mode: mode, isUU: isUU, temporaryOriginal: temporaryOriginal,
                                       modifiedGesture: modified, fraction: fraction) else {
            scaler.reset(); return true
        }
        func pixels(_ point: CGEventField, _ fixed: CGEventField, _ line: CGEventField) -> Double {
            let p = Double(event.getIntegerValueField(point))
            if p != 0 { return p }
            let f = event.getDoubleValueField(fixed)
            // Quartz line events normally expose point deltas too. Fallback: 10 px/line.
            if f != 0 { return f * 10 }
            return Double(event.getIntegerValueField(line)) * 10
        }
        let x = pixels(.scrollWheelEventPointDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventDeltaAxis2)
        let y = pixels(.scrollWheelEventPointDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventDeltaAxis1)
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        if phase & 1 != 0 { scaler.reset() }
        let target = event.getIntegerValueField(.eventTargetUnixProcessID)
        let window = event.getIntegerValueField(.mouseEventWindowUnderMousePointer)
        let loc = event.location
        let context = "\(pid):\(target):\(window):\(Int(loc.x / 32)):\(Int(loc.y / 32))"
        let delta = scaler.scale(x: x, y: y, fraction: fraction, time: now, context: context)
        adjusted += 1
        if delta.x == 0 && delta.y == 0 && phase == 0 && momentum == 0 { return false }
        guard let canonical = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                      wheel1: delta.y, wheel2: delta.x, wheel3: 0) else { return true }
        // Modify in place: preserve targeting, flags, source, gesture phases, and timestamps.
        for field: CGEventField in [.scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2,
                                    .scrollWheelEventDeltaAxis3] {
            event.setIntegerValueField(field, value: canonical.getIntegerValueField(field))
        }
        for field: CGEventField in [.scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2,
                                    .scrollWheelEventFixedPtDeltaAxis3] {
            event.setDoubleValueField(field, value: canonical.getDoubleValueField(field))
        }
        for field: CGEventField in [.scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2,
                                    .scrollWheelEventPointDeltaAxis3] {
            event.setIntegerValueField(field, value: canonical.getIntegerValueField(field))
        }
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        if phase & (4 | 8) != 0 || momentum & 4 != 0 { scaler.reset() }
        return true
    }
}
