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
        let result = ScrollPolicy.shouldScale(mode: mode, isUU: isUU, modifiedGesture: false, fraction: 0.1)
        check(result == (mode == .all || (mode == .automatic && isUU)), "mode/source policy")
        check(!ScrollPolicy.shouldScale(mode: mode, isUU: isUU, modifiedGesture: false, fraction: 1), "original speed bypass")
        check(!ScrollPolicy.shouldScale(mode: mode, isUU: isUU, modifiedGesture: true, fraction: 0.1), "zoom modifier bypass")
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
e.mode = .all; e.fraction = 1
let fast = wheel(100)
check(e.process(fast) && fast.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 100, "original speed bypass")
e.fraction = 0.1
let resumed = wheel(100)
check(e.process(resumed) && resumed.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 10, "selecting slow speed restores scaling")
let ended = wheel(0); ended.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
check(e.process(ended), "zero delta gesture ending retained")
check(ended.getIntegerValueField(.scrollWheelEventScrollPhase) == 4, "gesture end preserved")
if let argument = CommandLine.arguments.dropFirst().first, let pid = Int64(argument) {
    e.mode = .automatic
    let remote = wheel(120); remote.setIntegerValueField(.eventSourceUnixProcessID, value: pid)
    check(e.process(remote) && remote.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 12, "real installed UU process path identified")
    check(e.uuObserved == 1, "UU counter updated")
}


// Migration and one source of truth for speed.
var prefs = LightSlideSettings(values: ["slowFraction": 0.5, "scrollMode": "all", "loginConfigured": true])
check(prefs.percent == 50 && prefs.mode == .all, "50% and compatibility survive migration")
check(!SpeedScale.presets.contains(prefs.percent), "custom50 has no selected preset")
check(prefs.onboardingComplete, "existing users are not forced through onboarding")
prefs.toggleOriginal()
check(prefs.percent == 100 && prefs.previousSlowPercent == 50, "original remembers custom speed")
prefs.toggleOriginal()
check(prefs.percent == 50, "original toggles back to previous slow speed")
var paused = LightSlideSettings(values: ["slowFraction": 0.05, "disabled": true])
check(paused.percent == 100 && paused.previousSlowPercent == 5, "old paused preference becomes original")
paused.toggleOriginal(); check(paused.percent == 5, "paused legacy restores previous speed")
let fresh = LightSlideSettings(values: [:])
check(fresh.percent == 10 && !fresh.onboardingComplete && fresh.mode == .automatic, "new install enters onboarding")
let suiteName = "local.rixin.UUScrollHelper.test-" + UUID().uuidString
let testDefaults = UserDefaults(suiteName: suiteName)!
testDefaults.set(false, forKey: "loginConfigured")
prefs.save(to: testDefaults)
let roundtrip = LightSlideSettings(values: testDefaults.dictionaryRepresentation())
check(roundtrip.percent == 50 && roundtrip.mode == .all, "speed and compatibility persist")
check(testDefaults.bool(forKey: "loginConfigured") == false, "saving speed does not alter login preference")
testDefaults.removePersistentDomain(forName: suiteName)
for value in [1, 5, 10, 25, 50, 99, 100] {
    check(SpeedScale.percent(position: SpeedScale.position(percent: value), snap: false) == value, "log mapping roundtrip")
}
for value in SpeedScale.presets {
    check(SpeedScale.percent(position: SpeedScale.position(percent: value) - 0.01) == value, "preset snaps from below")
    check(SpeedScale.percent(position: SpeedScale.position(percent: value) + 0.01) == value, "preset snaps from above")
}
check(SpeedScale.percent(position: SpeedScale.position(percent: 50)) == 50, "50% never snaps to a preset")

