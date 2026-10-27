import Foundation
import IOKit.pwr_mgt
import Darwin

// Assertion names and owner validation adapted from Better Remote (pincc), MIT.
// See NOTICE.md. Reads power-assertion metadata only; never UU accounts or page content.
enum RemoteEvidence {
    static func connected() -> Bool? {
        var raw: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&raw) == kIOReturnSuccess,
              let entries = raw?.takeRetainedValue() as? [NSNumber: [[String: Any]]] else { return nil }
        var uncertain = false
        for (pid, values) in entries {
            let relevant = values.filter { value in
                UUConnectionEvidence.names.contains(value[kIOPMAssertionNameKey] as? String ?? "")
                    && (value[kIOPMAssertionTypeKey] as? String) == "PreventUserIdleDisplaySleep"
                    && (value[kIOPMAssertionLevelKey] as? NSNumber)?.intValue == 255
            }
            guard !relevant.isEmpty else { continue }
            var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
            guard proc_pidpath(pid.int32Value, &buffer, UInt32(buffer.count)) > 0 else { uncertain = true; continue }
            let path = String(cString: buffer)
            for value in relevant {
                if UUConnectionEvidence.matches(path: path, name: value[kIOPMAssertionNameKey] as? String ?? "",
                                                type: value[kIOPMAssertionTypeKey] as? String ?? "",
                                                level: (value[kIOPMAssertionLevelKey] as? NSNumber)?.intValue ?? 0) { return true }
            }
        }
        return uncertain ? nil : false
    }
}

/// Runs IOKit sampling off the UI/event-tap run loop. Only the latest sample returns to main.
final class ConnectionMonitor {
    private let queue = DispatchQueue(label: "local.rixin.UUScrollHelper.connection", qos: .utility)
    private var pending = false
    func sample(_ completion: @escaping (Bool?) -> Void) {
        guard !pending else { return }
        pending = true
        queue.async {
            let value = RemoteEvidence.connected()
            DispatchQueue.main.async { self.pending = false; completion(value) }
        }
    }
}
