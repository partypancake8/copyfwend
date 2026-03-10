import AppKit
import Combine

/// Central coordinator that owns all core services and drives the clipboard ring.
///
/// Wires ClipboardMonitor → ClipboardRing → NSPasteboard on every cycle.
/// Suppresses monitor feedback after outbound clipboard writes via resyncChangeCount.
/// All mutations happen on the main actor (Timer and CGEventTap both fire on the main run loop).
@MainActor
final class AppController: ObservableObject {

    @Published private(set) var isEnabled: Bool = true
    @Published private(set) var historyCount: Int = 0
    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var launchAtLoginEnabled: Bool = LaunchAtLoginManager.isEnabled

    private let ring = ClipboardRing()
    private let monitor = ClipboardMonitor()
    private let hotkey = HotkeyEngine()
    private let hud = CycleHUD()
    private var trustPollTimer: Timer?

    init() {
        accessibilityGranted = AXIsProcessTrusted()

        hud.onPaste = { [weak self] in
            self?.ring.promoteCurrentToNewest()
        }

        monitor.onNewEntry = { [weak self] text in
            self?.onNewEntry(text)
        }

        hotkey.onCycleOlder = { [weak self] in
            self?.cycleOlder()
        }

        hotkey.onCycleNewer = { [weak self] in
            self?.cycleNewer()
        }

        hotkey.onTapDisabled = { [weak self] in
            self?.accessibilityGranted = false
        }

        monitor.start()

        // Always attempt enable — CGEvent.tapCreate is what causes macOS to register
        // the app in Accessibility and surface the permission prompt. The engine
        // silently no-ops if trust hasn't been granted yet.
        hotkey.enable()

        if !accessibilityGranted {
            print("[AppController] Accessibility not granted — grant in System Settings → Privacy & Security → Accessibility")
            startTrustPolling()
        }
    }

    private func startTrustPolling() {
        trustPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard AXIsProcessTrusted() else { return }
                self.trustPollTimer?.invalidate()
                self.trustPollTimer = nil
                self.accessibilityGranted = true
                self.hotkey.enable()
                print("[AppController] Accessibility granted — hotkey engine enabled")
            }
        }
    }

    // MARK: - Entry point for new clipboard text

    func onNewEntry(_ text: String) {
        ring.append(text)
        historyCount = ring.count
        print("[AppController] new entry (\(ring.count) total): \(text.prefix(80))")
    }

    // MARK: - Cycling

    func cycleOlder() {
        ring.cycleOlder()
        writeCurrentEntryToClipboard()
        showHUD()
    }

    func cycleNewer() {
        ring.cycleNewer()
        writeCurrentEntryToClipboard()
        showHUD()
    }

    // MARK: - History management

    func clearHistory() {
        ring.clear()
        historyCount = ring.count
        hud.hide()
    }

    // MARK: - Enable / disable

    func toggleEnabled() {
        isEnabled.toggle()
        if isEnabled {
            monitor.start()
            refreshAccessibilityStatus()
        } else {
            monitor.stop()
            hotkey.disable()
            hud.hide()
        }
    }

    // MARK: - Launch at Login

    func toggleLaunchAtLogin() {
        LaunchAtLoginManager.toggle()
        launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    }

    // MARK: - Accessibility

    /// Re-checks AXIsProcessTrusted and enables/disables the hotkey engine accordingly.
    func refreshAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        accessibilityGranted = trusted
        if trusted && isEnabled {
            hotkey.enable()
        } else if !trusted {
            hotkey.disable()
        }
    }

    // MARK: - Private

    private func writeCurrentEntryToClipboard() {
        guard let text = ring.currentEntry() else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        monitor.resyncChangeCount()
        print("[AppController] clipboard → \(text.prefix(80))")
    }

    /// Computes display index and forwards the current entry to the CycleHUD.
    /// No-ops if the ring is empty (guard in cycleOlder/cycleNewer already ensures this).
    private func showHUD() {
        guard let text = ring.currentEntry(), let cursorIdx = ring.currentIndex else { return }
        // 1-based: 1 = most recent (highest cursor), Total = oldest (cursor 0)
        let displayIndex = ring.count - cursorIdx
        hud.show(text: text, index: displayIndex, total: ring.count)
    }
}
