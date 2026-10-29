import Cocoa
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = ScrollEngine()
    let defaults = UserDefaults.standard
    var settings = LightSlideSettings(values: [:])
    let panel = CompactPanel()
    let popover = NSPopover()
    let connectionMonitor = ConnectionMonitor()
    var status: NSStatusItem!
    var timer: Timer?
    var lastTrusted = false
    var connection: Bool?
    var sampledAt = -Double.infinity
    var requestedAt = -Double.infinity
    var loginError: String?
    var onboardingSpeedChosen = false
    var onboardingUUStart = 0
    var onboardingAdjustedStart = 0
    var onboardingConfirmedAt: TimeInterval?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if (try? Bundle.main.bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly == true {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "请先将 UU 轻滑拖入“应用程序”"
            alert.informativeText = "复制后推出安装磁盘，再从“应用程序”打开，以便保存授权和自动启动设置。"
            alert.addButton(withTitle: "知道了"); alert.runModal()
            NSApp.terminate(nil); return
        }
        settings = LightSlideSettings(values: defaults.dictionaryRepresentation())
        settings.save(to: defaults)
        applySettings()
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.target = self; status.button?.action = #selector(statusClicked)
        status.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let icon = NSImage(systemSymbolName: "arrow.up.and.down", accessibilityDescription: "UU 轻滑")
        icon?.size = NSSize(width: 15, height: 17); icon?.isTemplate = true
        status.button?.image = icon; status.button?.imagePosition = .imageLeading
        _ = panel.view
        panel.slider.target = self; panel.slider.action = #selector(speedChanged)
        panel.presets.target = self; panel.presets.action = #selector(presetChanged)
        panel.compatibility.target = self; panel.compatibility.action = #selector(useAutomatic)
        panel.compatibilityButton.target = self; panel.compatibilityButton.action = #selector(useCompatibility)
        panel.permissionButton.target = self; panel.permissionButton.action = #selector(authorize)
        panel.reverseVertical.target = self; panel.reverseVertical.action = #selector(directionChanged)
        panel.reverseHorizontal.target = self; panel.reverseHorizontal.action = #selector(directionChanged)
        panel.more.target = self; panel.more.action = #selector(showMore)
        panel.resized = { [weak self] size in self?.popover.contentSize = size }
        popover.contentViewController = panel; popover.behavior = .transient
        // Existing explicit login choices are not changed by this UI migration.
        if !defaults.bool(forKey: "loginConfigured") {
            do { try SMAppService.mainApp.register(); defaults.set(true, forKey: "loginConfigured") }
            catch { loginError = "自动启动未设置，可在更多菜单中重试。" }
        }
        refresh()
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
        if !settings.onboardingComplete || !engine.running { DispatchQueue.main.async { self.showPopover() } }
    }

    private func applySettings() {
        engine.reverseX = settings.reverseX; engine.reverseY = settings.reverseY
        engine.mode = settings.mode
        engine.fraction = Double(settings.percent) / 100
    }

    @objc func statusClicked() {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            guard AXIsProcessTrusted(), engine.running else { showPopover(); return }
            settings.toggleOriginal(); saveAndRefresh()
        } else if popover.isShown { popover.performClose(nil) }
        else { showPopover() }
    }

    func showPopover() {
        guard let button = status.button else { return }
        refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func refresh() {
        let now = ProcessInfo.processInfo.systemUptime
        let trusted = AXIsProcessTrusted()
        if !trusted { engine.stop() }
        else if !lastTrusted || !engine.running {
            // A failed/untrusted tap never recovers by itself after the user grants access.
            engine.stop(); engine.start()
        }
        lastTrusted = trusted
        let eligible = trusted && engine.running && settings.mode == .automatic && (settings.percent < 100 || settings.reverseX || settings.reverseY)
        if eligible, now - requestedAt >= 2 {
            requestedAt = now
            connectionMonitor.sample { [weak self] value in
                self?.connection = value
                self?.sampledAt = ProcessInfo.processInfo.systemUptime
            }
        }
        let currentConnection = now - sampledAt < 5 ? connection : nil
        engine.recognition.update(connection: currentConnection, eligible: eligible, at: now)
        let onboarding = onboardingMessage(trusted: trusted, now: now)
        panel.update(percent: settings.percent, mode: settings.mode, authorized: trusted, running: engine.running,
                     suggestion: engine.recognition.suggestsCompatibility, onboarding: onboarding,
                     reverseX: settings.reverseX, reverseY: settings.reverseY)
        let reducing = trusted && engine.running && settings.percent < 100
        status.button?.title = reducing ? " \(settings.percent)%" : ""
        let mode = settings.mode == .all ? "兼容模式（也影响本机）" : "自动识别 UU"
        status.button?.toolTip = "UU 轻滑 · \(mode) · \(settings.percent)%\n⌥ 点按切换原速与上次速度"
        status.button?.setAccessibilityLabel("UU 轻滑，\(mode)，\(settings.percent)%")
    }

    private func onboardingMessage(trusted: Bool, now: TimeInterval) -> String? {
        guard !settings.onboardingComplete else { return nil }
        guard trusted && engine.running else { return "1/3 · 开启辅助功能" }
        guard onboardingSpeedChosen else { return "2/3 · 选一个适合阅读的速度" }
        let recognized = engine.uuObserved > onboardingUUStart
        let compatible = settings.mode == .all && engine.adjusted > onboardingAdjustedStart
        if recognized || compatible {
            if onboardingConfirmedAt == nil { onboardingConfirmedAt = now }
            if now - (onboardingConfirmedAt ?? now) >= 3 {
                settings.onboardingComplete = true; settings.save(to: defaults)
                return nil
            }
            return recognized ? "已识别到 UU 滚动 ✓" : "已调整滚动 ✓（兼容模式）"
        }
        return "3/3 · 去 UU 里滚一下\n等待 UU 滚动…"
    }

    private func saveAndRefresh() { applySettings(); settings.save(to: defaults); refresh() }
    private func chooseSpeed(_ percent: Int, toggleOriginal: Bool = false) {
        guard AXIsProcessTrusted(), engine.running else { refresh(); return }
        if toggleOriginal { settings.toggleOriginal() } else { settings.setPercent(percent) }
        if !settings.onboardingComplete, !onboardingSpeedChosen, settings.percent < 100 {
            onboardingSpeedChosen = true
            onboardingUUStart = engine.uuObserved; onboardingAdjustedStart = engine.adjusted
        }
        saveAndRefresh()
    }
    @objc func directionChanged() {
        guard AXIsProcessTrusted(), engine.running else { refresh(); return }
        settings.reverseX = panel.reverseHorizontal.state == .on
        settings.reverseY = panel.reverseVertical.state == .on
        saveAndRefresh()
    }
    @objc func speedChanged() { chooseSpeed(SpeedScale.percent(position: panel.slider.doubleValue)) }
    @objc func presetChanged() {
        let index = panel.presets.selectedSegment
        guard SpeedScale.presets.indices.contains(index) else { return }
        chooseSpeed(SpeedScale.presets[index], toggleOriginal: index == 3)
    }
    @objc func useAutomatic() { settings.mode = .automatic; saveAndRefresh() }
    @objc func useCompatibility() { settings.mode = .all; saveAndRefresh() }

    @objc func authorize() {
        if AXIsProcessTrusted() { engine.stop(); engine.start(); refresh(); return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func openPermissions() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
    }

    private func item(_ title: String, action: Selector, checked: Bool? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let checked { item.state = checked ? .on : .off }
        return item
    }
    @objc func showMore() {
        let menu = NSMenu(); menu.autoenablesItems = false
        menu.addItem(item("登录 Mac 时自动启动", action: #selector(loginChanged), checked: SMAppService.mainApp.status == .enabled))
        let advanced = NSMenu()
        advanced.addItem(item("自动识别 UU", action: #selector(useAutomatic), checked: settings.mode == .automatic))
        advanced.addItem(item("兼容模式（也影响本机）", action: #selector(useCompatibility), checked: settings.mode == .all))
        let modes = NSMenuItem(title: "高级设置", action: nil, keyEquivalent: ""); modes.submenu = advanced
        menu.addItem(modes)
        menu.addItem(item("诊断信息…", action: #selector(showDiagnostics)))
        menu.addItem(item("辅助功能设置…", action: #selector(openPermissions)))
        menu.addItem(.separator())
        menu.addItem(item("使用引导", action: #selector(restartOnboarding)))
        menu.addItem(item("使用说明", action: #selector(showHelp)))
        menu.addItem(.separator())
        let quitItem = item("退出 UU 轻滑", action: #selector(quit)); quitItem.keyEquivalent = "q"
        menu.addItem(quitItem)
        // Let the accessibility/button action return before entering native menu tracking.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: self.panel.more.bounds.minY - 4), in: self.panel.more)
        }
    }
    @objc func loginChanged() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            else { try SMAppService.mainApp.register() }
            defaults.set(true, forKey: "loginConfigured"); loginError = nil
        } catch {
            loginError = "自动启动设置失败：\(error.localizedDescription)"
            let alert = NSAlert(); alert.messageText = "自动启动未更新"; alert.informativeText = loginError!
            alert.runModal()
        }
    }
    @objc func showDiagnostics() {
        let evidence: String
        switch connection { case true?: evidence = "检测到 UU 连接信号"; case false?: evidence = "未检测到 UU 连接信号"; case nil: evidence = "连接信号未知" }
        let alert = NSAlert(); alert.messageText = "UU 轻滑 · 诊断信息"
        alert.informativeText = "\(evidence)\n辅助功能：\(AXIsProcessTrusted() ? "已授权" : "未授权")\n滚动监听：\(engine.running ? "运行中" : "未启动")\nUU 事件：\(engine.uuObserved) · 已调整：\(engine.adjusted)\n最近来源：\(engine.lastSource)\n\n来源未标记的事件也可能来自本机，不代表 UU 识别一定失败。" + (loginError.map { "\n\($0)" } ?? "")
        alert.addButton(withTitle: "关闭")
        DispatchQueue.main.async { alert.runModal() }
    }
    @objc func restartOnboarding() {
        settings.onboardingComplete = false; onboardingSpeedChosen = false; onboardingConfirmedAt = nil
        saveAndRefresh()
    }
    @objc func showHelp() {
        if let url = Bundle.main.url(forResource: "guide", withExtension: "html") { NSWorkspace.shared.open(url) }
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); engine.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { showPopover() }; return true
    }
}

// Deterministic offscreen review: no input tap, login-item registration or user preference writes.
func renderUI(to folder: String) throws {
    let url = URL(fileURLWithPath: folder, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    let cases: [(String, Int, ScrollMode, Bool, Bool, Bool, String?)] = [
        ("reversed", 5, .automatic, true, true, false, nil),
        ("reverse-original", 100, .automatic, true, true, false, nil),
        ("normal", 5, .automatic, true, true, false, nil),
        ("custom50", 50, .automatic, true, true, false, nil),
        ("original", 100, .automatic, true, true, false, nil),
        ("compatible", 5, .all, true, true, false, nil),
        ("permission", 5, .automatic, false, false, false, nil),
        ("recognition", 5, .automatic, true, true, true, nil),
        ("tap-retry", 5, .automatic, true, false, false, nil),
        ("onboarding", 10, .automatic, true, true, false, "3/3 · 去 UU 里滚一下\n等待 UU 滚动…"),
        ("confirmed", 10, .automatic, true, true, false, "已识别到 UU 滚动 ✓")
    ]
    for (theme, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
        for (name, percent, mode, authorized, running, hint, onboarding) in cases {
            let panel = CompactPanel()
            let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 270, height: 184), styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.appearance = NSAppearance(named: appearance)
            window.contentViewController = panel
            panel.update(percent: percent, mode: mode, authorized: authorized, running: running, suggestion: hint, onboarding: onboarding, reverseX: name == "reversed", reverseY: name == "reversed" || name == "reverse-original")
            let expectedSegment = SpeedScale.presets.firstIndex(of: percent) ?? -1
            guard panel.presets.selectedSegment == expectedSegment,
                  panel.slider.isEnabled == (authorized && running),
                  panel.presets.isEnabled == (authorized && running),
                  panel.reverseVertical.isEnabled == (authorized && running),
                  panel.reverseHorizontal.state == (name == "reversed" ? .on : .off),
                  panel.reverseVertical.state == (name == "reversed" || name == "reverse-original" ? .on : .off),
                  panel.compatibility.isHidden == (mode != .all) else {
                throw NSError(domain: "CompactUI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid state: \(name)"])
            }
            window.setContentSize(panel.view.frame.size)
            for _ in 0..<3 { panel.view.layoutSubtreeIfNeeded(); RunLoop.main.run(until: Date().addingTimeInterval(0.08)) }
            guard let bitmap = panel.view.bitmapImageRepForCachingDisplay(in: panel.view.bounds) else { continue }
            panel.view.cacheDisplay(in: panel.view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: url.appendingPathComponent("\(name)-\(theme).png"))
            print("UI \(name)-\(theme) \(Int(panel.view.frame.width))x\(Int(panel.view.frame.height))")
            window.close()
        }
    }
}

let app = NSApplication.shared
let args = Array(CommandLine.arguments.dropFirst())
if args.count == 2, args[0] == "--render-ui" {
    app.setActivationPolicy(.prohibited)
    do { try renderUI(to: args[1]) } catch { fputs("UI render failed: \(error)\n", stderr); exit(1) }
} else {
    let delegate = AppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
