import CoreGraphics
import AppKit

/// Intercepts and swallows Option+W (cycle older) and Option+S (cycle newer) globally
/// using a CGEventTap at the session level.
///
/// Requires Accessibility permission. Call `enable()` only after `AXIsProcessTrusted()` returns true.
/// If the tap cannot be created (permission denied), `enable()` exits silently.
/// Platform-specific. Not unit-testable in isolation.
final class HotkeyEngine {

    var onCycleOlder: (() -> Void)?
    var onCycleNewer: (() -> Void)?
    var onTapDisabled: (() -> Void)?
    /// Fired on the main thread when the user releases the Option key after cycling.
    var onOptionReleased: (() -> Void)?
    /// Fired on the main thread when the user presses Option+Q during a cycling session.
    /// Use this to cancel the pending paste and hide the HUD without pasting.
    var onCancelCycle: (() -> Void)?

    /// Tracks whether the user pressed Option+W or Option+S since the last release.
    fileprivate var isCycling: Bool = false

    /// Clears cycling state without firing the release callback.
    /// Call this when history is cleared or the engine is disabled mid-session.
    func resetCyclingSession() {
        isCycling = false
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Key codes (US layout — hardware key positions, layout-independent)
    fileprivate static let keyCodeW: CGKeyCode = 13
    fileprivate static let keyCodeS: CGKeyCode = 1
    fileprivate static let keyCodeQ: CGKeyCode = 12

    func enable() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func disable() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    deinit {
        disable()
    }
}

// Top-level C-compatible callback — no captures allowed.
// Self is bridged via the userInfo pointer using passUnretained (safe: HotkeyEngine outlives the tap).
private func hotkeyEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passRetained(event) }
    let engine = Unmanaged<HotkeyEngine>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByUserInput, .tapDisabledByTimeout:
        DispatchQueue.main.async { engine.onTapDisabled?() }
        return Unmanaged.passRetained(event)

    case .keyDown:
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Match pure Option only — must not have Command, Control, or Shift
        guard flags.contains(.maskAlternate),
              !flags.contains(.maskCommand),
              !flags.contains(.maskControl),
              !flags.contains(.maskShift) else {
            return Unmanaged.passRetained(event)
        }

        switch keyCode {
        case HotkeyEngine.keyCodeW:
            engine.isCycling = true
            DispatchQueue.main.async { engine.onCycleOlder?() }
            return nil  // swallowed
        case HotkeyEngine.keyCodeS:
            engine.isCycling = true
            DispatchQueue.main.async { engine.onCycleNewer?() }
            return nil  // swallowed
        case HotkeyEngine.keyCodeQ where engine.isCycling:
            // Option+Q during a cycling session — cancel paste, do not step ring.
            engine.isCycling = false
            DispatchQueue.main.async { engine.onCancelCycle?() }
            return nil  // swallowed
        default:
            return Unmanaged.passRetained(event)
        }

    case .flagsChanged:
        // If the user releases Option while a cycling session is active, fire the paste callback.
        if engine.isCycling && !event.flags.contains(.maskAlternate) {
            engine.isCycling = false
            DispatchQueue.main.async { engine.onOptionReleased?() }
        }
        return Unmanaged.passRetained(event)  // never swallow flags

    default:
        return Unmanaged.passRetained(event)
    }
}
