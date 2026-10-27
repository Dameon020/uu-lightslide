import Cocoa
import ApplicationServices

var count = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    if !condition() { fputs("FAIL: \(name)\n", stderr); exit(1) }
    count += 1
}
var s = ScrollScaler()
var total = 0
for i in 0..<1000 {
    total += Int(s.scale(x: 0, y: 1, fraction: 0.01, time: Double(i) * 0.001, context: "a").y)
}
check(abs(total - 10) <= 1, "1% preserves accumulated subpixels")
s.reset()
check(s.scale(x: 100, y: -120, fraction: 0.1, time: 1, context: "a").y == -12, "negative direction and ratio")
s.reset()
_ = s.scale(x: 0, y: 9, fraction: 0.1, time: 1, context: "a")
check(s.scale(x: 0, y: -10, fraction: 0.1, time: 1.1, context: "a").y == -1, "reverse clears residue")
s.reset()
_ = s.scale(x: 0, y: 9, fraction: 0.1, time: 1, context: "a")
check(s.scale(x: 0, y: 2, fraction: 0.1, time: 1.1, context: "b").y == 0, "target change clears residue")
check(s.scale(x: 0, y: 8, fraction: 0.1, time: 2, context: "b").y == 0, "pause clears residue")
check(UUSource.isUUExecutable("/Applications/UURemote.app/Contents/Helpers/UURemoteServer"), "UU server recognized")
check(!UUSource.isUUExecutable("/Applications/Other.app/Contents/MacOS/UURemoteServer"), "same name elsewhere rejected")
check(!UUSource.isUUExecutable("/Applications/UURemote.app/Contents/Helpers/Unknown"), "unknown component rejected")
for mode: ScrollMode in [.automatic, .all, .off] {
    for isUU in [false, true] {
        let result = ScrollPolicy.shouldScale(mode: mode, isUU: isUU, temporaryOriginal: false, modifiedGesture: false, fraction: 0.1)
        check(result == (mode == .all || (mode == .automatic && isUU)), "mode/source policy")
        check(!ScrollPolicy.shouldScale(mode: mode, isUU: isUU, temporaryOriginal: true, modifiedGesture: false, fraction: 0.1), "temporary original bypass")
        check(!ScrollPolicy.shouldScale(mode: mode, isUU: isUU, temporaryOriginal: false, modifiedGesture: true, fraction: 0.1), "zoom modifier bypass")
    }
}
func wheel(_ amount: Int32, units: CGScrollEventUnit = .pixel) -> CGEvent {
    CGEvent(scrollWheelEvent2Source: nil, units: units, wheelCount: 2, wheel1: amount, wheel2: 0, wheel3: 0)!
}
let e = ScrollEngine()
e.mode = .all; e.fraction = 0.1
let w = wheel(-120)
w.location = CGPoint(x: 333, y: 222)
check(e.process(w), "event retained")
check(w.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -12, "pixel event scaled")
check(w.location == CGPoint(x: 333, y: 222), "target coordinates retained")
check(w.getIntegerValueField(.scrollWheelEventIsContinuous) == 1, "continuous output")
let line = wheel(12, units: .line)
check(e.process(line), "line retained")
check(line.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 12, "line converted using points")
let zoom = wheel(100); zoom.flags = .maskControl
check(e.process(zoom) && zoom.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 100, "ctrl scroll untouched")
e.mode = .automatic
let local = wheel(100)
check(e.process(local) && local.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 100, "non-UU source untouched")
e.mode = .all; e.originalUntil = ProcessInfo.processInfo.systemUptime + 30
let fast = wheel(100)
check(e.process(fast) && fast.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 100, "fast timer bypass")
e.originalUntil = ProcessInfo.processInfo.systemUptime - 1
let resumed = wheel(100)
check(e.process(resumed) && resumed.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 10, "fast timer expiration restores")
let ended = wheel(0); ended.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
check(e.process(ended), "zero delta gesture ending retained")
check(ended.getIntegerValueField(.scrollWheelEventScrollPhase) == 4, "gesture end preserved")
if let argument = CommandLine.arguments.dropFirst().first, let pid = Int64(argument) {
    e.mode = .automatic
    let remote = wheel(120); remote.setIntegerValueField(.eventSourceUnixProcessID, value: pid)
    check(e.process(remote) && remote.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 12, "real installed UU process path identified")
    check(e.uuObserved == 1, "UU counter updated")
}
print("PASS: \(count) assertions. Synthetic events only; real UU gesture test remains pending.")
