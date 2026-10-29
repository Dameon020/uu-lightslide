import Cocoa

final class SpeedTickMarks: NSView {
    weak var slider: NSSlider?
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 6) }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let slider, let cell = slider.cell as? NSSliderCell else { return }
        let bar = cell.barRect(flipped: slider.isFlipped)
        NSColor.secondaryLabelColor.setStroke()
        for percent in SpeedScale.presets {
            let inset = cell.knobThickness / 2
            let x = bar.minX + inset + CGFloat(SpeedScale.position(percent: percent)) * max(0, bar.width - 2 * inset)
            let line = NSBezierPath()
            line.move(to: NSPoint(x: x, y: 1)); line.line(to: NSPoint(x: x, y: 5))
            line.lineWidth = 1; line.stroke()
        }
    }
}

final class CompactPanel: NSViewController {
    let stack = NSStackView()
    let valueLabel = NSTextField(labelWithString: "10%")
    let slider = NSSlider(value: 0.5, minValue: 0, maxValue: 1, target: nil, action: nil)
    let ticks = SpeedTickMarks()
    let presets = NSSegmentedControl(labels: ["5%", "10%", "25%", "原速"], trackingMode: .selectOne, target: nil, action: nil)
    let compatibility = NSButton(title: "兼容", target: nil, action: nil)
    let reverseVertical = NSButton(checkboxWithTitle: "上下", target: nil, action: nil)
    let reverseHorizontal = NSButton(checkboxWithTitle: "左右", target: nil, action: nil)
    let more = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "更多")!, target: nil, action: nil)
    let permissionBox = NSStackView()
    let permissionText = NSTextField(wrappingLabelWithString: "开启辅助功能，才能调整滚动。")
    let permissionButton = NSButton(title: "开启辅助功能", target: nil, action: nil)
    let recognitionBox = NSStackView()
    let compatibilityButton = NSButton(title: "改用兼容模式", target: nil, action: nil)
    let onboardingText = NSTextField(wrappingLabelWithString: "")
    var resized: ((NSSize) -> Void)?

    override func loadView() {
        let background = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 270, height: 184))
        background.material = .popover; background.state = .active
        view = background
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        func add(_ child: NSView) {
            stack.addArrangedSubview(child)
            child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        let header = NSStackView(); header.orientation = .horizontal; header.spacing = 6
        let icon = NSImageView()
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") { icon.image = NSImage(contentsOf: url) }
        icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 20).isActive = true
        icon.setAccessibilityElement(false)
        header.addArrangedSubview(icon)
        let title = NSTextField(labelWithString: "UU 轻滑")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        header.addArrangedSubview(title)
        compatibility.bezelStyle = .inline; compatibility.controlSize = .small
        compatibility.font = .systemFont(ofSize: 11, weight: .medium)
        compatibility.attributedTitle = NSAttributedString(string: "兼容", attributes: [.foregroundColor: NSColor.labelColor, .font: NSFont.systemFont(ofSize: 11, weight: .medium)])
        compatibility.toolTip = "兼容模式也会调整本机滚动。点按切回自动识别。"
        compatibility.setAccessibilityLabel("兼容模式，点按恢复自动识别")
        header.addArrangedSubview(compatibility)
        header.addArrangedSubview(NSView())
        more.bezelStyle = .inline; more.isBordered = false
        more.widthAnchor.constraint(equalToConstant: 24).isActive = true
        more.heightAnchor.constraint(equalToConstant: 22).isActive = true
        more.setAccessibilityLabel("更多设置")
        header.addArrangedSubview(more)
        add(header)

        configureBox(permissionBox)
        configureCaption(permissionText)
        permissionBox.addArrangedSubview(permissionText)
        permissionButton.bezelStyle = .rounded
        permissionBox.addArrangedSubview(permissionButton)
        add(permissionBox)

        let valueRow = NSStackView(); valueRow.orientation = .horizontal
        let caption = NSTextField(labelWithString: "滚动速度")
        caption.font = .systemFont(ofSize: 12); caption.textColor = .secondaryLabelColor
        valueRow.addArrangedSubview(caption); valueRow.addArrangedSubview(NSView())
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 27, weight: .semibold)
        valueLabel.textColor = .controlAccentColor
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueRow.addArrangedSubview(valueLabel)
        add(valueRow)

        let sliderGroup = NSStackView(); sliderGroup.orientation = .vertical; sliderGroup.spacing = 0
        slider.isContinuous = true
        slider.setAccessibilityLabel("滚动速度，对数刻度")
        slider.toolTip = "对数刻度，低速区调节更精细；刻度对应 5%、10%、25% 和原速。"
        sliderGroup.addArrangedSubview(slider)
        ticks.slider = slider
        sliderGroup.addArrangedSubview(ticks)
        slider.widthAnchor.constraint(equalTo: sliderGroup.widthAnchor).isActive = true
        ticks.widthAnchor.constraint(equalTo: sliderGroup.widthAnchor).isActive = true
        add(sliderGroup)
        presets.segmentStyle = .rounded
        presets.segmentDistribution = .fillEqually
        presets.setAccessibilityLabel("滚动速度快捷档位")
        presets.setToolTip("切换原速，再点一次回到上次速度", forSegment: 3)
        add(presets)
        let directionRow = NSStackView(); directionRow.orientation = .horizontal; directionRow.spacing = 12
        let directionLabel = NSTextField(labelWithString: "反向滚动")
        directionLabel.font = .systemFont(ofSize: 12); directionLabel.textColor = .secondaryLabelColor
        directionRow.addArrangedSubview(directionLabel)
        directionRow.addArrangedSubview(NSView())
        for (button, title) in [(reverseVertical, "反转上下滚动"), (reverseHorizontal, "反转左右滚动")] {
            button.controlSize = .small; button.font = .systemFont(ofSize: 12)
            button.setAccessibilityLabel(title)
            button.toolTip = "开启后反转对应方向；关闭沿用原来的方向，原速时也生效。"
            directionRow.addArrangedSubview(button)
        }
        add(directionRow)

        configureBox(recognitionBox)
        let hint = NSTextField(wrappingLabelWithString: "没识别到 UU 的滚动？")
        configureCaption(hint)
        recognitionBox.addArrangedSubview(hint)
        compatibilityButton.bezelStyle = .rounded
        recognitionBox.addArrangedSubview(compatibilityButton)
        add(recognitionBox)
        configureCaption(onboardingText)
        add(onboardingText)
    }

    private func configureCaption(_ label: NSTextField) {
        label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 238
        label.setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func configureBox(_ box: NSStackView) {
        box.orientation = .vertical; box.alignment = .leading; box.spacing = 6
    }

    func update(percent: Int, mode: ScrollMode, authorized: Bool, running: Bool,
                suggestion: Bool, onboarding: String?, reverseX: Bool = false, reverseY: Bool = false) {
        _ = view
        valueLabel.stringValue = "\(percent)%"
        valueLabel.textColor = authorized ? .controlAccentColor : .disabledControlTextColor
        slider.doubleValue = SpeedScale.position(percent: percent)
        slider.setAccessibilityValue("原速的 \(percent)%")
        slider.isEnabled = authorized && running
        presets.isEnabled = authorized && running
        reverseVertical.isEnabled = authorized && running
        reverseHorizontal.isEnabled = authorized && running
        reverseVertical.state = reverseY ? .on : .off
        reverseHorizontal.state = reverseX ? .on : .off
        presets.selectedSegment = SpeedScale.presets.firstIndex(of: percent) ?? -1
        compatibility.isHidden = mode != .all
        permissionBox.isHidden = authorized && running
        permissionText.stringValue = authorized ? "滚动监听未启动，请重试。" : "开启辅助功能，才能调整滚动。"
        permissionButton.title = authorized ? "重新连接滚动监听" : "开启辅助功能"
        recognitionBox.isHidden = !suggestion || !authorized || !running || mode != .automatic || (percent == 100 && !reverseX && !reverseY)
        onboardingText.stringValue = onboarding ?? ""
        onboardingText.isHidden = onboarding == nil
        ticks.needsDisplay = true
        view.layoutSubtreeIfNeeded()
        let size = NSSize(width: 270, height: ceil(stack.fittingSize.height) + 32)
        view.setFrameSize(size)
        resized?(size)
    }
}
