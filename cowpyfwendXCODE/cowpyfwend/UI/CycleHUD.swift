import AppKit
import CoreGraphics

/// Floating non-activating panel displayed near the cursor while the user cycles clipboard history.
///
/// Shows the current ring entry (truncated) and a position indicator `[N / Total]` where
/// 1 = most recent entry and Total = oldest. Auto-pastes via Cmd+V and dismisses after 1.0s
/// of cycling inactivity. Never steals keyboard focus.
///
/// Owned by `AppController`. Call `show(text:index:total:)` on every cycle press and
/// `hide()` when cycling is interrupted (clear, disable).
final class CycleHUD: NSPanel {

    private let label = NSTextField(labelWithString: "")
    private var dismissTimer: Timer?

    private static let panelWidth:    CGFloat       = 460
    private static let panelHeight:   CGFloat       = 38
    private static let maxChars:      Int           = 45
    private static let dismissDelay:  TimeInterval  = 1.0
    /// Cursor offset so the HUD appears above and to the right of the pointer.
    private static let cursorOffset:  NSPoint       = NSPoint(x: 16, y: 20)

    // MARK: - Init

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.panelWidth, height: Self.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setupContent()
    }

    private func setupContent() {
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 8
        effect.layer?.masksToBounds = true

        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
        ])

        contentView = effect
    }

    // MARK: - Public API

    /// Updates the HUD label, repositions near the cursor, and resets the 1.0s dismiss timer.
    ///
    /// - Parameters:
    ///   - text: The current clipboard entry. Truncated to `maxChars` characters automatically.
    ///   - index: 1-based display index (1 = most recent entry).
    ///   - total: Total number of entries in the ring.
    func show(text: String, index: Int, total: Int) {
        let clipped = text.count > Self.maxChars
            ? String(text.prefix(Self.maxChars)).appending("…")
            : text
        // Collapse newlines so multi-line copies display on one line
        let oneLiner = clipped
            .replacingOccurrences(of: "\r\n", with: "↵")
            .replacingOccurrences(of: "\n",   with: "↵")
            .replacingOccurrences(of: "\r",   with: "↵")
        label.stringValue = "\(oneLiner)  [\(index) / \(total)]"

        repositionNearCursor()
        if !isVisible { orderFront(nil) }
        resetDismissTimer()
    }

    /// Cancels the dismiss timer and hides the panel without simulating paste.
    ///
    /// Call when history is cleared or the app is disabled mid-cycle.
    func hide() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        orderOut(nil)
    }

    // MARK: - Private

    private func repositionNearCursor() {
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(
            x: mouse.x + Self.cursorOffset.x,
            y: mouse.y + Self.cursorOffset.y
        )

        // Clamp to the screen that contains the cursor so the panel is always fully visible
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let screen {
            let frame = screen.visibleFrame
            origin.x = max(frame.minX + 8, min(origin.x, frame.maxX - Self.panelWidth  - 8))
            origin.y = max(frame.minY + 8, min(origin.y, frame.maxY - Self.panelHeight - 8))
        }

        setFrameOrigin(origin)
    }

    private func resetDismissTimer() {
        dismissTimer?.invalidate()
        dismissTimer = Timer.scheduledTimer(
            withTimeInterval: Self.dismissDelay,
            repeats: false
        ) { [weak self] _ in
            self?.pasteAndHide()
        }
    }

    private func pasteAndHide() {
        simulatePaste()
        hide()
    }

    /// Simulates Cmd+V (keyCode 9) via CGEventTap so the current clipboard entry is pasted
    /// into whatever app had focus before the hotkey fired.
    private func simulatePaste() {
        guard
            let source  = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
            let keyUp   = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        else { return }
        keyDown.flags = .maskCommand
        keyUp.flags   = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }
}
