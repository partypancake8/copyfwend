import AppKit
import CoreGraphics

/// Floating non-activating panel displayed near the cursor while the user cycles clipboard history.
///
/// Shows the current ring entry (truncated) and a position indicator `[N / Total]` where
/// 1 = most recent entry and Total = oldest. Paste is triggered by calling `commitPaste()`
/// when the user releases the Option modifier key. Never steals keyboard focus.
///
/// Owned by `AppController`. Call `show(text:index:total:)` on every cycle press,
/// `commitPaste()` on Option release, and `hide()` when cycling is interrupted (clear, disable).
final class CycleHUD: NSPanel {

    private let label      = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "")

    /// Called on the main thread immediately after a paste is simulated.
    /// Wire this to `ClipboardRing.promoteCurrentToNewest()` via `AppController`.
    var onPaste: (() -> Void)?

    private static let hPad:             CGFloat      = 14
    private static let vPad:             CGFloat      = 10
    private static let badgeTopGap:      CGFloat      = 4
    private static let minWidth:         CGFloat      = 120
    private static let maxWidthFraction: CGFloat      = 0.40  // fraction of the current screen width
    private static let absoluteMaxWidth: CGFloat      = 620
    private static let maxLines:         Int          = 5
    private static let fontSize:         CGFloat      = 13
    private static let badgeFontSize:    CGFloat      = 11
    private static let cornerRadius:     CGFloat      = 12
    private static let panelAlpha:       CGFloat      = 0.92
    private static let fadeIn:           TimeInterval = 0.10
    private static let fadeOut:          TimeInterval = 0.08
    /// Cursor offset so the HUD appears below and to the right of the pointer.
    private static let cursorOffset:     NSPoint      = NSPoint(x: 16, y: -28)

    // MARK: - Init

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.minWidth, height: 38),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        alphaValue = 0
        setupContent()
    }

    private func setupContent() {
        let effect = NSVisualEffectView()
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = Self.cornerRadius
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 0.5
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor

        label.font = .systemFont(ofSize: Self.fontSize, weight: .regular)
        label.textColor = .white
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = Self.maxLines
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false

        badgeLabel.font = .monospacedSystemFont(ofSize: Self.badgeFontSize, weight: .medium)
        badgeLabel.textColor = NSColor.controlAccentColor
        badgeLabel.alignment = .left
        badgeLabel.isSelectable = false
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(badgeLabel)
        effect.addSubview(label)
        NSLayoutConstraint.activate([
            badgeLabel.topAnchor.constraint(equalTo: effect.topAnchor, constant: Self.vPad),
            badgeLabel.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: Self.hPad),
            badgeLabel.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -Self.hPad),

            label.topAnchor.constraint(equalTo: badgeLabel.bottomAnchor, constant: Self.badgeTopGap),
            label.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: Self.hPad),
            label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -Self.hPad),
            label.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -Self.vPad),
        ])

        contentView = effect
    }

    // MARK: - Public API

    /// Updates the HUD label, resizes to fit, and repositions near the cursor.
    ///
    /// - Parameters:
    ///   - text: The current clipboard entry.
    ///   - index: 1-based display index (1 = most recent entry).
    ///   - total: Total number of entries in the ring.
    func show(text: String, index: Int, total: Int) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        let screenWidth = screen?.visibleFrame.width ?? 1440
        let maxPanelWidth = min(Self.absoluteMaxWidth, screenWidth * Self.maxWidthFraction)

        // Normalize line endings; preserve as real newlines for multi-line display
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r",   with: "\n")

        // Truncate to a screen-proportional character limit
        let charLimit = screenCharLimit(containerWidth: maxPanelWidth - Self.hPad * 2)
        let display = normalized.count > charLimit
            ? String(normalized.prefix(charLimit)).appending("…")
            : normalized

        label.stringValue = display
        badgeLabel.stringValue = "\(index) / \(total)"

        resizePanel(maxPanelWidth: maxPanelWidth)
        repositionNearCursor()

        if !isVisible {
            alphaValue = 0
            orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = Self.fadeIn
                self.animator().alphaValue = Self.panelAlpha
            }
        }
    }

    /// Hides the panel without simulating paste.
    ///
    /// Call when history is cleared or the app is disabled mid-cycle.
    func hide() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = Self.fadeOut
            self.animator().alphaValue = 0
        }) { [weak self] in
            self?.orderOut(nil)
        }
    }

    /// Triggers paste and hides the HUD. Call when the user releases the Option modifier key.
    func commitPaste() {
        pasteAndHide()
    }

    // MARK: - Private

    /// at the label font, multiplied by maxLines.
    private func screenCharLimit(containerWidth: CGFloat) -> Int {
        guard let font = label.font else { return 300 }
        let charWidth = ("M" as NSString).size(withAttributes: [.font: font]).width
        let charsPerLine = max(1, Int(containerWidth / charWidth))
        return charsPerLine * Self.maxLines
    }

    /// Sizes the panel to fit the current label string.
    /// Short text → panel shrinks to content width (single line).
    /// Long text → panel uses maxPanelWidth and grows vertically up to maxLines.
    private func resizePanel(maxPanelWidth: CGFloat) {
        guard let font = label.font, let badgeFont = badgeLabel.font else { return }
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let containerWidth = maxPanelWidth - Self.hPad * 2

        let singleLineWidth = ceil((label.stringValue as NSString).size(withAttributes: attrs).width)
        let panelWidth: CGFloat = singleLineWidth <= containerWidth
            ? max(Self.minWidth, singleLineWidth + Self.hPad * 2)
            : maxPanelWidth

        let measuredRect = (label.stringValue as NSString).boundingRect(
            with: NSSize(width: panelWidth - Self.hPad * 2, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let badgeHeight = ceil(("0" as NSString).size(withAttributes: [.font: badgeFont]).height)
        let panelHeight = Self.vPad + badgeHeight + Self.badgeTopGap + ceil(measuredRect.height) + Self.vPad
        setContentSize(NSSize(width: panelWidth, height: panelHeight))
    }

    private func repositionNearCursor() {
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(
            x: mouse.x + Self.cursorOffset.x,
            y: mouse.y + Self.cursorOffset.y
        )

        // Clamp to the screen that contains the cursor so the panel is always fully visible
        // Negative Y offset places the HUD below the cursor; subtract panel height to anchor top edge.
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main
        if let screen {
            let frame = screen.visibleFrame
            origin.x = max(frame.minX + 8, min(origin.x, frame.maxX - self.frame.size.width  - 8))
            origin.y = max(frame.minY + 8, min(origin.y, frame.maxY - self.frame.size.height - 8))
        }

        setFrameOrigin(origin)
    }

    private func pasteAndHide() {
        simulatePaste()
        onPaste?()
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

