import AppKit

/// Polls NSPasteboard on a fixed interval and fires a callback whenever new text is copied.
///
/// Platform-specific. Not unit-testable in isolation.
/// Call `start()` to begin monitoring and `stop()` to halt it.
final class ClipboardMonitor {

    private let interval: TimeInterval = 0.5
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    /// Called on the main thread whenever a new text entry is detected on the pasteboard.
    var onNewEntry: ((String) -> Void)?

    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        onNewEntry?(text)
    }
}
