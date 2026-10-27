import Cocoa
import ApplicationServices
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    let engine = ScrollEngine()
    let defaults = UserDefaults.standard
    var status: NSStatusItem!
    let popover = NSPopover()
    var timer: Timer?
    let stateLabel = NSTextField(wrappingLabelWithString: "")
    let valueLabel = NSTextField(labelWithString: "")
    let detailLabel = NSTextField(wrappingLabelWithString: "")
    let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
    let modePicker = NSPopUpButton()
    let fastButton = NSButton(title: "原速 30 秒", target: nil, action: nil)
    let authButton = NSButton(title: "授权辅助功能…", target: nil, action: nil)
    let loginButton = NSButton(checkboxWithTitle: "登录 Mac 时自动启动", target: nil, action: nil)
    var loginError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // A DMG is an installer container, not a permanent place for the login item.
        if (try? Bundle.main.bundleURL.resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly == true {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "请先将 UU 轻滑拖入“应用程序”"
            alert.informativeText = "当前应用位于只读安装磁盘。请完成复制、推出安装磁盘，再从“应用程序”打开，以便保存授权和自动启动设置。"
            alert.addButton(withTitle: "知道了")
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        let saved = defaults.double(forKey: "slowFraction")
        engine.fraction = saved >= 0.01 && saved <= 1 ? saved : 0.1
        // Compatibility mode is deliberately session-only; never slow the local mouse on next launch.
        engine.mode = defaults.bool(forKey: "disabled") ? .off : .automatic
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.target = self; status.button?.action = #selector(togglePopover)
        status.button?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let menuIcon = NSImage(systemSymbolName: "arrow.up.and.down", accessibilityDescription: "UU 轻滑")
        menuIcon?.size = NSSize(width: 15, height: 17)
        menuIcon?.isTemplate = true
        status.button?.image = menuIcon
        status.button?.imagePosition = .imageLeading
        status.button?.toolTip = "UU 轻滑：调整远程滑动速度"
        makeUI()
        // Refresh the registered bundle URL after the display-name/path migration.
        // An explicitly disabled login item stays disabled.
        if !defaults.bool(forKey: "appearanceV2LoginMigrated"), SMAppService.mainApp.status == .enabled {
            do {
                try SMAppService.mainApp.unregister()
                try SMAppService.mainApp.register()
                defaults.set(true, forKey: "appearanceV2LoginMigrated")
            } catch { loginError = "请重新勾选登录自动启动以更新应用位置。" }
        }
        if !defaults.bool(forKey: "loginConfigured") {
            do {
                try SMAppService.mainApp.register()
                defaults.set(true, forKey: "loginConfigured")
            } catch { loginError = "自动启动未设置，可勾选后重试。" }
        }
        engine.start()
        refresh()
        timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
        let showAppearanceUpdate = !defaults.bool(forKey: "appearanceV2Shown")
        defaults.set(true, forKey: "appearanceV2Shown")
        if !engine.running || showAppearanceUpdate { DispatchQueue.main.async { self.togglePopover() } }
    }

    private func label(_ text: String, size: CGFloat = 13, bold: Bool = false) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        return l
    }
    private func button(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded; b.controlSize = .large
        return b
    }
    private func row(_ views: [NSView]) -> NSStackView {
        let s = NSStackView(views: views); s.orientation = .horizontal; s.spacing = 8
        s.distribution = .fillEqually; return s
    }
    func makeUI() {
        let vc = NSViewController()
        vc.view = NSView(frame: NSRect(x: 0, y: 0, width: 356, height: 470))
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: vc.view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -20)
        ])
        func add(_ v: NSView, full: Bool = true) {
            stack.addArrangedSubview(v)
            if full { v.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        }
        let header = NSStackView()
        header.orientation = .horizontal; header.spacing = 10
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            let iconView = NSImageView(image: icon)
            iconView.widthAnchor.constraint(equalToConstant: 38).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 38).isActive = true
            header.addArrangedSubview(iconView)
        }
        header.addArrangedSubview(label("UU 轻滑", size: 22, bold: true))
        add(header)
        stateLabel.font = .systemFont(ofSize: 12); stateLabel.textColor = .secondaryLabelColor
        add(stateLabel)
        add(valueLabel)
        valueLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        slider.target = self; slider.action = #selector(speedChanged); slider.isContinuous = true
        slider.doubleValue = (log10(engine.fraction) + 2) / 2
        add(slider)
        let presets = row([button("很慢 5%", #selector(preset5)), button("慢速 10%", #selector(preset10)), button("较快 50%", #selector(preset50))])
        add(presets)
        fastButton.target = self; fastButton.action = #selector(temporaryFast); fastButton.bezelStyle = .rounded
        fastButton.controlSize = .large
        add(fastButton)
        modePicker.addItems(withTitles: ["自动：只减速 UU 远程输入", "兼容：全部滚动减速（本次）", "暂停减速"])
        modePicker.selectItem(at: engine.mode == .off ? 2 : 0)
        modePicker.target = self; modePicker.action = #selector(modeChanged)
        add(modePicker)
        add(label("继续使用 UU 自带滚动条。自动模式不改本机鼠标；兼容模式会同时影响本机。", size: 12))
        loginButton.target = self; loginButton.action = #selector(loginChanged)
        add(loginButton)
        authButton.target = self; authButton.action = #selector(authorize); authButton.bezelStyle = .rounded
        add(authButton)
        detailLabel.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        detailLabel.textColor = .secondaryLabelColor
        add(detailLabel)
        add(row([button("使用说明", #selector(showHelp)), button("退出", #selector(quit))]))
        popover.contentViewController = vc; popover.behavior = .transient
        popover.contentSize = NSSize(width: 356, height: 490)
    }

    @objc func togglePopover() {
        if popover.isShown { popover.performClose(nil) }
        else if let b = status.button {
            refresh(); popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
    func refresh() {
        if !engine.running && AXIsProcessTrusted() { engine.start() }
        let percent = Int((engine.fraction * 100).rounded())
        let remaining = max(0, Int(ceil(engine.originalUntil - ProcessInfo.processInfo.systemUptime)))
        if !engine.running {
            stateLabel.stringValue = AXIsProcessTrusted() ? "监听尚未启动，请重新打开应用或检查权限。" : "需要一次辅助功能授权，才能调整滚动。"
            status.button?.title = " 授权"
        } else if engine.mode == .off {
            stateLabel.stringValue = "已暂停 · 所有滚动保持原速"
            status.button?.title = " 暂停"
        } else if remaining > 0 {
            stateLabel.stringValue = "临时原速 · \(remaining) 秒后恢复慢速"
            status.button?.title = " 100%"
        } else {
            let recent = ProcessInfo.processInfo.systemUptime - engine.lastUUTime < 5
            stateLabel.stringValue = engine.mode == .all ? "兼容模式 · 本机与远程滚动都减速" : (recent ? "已识别 UU 滚动 · 自动减速中" : "自动模式就绪 · 等待 UU 滚动")
            status.button?.title = " \(percent)%"
        }
        valueLabel.stringValue = "滚动速度：原速的 \(percent)%"
        fastButton.title = remaining > 0 ? "立即恢复慢速（剩 \(remaining) 秒）" : "原速 30 秒 · 到时恢复慢速"
        authButton.title = engine.running ? "辅助功能已授权 · 查看权限" : "授权辅助功能…"
        loginButton.state = SMAppService.mainApp.status == .enabled ? .on : .off
        var detail = "UU事件 \(engine.uuObserved) · 已减速 \(engine.adjusted)\n最近来源：\(engine.lastSource)"
        if let loginError { detail += "\n" + loginError }
        if SMAppService.mainApp.status == .requiresApproval { detail += "\n请在系统登录项中允许自动启动。" }
        detailLabel.stringValue = detail
    }
    private func setSpeed(_ f: Double) {
        engine.fraction = f; engine.originalUntil = 0
        defaults.set(f, forKey: "slowFraction")
        slider.doubleValue = (log10(f) + 2) / 2; refresh()
    }
    @objc func speedChanged() { setSpeed(max(1, (pow(10, slider.doubleValue * 2 - 2) * 100).rounded()) / 100) }
    @objc func preset5() { setSpeed(0.05) }
    @objc func preset10() { setSpeed(0.10) }
    @objc func preset50() { setSpeed(0.50) }
    @objc func temporaryFast() {
        engine.originalUntil = engine.temporaryOriginal ? 0 : ProcessInfo.processInfo.systemUptime + 30
        refresh()
    }
    @objc func modeChanged() {
        engine.mode = [ScrollMode.automatic, .all, .off][modePicker.indexOfSelectedItem]
        defaults.set(engine.mode == .off, forKey: "disabled"); refresh()
    }
    @objc func loginChanged() {
        do {
            if loginButton.state == .on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            defaults.set(true, forKey: "loginConfigured"); loginError = nil
        } catch { loginError = "自动启动设置失败，请在系统登录项中检查。" }
        refresh()
    }
    @objc func authorize() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    @objc func showHelp() {
        if let url = Bundle.main.url(forResource: "guide", withExtension: "html") { NSWorkspace.shared.open(url) }
    }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { engine.stop() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { togglePopover() }; return true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
