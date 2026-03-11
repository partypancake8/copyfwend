import Foundation

/// In-memory ring of clipboard text entries.
///
/// Pure Swift — no platform dependencies. All entries are recorded as-is:
/// duplicates, empty strings, and whitespace-only strings are never filtered.
///
/// Cursor resets to the newest entry on every `append`. Cycling clamps at both ends — no wraparound.
///
/// First-press model: the first `cycleOlder` or `cycleNewer` after a new copy writes
/// the current entry (newest) without moving the cursor — matching the terminal up-arrow
/// mental model. Subsequent presses step through history. A new `append` resets this state.
final class ClipboardRing {

    private var entries: [String] = []
    private var cursor: Int = 0
    /// False after every append; set to true on the first cycle press.
    /// While false, cycle calls return the current entry without moving.
    private var cyclingActive = false

    /// Number of entries currently stored.
    var count: Int { entries.count }

    /// The 0-based cursor position (0 = oldest, count−1 = newest), or `nil` if the ring is empty.
    var currentIndex: Int? { entries.isEmpty ? nil : cursor }

    /// Appends a new entry, resets the cursor to the newest position, and resets cycling state.
    func append(_ text: String) {
        entries.append(text)
        cursor = entries.count - 1
        cyclingActive = false
    }

    /// Returns the entry at the current cursor position, or `nil` if the ring is empty.
    func currentEntry() -> String? {
        guard !entries.isEmpty else { return nil }
        return entries[cursor]
    }

    /// Moves the cursor toward older entries (lower index), clamping at the oldest entry.
    /// First call after a copy does not move — it returns the newest entry (current position).
    func cycleOlder() {
        guard !entries.isEmpty else { return }
        if cyclingActive {
            if cursor > 0 { cursor -= 1 }
        } else {
            cyclingActive = true
        }
    }

    /// Moves the cursor toward newer entries (higher index), clamping at the newest entry.
    /// First call after a copy does not move — it returns the newest entry (current position).
    func cycleNewer() {
        guard !entries.isEmpty else { return }
        if cyclingActive {
            if cursor < entries.count - 1 { cursor += 1 }
        } else {
            cyclingActive = true
        }
    }

    /// Promotes the current entry to the newest position in the ring and resets cycling state.
    ///
    /// Call after a paste. The pasted entry is moved (not duplicated) to the end of the ring,
    /// matching the clipboard's actual state — the last written value is now the "newest" item.
    /// Count is unchanged. The next cycle session will start on the promoted entry.
    func promoteCurrentToNewest() {
        guard !entries.isEmpty else { return }
        let text = entries[cursor]
        entries.remove(at: cursor)
        entries.append(text)
        cursor = entries.count - 1
        cyclingActive = false
    }

    /// Removes all entries and resets the cursor and cycling state.
    func clear() {
        entries.removeAll()
        cursor = 0
        cyclingActive = false
    }
}
