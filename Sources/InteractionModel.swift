import Foundation

struct LightSlideSettings {
    var percent: Int
    var previousSlowPercent: Int
    var mode: ScrollMode
    var onboardingComplete: Bool

    init(values: [String: Any]) {
        let saved = (values["slowFraction"] as? NSNumber)?.doubleValue ?? 0.1
        let valid = saved.isFinite && saved >= 0.01 && saved <= 1 ? saved : 0.1
        percent = Int((valid * 100).rounded())
        let previous = (values["previousSlowPercent"] as? NSNumber)?.intValue ?? (percent < 100 ? percent : 10)
        previousSlowPercent = min(99, max(1, previous))
        mode = (values["scrollMode"] as? String) == ScrollMode.all.rawValue ? .all : .automatic
        // The old pause switch becomes original speed; retain the last slow value for one-click return.
        if (values["disabled"] as? NSNumber)?.boolValue == true { percent = 100 }
        onboardingComplete = (values["compactOnboardingComplete"] as? NSNumber)?.boolValue
            ?? (values["slowFraction"] != nil)
    }

    mutating func setPercent(_ value: Int) {
        percent = min(100, max(1, value))
        if percent < 100 { previousSlowPercent = percent }
    }

    mutating func toggleOriginal() {
        if percent == 100 { percent = previousSlowPercent }
        else { previousSlowPercent = percent; percent = 100 }
    }

    func save(to defaults: UserDefaults) {
        defaults.set(Double(percent) / 100, forKey: "slowFraction")
        defaults.set(previousSlowPercent, forKey: "previousSlowPercent")
        defaults.set(mode.rawValue, forKey: "scrollMode")
        defaults.set(false, forKey: "disabled")
        defaults.set(onboardingComplete, forKey: "compactOnboardingComplete")
        // Login-item preferences are deliberately not part of speed/mode persistence.
    }
}

enum SpeedScale {
    static let presets = [5, 10, 25, 100]
    static func position(percent: Int) -> Double { log10(Double(min(100, max(1, percent)))) / 2 }
    static func percent(position: Double, snap: Bool = true) -> Int {
        let position = min(1, max(0, position.isFinite ? position : 0.5))
        if snap, let preset = presets.min(by: { abs(self.position(percent: $0) - position) < abs(self.position(percent: $1) - position) }),
           abs(self.position(percent: preset) - position) <= 0.018 { return preset }
        return min(100, max(1, Int(pow(10, position * 2).rounded())))
    }
}

enum ScrollSourceKind { case uu, unidentified, other }

/// A conditional suggestion, not proof that an unlabelled event came from UU.
/// Requires positive connection evidence and sustained unidentified movement.
struct RecognitionHealth {
    private var connectedSince: TimeInterval?
    private var unknownTimes: [TimeInterval] = []
    private var lastRecognized: TimeInterval?
    private(set) var suggestsCompatibility = false

    mutating func update(connection: Bool?, eligible: Bool, at now: TimeInterval) {
        guard connection == true, eligible else { self = Self(); return }
        if connectedSince == nil { connectedSince = now }
        unknownTimes.removeAll { now - $0 > 12 || $0 > now }
        guard !suggestsCompatibility, now - (connectedSince ?? now) >= 2,
              unknownTimes.count >= 8, let first = unknownTimes.first, let last = unknownTimes.last,
              last - first >= 3, now - last <= 3,
              lastRecognized.map({ now - $0 > 12 }) ?? true else { return }
        suggestsCompatibility = true
    }

    mutating func record(_ source: ScrollSourceKind, at now: TimeInterval) {
        guard connectedSince != nil else { return }
        switch source {
        case .uu:
            lastRecognized = now; unknownTimes.removeAll(); suggestsCompatibility = false
        case .unidentified:
            unknownTimes.append(now)
            if unknownTimes.count > 256 { unknownTimes.removeFirst(unknownTimes.count - 256) }
        case .other: break
        }
    }
}

/// Only the UU service's active display-sleep assertion counts as connection evidence.
enum UUConnectionEvidence {
    static let names: Set<String> = ["idleDisplaySleepDisabled", "UURemote Disable Display Sleep"]
    static func matches(path: String, name: String, type: String, level: Int) -> Bool {
        path.hasSuffix("/UURemote.app/Contents/Helpers/UURemoteServer") && names.contains(name)
            && type == "PreventUserIdleDisplaySleep" && level == 255
    }
}
