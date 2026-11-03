import AppKit

@MainActor
final class ResyncHUDController {
    private static let size = NSSize(width: 440, height: 248)
    private static let cornerRadius: CGFloat = 22

    private let panel: NSPanel
    private let choiceView: NSView
    private let confirmationView: NSView
    private let confirmationLabel: NSTextField
    private var dismissWorkItem: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // The mask image rounds the material *and* the window shadow, so no
        // square corners show behind the rounded content.
        let effectView = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.maskImage = Self.roundedMask(radius: Self.cornerRadius)
        panel.contentView = effectView

        let title = Self.label("遠端 Mac 現在是哪個輸入法？", size: 18, weight: .semibold)
        let subtitle = Self.label("看一眼遠端選單列，按下對應的鍵（只切換本機）",
                                  size: 12, weight: .regular, color: .secondaryLabelColor)
        subtitle.maximumNumberOfLines = 2
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.preferredMaxLayoutWidth = Self.size.width - 64

        let options = NSStackView(views: [
            Self.optionCard(key: "E", title: "ABC", caption: "遠端是英文"),
            Self.optionCard(key: "C", title: "注音", caption: "遠端是中文"),
        ])
        options.orientation = .horizontal
        options.distribution = .fillEqually
        options.spacing = 12

        let cancel = NSStackView(views: [
            Self.keycap("esc"),
            Self.label("取消", size: 12, weight: .regular, color: .secondaryLabelColor),
        ])
        cancel.orientation = .horizontal
        cancel.spacing = 6

        let choice = NSStackView(views: [title, subtitle, options, cancel])
        choice.orientation = .vertical
        choice.alignment = .centerX
        choice.spacing = 10
        choice.setCustomSpacing(18, after: subtitle)
        choice.setCustomSpacing(16, after: options)
        options.translatesAutoresizingMaskIntoConstraints = false
        choiceView = choice

        let check = NSImageView(image: NSImage(
            systemSymbolName: "checkmark.circle.fill",
            accessibilityDescription: nil
        ) ?? NSImage())
        check.symbolConfiguration = .init(pointSize: 44, weight: .medium)
        check.contentTintColor = .systemGreen
        confirmationLabel = Self.label("", size: 17, weight: .semibold)
        let confirmation = NSStackView(views: [check, confirmationLabel])
        confirmation.orientation = .vertical
        confirmation.alignment = .centerX
        confirmation.spacing = 12
        confirmationView = confirmation

        for view in [choiceView, confirmationView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            effectView.addSubview(view)
            NSLayoutConstraint.activate([
                view.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
                view.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            ])
        }
        NSLayoutConstraint.activate([
            options.widthAnchor.constraint(equalToConstant: Self.size.width - 64),
        ])
    }

    func show() {
        dismissWorkItem?.cancel()
        choiceView.isHidden = false
        confirmationView.isHidden = true
        present()
    }

    func showConfirmation(_ mode: InputMode) {
        dismissWorkItem?.cancel()
        confirmationLabel.stringValue = mode == .english ? "已對齊：本機切為 ABC" : "已對齊：本機切為注音"
        choiceView.isHidden = true
        confirmationView.isHidden = false
        present()

        let item = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        panel.orderOut(nil)
    }

    private func present() {
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: frame.midX - Self.size.width / 2,
                y: frame.midY - Self.size.height / 2
            ))
        }
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    // MARK: - Building blocks

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private static func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight,
        color: NSColor = .labelColor
    ) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        field.alignment = .center
        return field
    }

    private static func keycap(_ key: String, prominent: Bool = false) -> NSView {
        let text = NSTextField(labelWithString: key)
        text.font = .monospacedSystemFont(ofSize: prominent ? 18 : 11, weight: .semibold)
        text.textColor = prominent ? .white : .secondaryLabelColor
        text.alignment = .center
        let cap = RoundedFillView(
            content: text,
            padding: prominent ? NSEdgeInsets(top: 5, left: 14, bottom: 5, right: 14)
                               : NSEdgeInsets(top: 2, left: 7, bottom: 2, right: 7),
            cornerRadius: prominent ? 8 : 5,
            fill: prominent ? .controlAccentColor : .quaternaryLabelColor,
            border: prominent ? nil : .separatorColor
        )
        cap.setContentHuggingPriority(.required, for: .horizontal)
        cap.setContentHuggingPriority(.required, for: .vertical)
        return cap
    }

    private static func optionCard(key: String, title: String, caption: String) -> NSView {
        let stack = NSStackView(views: [
            keycap(key, prominent: true),
            label(title, size: 16, weight: .semibold),
            label(caption, size: 11, weight: .regular, color: .secondaryLabelColor),
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        return RoundedFillView(
            content: stack,
            padding: NSEdgeInsets(top: 14, left: 12, bottom: 12, right: 12),
            cornerRadius: 14,
            fill: .quaternaryLabelColor,
            border: nil
        )
    }
}

/// Layer-backed rounded background that sizes itself from its content and
/// re-resolves dynamic colors when the appearance changes.
private final class RoundedFillView: NSView {
    private let fill: NSColor
    private let border: NSColor?

    init(content: NSView, padding: NSEdgeInsets, cornerRadius: CGFloat, fill: NSColor, border: NSColor?) {
        self.fill = fill
        self.border = border
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor, constant: padding.top),
            content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding.bottom),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: padding.left),
            content.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -padding.right),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
        let snug = widthAnchor.constraint(equalTo: content.widthAnchor, constant: padding.left + padding.right)
        snug.priority = .defaultLow
        snug.isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fill.cgColor
            layer?.borderColor = border?.cgColor
            layer?.borderWidth = border == nil ? 0 : 1
        }
    }
}
