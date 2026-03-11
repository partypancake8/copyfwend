import Testing
@testable import copyfwend

struct ClipboardRingTests {

    // MARK: - Empty state

    @Test func emptyRingHasZeroCount() {
        let ring = ClipboardRing()
        #expect(ring.count == 0)
    }

    @Test func emptyRingCurrentEntryIsNil() {
        let ring = ClipboardRing()
        #expect(ring.currentEntry() == nil)
    }

    // MARK: - Single entry

    @Test func singleAppendCountIsOne() {
        let ring = ClipboardRing()
        ring.append("hello")
        #expect(ring.count == 1)
    }

    @Test func singleAppendCurrentEntryReturnsIt() {
        let ring = ClipboardRing()
        ring.append("hello")
        #expect(ring.currentEntry() == "hello")
    }

    // MARK: - Multiple entries and cursor position

    @Test func multipleAppendsIncrementCount() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        #expect(ring.count == 3)
    }

    @Test func afterMultipleAppendsCursorIsAtNewest() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        #expect(ring.currentEntry() == "c")
    }

    // MARK: - cycleOlder

    @Test func firstCycleOlderStaysAtNewest() {
        // First press after a copy must not move — returns the newest entry.
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder()
        #expect(ring.currentEntry() == "c")
    }

    @Test func secondCycleOlderMovesBackOne() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // first press — stays at c
        ring.cycleOlder() // second press — moves to b
        #expect(ring.currentEntry() == "b")
    }

    @Test func cycleOlderFromOldestClampsAtOldest() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move — first press)
        ring.cycleOlder() // b
        ring.cycleOlder() // a — at oldest
        ring.cycleOlder() // clamped — stays at a
        #expect(ring.currentEntry() == "a")
    }

    // MARK: - cycleNewer

    @Test func firstCycleNewerStaysAtNewest() {
        // First press after a copy must not move — returns the newest entry.
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleNewer()
        #expect(ring.currentEntry() == "c")
    }

    @Test func cycleNewerFromNewestClampsAtNewest() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleNewer() // c (no move — first press, already at newest)
        ring.cycleNewer() // clamped — stays at c
        #expect(ring.currentEntry() == "c")
    }

    @Test func cycleNewerFromOldestMovesForwardOne() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move — first press)
        ring.cycleOlder() // b
        ring.cycleOlder() // a — at oldest
        ring.cycleNewer() // b — moves forward one
        #expect(ring.currentEntry() == "b")
    }

    // MARK: - Append resets cursor

    @Test func appendResetsCursorToNewestRegardlessOfPosition() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move)
        ring.cycleOlder() // b
        ring.cycleOlder() // a — cursor not at newest
        ring.append("d")  // should reset to d
        #expect(ring.currentEntry() == "d")
        #expect(ring.count == 4)
    }

    // MARK: - clear

    @Test func clearResetsCountToZero() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.clear()
        #expect(ring.count == 0)
    }

    @Test func clearMakesCurrentEntryNil() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.clear()
        #expect(ring.currentEntry() == nil)
    }

    @Test func clearThenAppendWorks() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.clear()
        ring.append("b")
        #expect(ring.count == 1)
        #expect(ring.currentEntry() == "b")
    }

    // MARK: - No filtering

    @Test func duplicateEntriesAreBothRecorded() {
        let ring = ClipboardRing()
        ring.append("same")
        ring.append("same")
        #expect(ring.count == 2)
    }

    @Test func emptyStringIsRecorded() {
        let ring = ClipboardRing()
        ring.append("")
        #expect(ring.count == 1)
        #expect(ring.currentEntry() == "")
    }
    @Test func whitespaceOnlyStringIsRecorded() {
        let ring = ClipboardRing()
        ring.append("   \t\n")
        #expect(ring.count == 1)
        #expect(ring.currentEntry() == "   \t\n")
    }

    // MARK: - Wraparound symmetry

    @Test func fullCycleOlderStopsAtOldest() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        // First press: no move (c). Then step b, a — clamps at oldest.
        ring.cycleOlder() // c (no move — first press)
        ring.cycleOlder() // b
        ring.cycleOlder() // a — at oldest
        ring.cycleOlder() // clamped — stays at a
        #expect(ring.currentEntry() == "a")
    }

    @Test func fullCycleNewerClampsAtNewest() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        // First press: no move (already at newest). Further presses clamp at c.
        ring.cycleNewer() // c (no move — first press)
        ring.cycleNewer() // clamped — stays at c
        ring.cycleNewer() // stays at c
        ring.cycleNewer() // stays at c
        #expect(ring.currentEntry() == "c")
    }

    // MARK: - First-press model / cycling session

    @Test func appendResetsCyclingSessionFirstWIsNewest() {
        // After a new copy, first W should always yield newest regardless of prior cycling.
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move)
        ring.cycleOlder() // b — mid-session
        ring.append("d")  // new copy resets session
        ring.cycleOlder() // first W → d (no move)
        #expect(ring.currentEntry() == "d")
    }

    @Test func mixedCycleOlderThenNewer() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move)
        ring.cycleOlder() // b
        ring.cycleOlder() // a
        ring.cycleNewer() // b
        ring.cycleNewer() // c
        #expect(ring.currentEntry() == "c")
    }

    @Test func singleEntryCycleOlderStaysOnIt() {
        let ring = ClipboardRing()
        ring.append("only")
        ring.cycleOlder() // no move (first press)
        ring.cycleOlder() // clamped — still "only"
        #expect(ring.currentEntry() == "only")
    }

    @Test func cycleOlderOnEmptyRingIsNoop() {
        let ring = ClipboardRing()
        ring.cycleOlder()
        #expect(ring.currentEntry() == nil)
    }

    @Test func cycleNewerOnEmptyRingIsNoop() {
        let ring = ClipboardRing()
        ring.cycleNewer()
        #expect(ring.currentEntry() == nil)
    }

    // MARK: - promoteCurrentToNewest

    @Test func promoteCurrentToNewestMovesOlderEntryToEnd() {
        // Cycle to an older entry, promote it — it should appear as newest.
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move, first press)
        ring.cycleOlder() // b
        ring.promoteCurrentToNewest()  // b promoted to newest
        #expect(ring.currentEntry() == "b")
        #expect(ring.count == 3)        // no duplication
    }

    @Test func promoteCurrentToNewestOrdersRingCorrectly() {
        // After promoting b from [a, b, c], ring should be [a, c, b].
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move)
        ring.cycleOlder() // b
        ring.promoteCurrentToNewest()
        // Now cycle: first press stays on b (newest), then c, then a.
        ring.cycleOlder() // b (no move — first press after promote)
        #expect(ring.currentEntry() == "b")
        ring.cycleOlder() // c (one step older)
        #expect(ring.currentEntry() == "c")
        ring.cycleOlder() // a
        #expect(ring.currentEntry() == "a")
    }

    @Test func promoteCurrentToNewestResetsCyclingSession() {
        // After promote, first cycle press must stay on the promoted entry.
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move)
        ring.cycleOlder() // b
        ring.promoteCurrentToNewest()
        ring.cycleOlder() // first press — must stay on b, not move
        #expect(ring.currentEntry() == "b")
    }

    @Test func promoteCurrentToNewestOnNewestIsNoop() {
        // Promoting when already at newest leaves ring and cursor unchanged.
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move — now at newest)
        ring.promoteCurrentToNewest()
        #expect(ring.currentEntry() == "c")
        #expect(ring.count == 3)
    }

    @Test func promoteCurrentToNewestOnEmptyRingIsNoop() {
        let ring = ClipboardRing()
        ring.promoteCurrentToNewest() // must not crash
        #expect(ring.count == 0)
        #expect(ring.currentEntry() == nil)
    }
}
