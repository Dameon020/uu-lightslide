import Foundation

enum ScrollMode: String { case automatic, all, off }

struct ScrollPolicy {
    static func shouldScale(mode: ScrollMode, isUU: Bool, temporaryOriginal: Bool,
                            modifiedGesture: Bool, fraction: Double) -> Bool {
        guard !temporaryOriginal, !modifiedGesture, fraction < 0.999 else { return false }
        switch mode {
        case .automatic: return isUU
        case .all: return true
        case .off: return false
        }
    }
}

// Keep subpixel movement instead of rounding every small wheel event to zero.
// Residues never carry across a pause, direction change, source, or target.
struct ScrollScaler {
    private var rx = 0.0, ry = 0.0
    private var lastX = 0.0, lastY = 0.0
    private var lastTime = -Double.infinity
    private var lastContext = ""
    mutating func reset() { self = ScrollScaler() }
    mutating func scale(x: Double, y: Double, fraction: Double,
                        time: Double, context: String) -> (x: Int32, y: Int32) {
        if context != lastContext || time - lastTime > 0.35 || time < lastTime {
            rx = 0; ry = 0; lastX = 0; lastY = 0
        }
        if x * lastX < 0 { rx = 0 }
        if y * lastY < 0 { ry = 0 }
        let f = min(1, max(0.01, fraction.isFinite ? fraction : 0.1))
        rx += (x.isFinite ? x : 0) * f
        ry += (y.isFinite ? y : 0) * f
        let ix = Int32(max(Double(Int32.min), min(Double(Int32.max), rx.rounded(.towardZero))))
        let iy = Int32(max(Double(Int32.min), min(Double(Int32.max), ry.rounded(.towardZero))))
        rx -= Double(ix); ry -= Double(iy)
        if x != 0 { lastX = x }; if y != 0 { lastY = y }
        lastTime = time; lastContext = context
        return (ix, iy)
    }
}

enum UUSource {
    static func isUUExecutable(_ path: String) -> Bool {
        // Identify the installed application's components, never just a process name.
        let marker = "/UURemote.app/Contents/"
        guard let range = path.range(of: marker) else { return false }
        let suffix = String(path[range.upperBound...])
        return ["MacOS/UURemote", "MacOS/UURemoteService", "MacOS/UURemoteDaemon",
                "Helpers/UURemoteServer",
                "XPCServices/UURemoteHelper.xpc/Contents/MacOS/UURemoteHelper"].contains(suffix)
    }
}
