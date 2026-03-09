import Foundation

/// In-memory ring of clipboard text entries.
///
/// Pure Swift — no platform dependencies. All entries are recorded as-is:
/// duplicates, empty strings, and whitespace-only strings are never filtered.
///
/// Cursor resets to the newest entry on every `append`. Cycling wraps at both ends.
final class ClipboardRing {

    private var entries: [String] = []
    private var cursor: Int = 0

    /// Number of entries currently stored.
    var count: Int { entries.count }

    /// Appends a new entry and resets the cursor to the newest position.
    func append(_ text: String) {
        entries.append(text)
        cursor = entries.count - 1
    }

    /// Returns the entry at the current cursor position, or `nil` if the ring is empty.
    func currentEntry() -> String? {
        guard !entries.isEmpty else { return nil }
        return entries[cursor]
    }

    /// Moves the cursor toward older entries (lower index), wrapping from oldest to newest.
    func cycleOlder() {
        guard !entries.isEmpty else { return }
        cursor = cursor == 0 ? entries.count - 1 : cursor - 1
    }

    /// Moves the cursor toward newer entries (higher index), wrapping from newest to oldest.
    func cycleNewer() {
        guard !entries.isEmpty else { return }
        cursor = cursor == entries.count - 1 ? 0 : cursor + 1
    }

    /// Removes all entries and resets the cursor.
    func clear() {
        entries.removeAll()
        cursor = 0
    }
}
