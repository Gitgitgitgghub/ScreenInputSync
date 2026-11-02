import AppKit

@MainActor
final class ResyncHUDController {
    private let panel: NSPanel
    private let titleLabel: NSTextField
    private let instructionLabel: NSTextField
    private var dismissWorkItem: DispatchWorkItem?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        titleLabel = NSTextField(labelWithString: "Align with remote Mac")
        instructionLabel = NSTextField(labelWithString: "E  English     C  中文     Esc  Cancel")

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let effectView = NSVisualEffectView(frame: panel.contentView!.bounds)
        effectView.autoresizingMask = [.width, .height]
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 18
        effectView.layer?.masksToBounds = true
        panel.contentView = effectView

        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .center
        instructionLabel.font = .monospacedSystemFont(ofSize: 17, weight: .medium)
        instructionLabel.textColor = .secondaryLabelColor
        instructionLabel.alignment = .center

        let stack = NSStackView(views: [titleLabel, instructionLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: effectView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: effectView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: effectView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: effectView.trailingAnchor, constant: -24)
        ])
    }

    func show() {
        dismissWorkItem?.cancel()
        titleLabel.stringValue = "Align with remote Mac"
        instructionLabel.stringValue = "E  English     C  中文     Esc  Cancel"
        centerPanel()
        panel.orderFrontRegardless()
    }

    func showConfirmation(_ mode: InputMode) {
        dismissWorkItem?.cancel()
        titleLabel.stringValue = mode == .english ? "Aligned: English" : "已對齊：中文"
        instructionLabel.stringValue = ""
        centerPanel()
        panel.orderFrontRegardless()

        let item = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9, execute: item)
    }

    func dismiss() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        panel.orderOut(nil)
    }

    private func centerPanel() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - panel.frame.width / 2,
            y: frame.midY - panel.frame.height / 2
        ))
    }
}