func unidentifiedBurst(_ health: inout RecognitionHealth, from start: Double) {
    for i in 0..<8 {
        let time = start + Double(i) * 0.5
        health.record(.unidentified, at: time)
        health.update(connection: true, eligible: true, at: time)
    }
}
var health = RecognitionHealth()
health.update(connection: true, eligible: true, at: 0)
unidentifiedBurst(&health, from: 3)
check(health.suggestsCompatibility, "sustained unknown scrolling during positive connection suggests compatibility")
health.record(.uu, at: 7)
check(!health.suggestsCompatibility, "recognized UU scrolling clears hint immediately")
unidentifiedBurst(&health, from: 8)
check(!health.suggestsCompatibility, "recent recognized input prevents misleading hint")
health.update(connection: nil, eligible: true, at: 13)
check(!health.suggestsCompatibility, "unknown connection clears hint")
var disconnected = RecognitionHealth()
for i in 0..<15 {
    disconnected.record(.unidentified, at: Double(i))
    disconnected.update(connection: false, eligible: true, at: Double(i))
}
check(!disconnected.suggestsCompatibility, "ordinary unmarked local input never claims UU failure")
var other = RecognitionHealth()
other.update(connection: true, eligible: true, at: 0)
for i in 0..<15 { other.record(.other, at: Double(i)); other.update(connection: true, eligible: true, at: Double(i)) }
check(!other.suggestsCompatibility, "known other applications are not counted as unmarked UU input")
var sparse = RecognitionHealth()
sparse.update(connection: true, eligible: true, at: 0)
sparse.record(.unidentified, at: 3); sparse.update(connection: true, eligible: true, at: 10)
check(!sparse.suggestsCompatibility, "single unknown event does not prompt")
var inactive = RecognitionHealth()
inactive.update(connection: true, eligible: true, at: 0)
unidentifiedBurst(&inactive, from: 3)
inactive.update(connection: true, eligible: false, at: 7)
check(!inactive.suggestsCompatibility, "original/compatible/untrusted mode clears hint")
var stale = RecognitionHealth()
stale.update(connection: true, eligible: true, at: 0)
for i in 0..<8 { stale.record(.unidentified, at: 3 + Double(i) * 0.5) }
stale.update(connection: true, eligible: true, at: 30)
check(!stale.suggestsCompatibility, "old scrolling cannot trigger a later prompt")
let uuPath = "/Applications/UURemote.app/Contents/Helpers/UURemoteServer"
check(UUConnectionEvidence.matches(path: uuPath, name: "UURemote Disable Display Sleep", type: "PreventUserIdleDisplaySleep", level: 255), "active UU display assertion is evidence")
check(!UUConnectionEvidence.matches(path: uuPath, name: "UURemote Disable Idle System Sleep", type: "PreventUserIdleSystemSleep", level: 255), "resident UU process is not a connection")
check(!UUConnectionEvidence.matches(path: "/tmp/UURemoteServer", name: "UURemote Disable Display Sleep", type: "PreventUserIdleDisplaySleep", level: 255), "unrelated assertion owner rejected")
check(!UUConnectionEvidence.matches(path: uuPath, name: "UURemote Disable Display Sleep", type: "PreventUserIdleDisplaySleep", level: 0), "inactive assertion rejected")
// Direction changes are independent per axis, at both original and reduced speeds.
check(!fresh.reverseX && !fresh.reverseY, "legacy settings preserve directions")
prefs.reverseX = true; prefs.reverseY = true
prefs.save(to: testDefaults)
let savedDirection = LightSlideSettings(values: testDefaults.dictionaryRepresentation())
check(savedDirection.reverseX && savedDirection.reverseY, "directions persist across reload")
testDefaults.removePersistentDomain(forName: suiteName)
for fraction in [0.1, 1.0] {
    for rx in [false, true] {
        for ry in [false, true] {
            let engine = ScrollEngine(); engine.mode = .all; engine.fraction = fraction
            engine.reverseX = rx; engine.reverseY = ry
            let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 3, wheel1: 120, wheel2: -80, wheel3: 0)!
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 2)
            event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 2)
            let timestamp = event.timestamp
            check(engine.process(event), "direction event retained")
            check(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == Int64(120 * fraction) * (ry ? -1 : 1), "vertical direction and scale")
            check(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == Int64(-80 * fraction) * (rx ? -1 : 1), "horizontal direction and scale")
            check(event.timestamp == timestamp && event.getIntegerValueField(.scrollWheelEventScrollPhase) == 2 && event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 2, "gesture metadata survives reversal")
        }
    }
}
let directionEngine = ScrollEngine(); directionEngine.mode = .all; directionEngine.fraction = 1
directionEngine.reverseY = true
let fractionalLine = wheel(3, units: .line)
fractionalLine.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0.375)
let originalPoints = fractionalLine.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
let originalLines = fractionalLine.getIntegerValueField(.scrollWheelEventDeltaAxis1)
let originalContinuous = fractionalLine.getIntegerValueField(.scrollWheelEventIsContinuous)
check(directionEngine.process(fractionalLine), "original line event retained")
check(fractionalLine.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == -0.375, "original fractional delta reversed exactly")
check(fractionalLine.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -originalPoints && fractionalLine.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -originalLines, "original line and point fields agree")
check(fractionalLine.getIntegerValueField(.scrollWheelEventIsContinuous) == originalContinuous, "original units preserved")
for flag: CGEventFlags in [.maskControl, .maskCommand, .maskAlternate] {
    let modified = wheel(100); modified.flags = flag
    check(directionEngine.process(modified) && modified.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 100, "modified gestures not reversed")
}
for mode: ScrollMode in [.automatic, .off] {
    directionEngine.mode = mode
    let local = wheel(100)
    check(directionEngine.process(local) && local.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 100, "source and disabled scope honored for reversal")
}
directionEngine.mode = .all; directionEngine.fraction = 0.1; directionEngine.reverseY = false
_ = directionEngine.process(wheel(9))
directionEngine.reverseY = true
let afterToggle = wheel(10)
check(directionEngine.process(afterToggle) && afterToggle.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -1, "changing direction clears fractional residue")
let reverseEnd = wheel(0); reverseEnd.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
check(directionEngine.process(reverseEnd) && reverseEnd.getIntegerValueField(.scrollWheelEventScrollPhase) == 4, "reversed gesture ending preserved")
// Shift + a discrete vertical wheel must remain horizontal after pixel conversion.
for speed in [1.0, 0.1, 0.05] {
    for rx in [false, true] {
        for ry in [false, true] {
            let engine = ScrollEngine(); engine.mode = .all; engine.fraction = speed
            engine.reverseX = rx; engine.reverseY = ry
            let shifted = wheel(20, units: .line); shifted.flags = .maskShift
            let input = shifted.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
            let stamp = shifted.timestamp
            check(engine.process(shifted), "shift wheel retained")
            check(shifted.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 0, "shift wheel has no vertical drift")
            check(shifted.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == Int64(Double(input) * speed) * (rx ? -1 : 1), "shift wheel follows horizontal reversal at every speed")
            check(!shifted.flags.contains(.maskShift) && shifted.timestamp == stamp, "converted shift consumed once; timestamp preserved")
            let cocoa = NSEvent(cgEvent: shifted)!
            check(cocoa.scrollingDeltaX != 0 && cocoa.scrollingDeltaY == 0, "AppKit receives horizontal movement")
        }
    }
}
for mode: ScrollMode in [.automatic, .off] {
    let engine = ScrollEngine(); engine.mode = mode; engine.reverseX = true
    let shifted = wheel(20, units: .line); shifted.flags = .maskShift
    let input = shifted.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
    check(engine.process(shifted) && shifted.flags.contains(.maskShift) && shifted.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == input, "shift conversion respects source filtering")
}
for modifier: CGEventFlags in [.maskControl, .maskCommand, .maskAlternate] {
    let engine = ScrollEngine(); engine.mode = .all; engine.reverseX = true
    let shifted = wheel(20, units: .line); shifted.flags = [.maskShift, modifier]
    let input = shifted.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
    check(engine.process(shifted) && shifted.flags.contains(.maskShift) && shifted.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == input, "shift plus zoom modifiers bypass unchanged")
}
let nativeEngine = ScrollEngine(); nativeEngine.mode = .all; nativeEngine.fraction = 0.1
nativeEngine.reverseX = true
let nativeHorizontal = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 0, wheel2: 20, wheel3: 0)!
nativeHorizontal.flags = .maskShift
let nativeInput = nativeHorizontal.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
check(nativeEngine.process(nativeHorizontal) && nativeHorizontal.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == -Int64(Double(nativeInput) * 0.1) && nativeHorizontal.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 0, "already horizontal shift input is not swapped again")
let precise = wheel(100); precise.flags = .maskShift
check(nativeEngine.process(precise) && precise.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 10 && precise.flags.contains(.maskShift), "precise trackpad-like input keeps existing shift behavior")
let residueEngine = ScrollEngine(); residueEngine.mode = .all; residueEngine.fraction = 0.05
func smallDiscrete(_ shifted: Bool) -> CGEvent {
    let event = wheel(1, units: .line)
    event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: 0)
    event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0.9)
    event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 9)
    if shifted { event.flags = .maskShift }
    return event
}
_ = residueEngine.process(smallDiscrete(true))
_ = residueEngine.process(smallDiscrete(false))
let afterShiftChange = smallDiscrete(true)
check(!residueEngine.process(afterShiftChange), "shift transitions do not leak old residual movement")
print("PASS: \(count) assertions. Synthetic events/model tests; real phone/iPad acceptance remains separate.")
