import Testing
@testable import cowpyfwend

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

    @Test func cycleOlderFromOldestWrapsToNewest() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleOlder() // c (no move)
        ring.cycleOlder() // b
        ring.cycleOlder() // a
        ring.cycleOlder() // wraps → c
        #expect(ring.currentEntry() == "c")
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

    @Test func cycleNewerFromNewestWrapsToOldest() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleNewer() // c (no move)
        ring.cycleNewer() // wraps → a
        #expect(ring.currentEntry() == "a")
    }

    @Test func cycleNewerFromOldestMovesForwardOne() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        ring.cycleNewer() // c (no move)
        ring.cycleNewer() // wraps → a
        ring.cycleNewer() // b
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

    @Test func fullCycleOlderReturnsToStart() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        // First press: no move (c). Then step through b, a, wrap back to c.
        ring.cycleOlder() // c (no move)
        ring.cycleOlder() // b
        ring.cycleOlder() // a
        ring.cycleOlder() // wraps → c
        #expect(ring.currentEntry() == "c")
    }

    @Test func fullCycleNewerReturnsToStart() {
        let ring = ClipboardRing()
        ring.append("a")
        ring.append("b")
        ring.append("c")
        // First press: no move (c). Then wrap to a, step b, step c.
        ring.cycleNewer() // c (no move)
        ring.cycleNewer() // wraps → a
        ring.cycleNewer() // b
        ring.cycleNewer() // c
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
        ring.cycleOlder() // wraps — still "only"
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
}
