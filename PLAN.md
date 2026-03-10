# cowpyfwend — Internal Engineering Plan

## Product Summary

cowpyfwend is a native macOS menu bar app that maintains an in-memory ring of all text strings the user copies to the clipboard. Global hotkeys allow silent backward and forward cycling through that ring, with each cycle writing the selected entry to the live system clipboard. No UI is shown during cycling. The app lives entirely in the menu bar and has no Dock presence.

The goal is a minimal, well-engineered tool that does one thing correctly, stays out of the way, and can be iterated safely.

---

## Locked Decisions

These decisions are fixed for V1 and must not be changed without an explicit spec update.

| Decision           | Value                                              |
| ------------------ | -------------------------------------------------- |
| Clipboard content  | Text only                                          |
| Storage            | In-memory only; nothing written to disk            |
| Cycle older hotkey | `Option+W` (keyCode 13, maskAlternate)             |
| Cycle newer hotkey | `Option+S` (keyCode 1, maskAlternate)              |
| Hotkey handling    | Fully swallowed — not passed through               |
| Filtering          | None — all text entries recorded                   |
| Duplicates         | Recorded as-is                                     |
| Empty strings      | Recorded as-is                                     |
| Whitespace-only    | Recorded as-is                                     |
| Pointer reset      | Resets to newest entry on every new copy           |
| Wraparound         | Enabled at both ends                               |
| Auto-paste         | Yes — Cmd+V simulated after each cycle             |
| Persistence        | Not in V1                                          |
| Launch at login    | Included via `SMAppService` (macOS 13+)            |
| Accessibility      | Required; must be surfaced in menu if not granted  |
| Minimum OS         | macOS 13.0 (Ventura)                               |
| Build tooling      | Xcode only                                         |
| App type           | Menu bar agent — `LSUIElement = YES`, no Dock icon |

---

## Detailed V1 Scope

### Clipboard Monitoring

- Poll `NSPasteboard.general` on a repeating timer (~0.5s interval)
- Detect new copies by comparing `NSPasteboard.changeCount` to last-seen value
- On change: read string value via `NSPasteboard.string(forType: .string)`
- Pass new string to ring, reset pointer to newest

### Clipboard Ring

- Array-backed in-memory store of `String` entries
- Integer cursor (index) representing current position
- `append(_:)` — adds entry to end, resets cursor to `count - 1`
- `cycleOlder()` — decrements cursor; wraps from 0 to `count - 1`
- `cycleNewer()` — increments cursor; wraps from `count - 1` to 0
- `currentEntry() -> String?` — returns entry at cursor; `nil` if empty
- `clear()` — empties store, resets cursor
- `count: Int` — number of stored entries

### Global Hotkeys

- `CGEventTap` on `.cgSessionEventTap` at `.headInsertEventTap` position
- Listen for `.keyDown` events
- Match `Option+W`: flags contain `.maskAlternate`, keyCode == 13
- Match `Option+S`: flags contain `.maskAlternate`, keyCode == 1
- On match: invoke callback, return `nil` from tap callback (swallows event)
- On non-match: return event unmodified
- Handle `CGEvent.tapDisabledByUserInput` and `CGEvent.tapDisabledByTimeout` to surface Accessibility loss

### Cycling Behavior

- On hotkey: cycle ring → read `currentEntry()` → if non-nil, write to `NSPasteboard`, then schedule debounced paste
- Write: `NSPasteboard.general.clearContents()` then `NSPasteboard.general.setString(_:forType:)`
- Debounce: paste fires 400ms after the last W/S press. Rapid cycling resets the timer each press.
- Simulate paste: post CGEvent Cmd+V (keyCode 9, `.maskCommand`) to `.cgSessionEventTap`
- Rapid W/S cycles update the clipboard each press; only the final resting entry gets pasted
- If ring is empty: hotkey is swallowed, clipboard unchanged, no paste scheduled

### Menu Bar UI

Menu items, in order:

1. Title: `cowpyfwend` (non-interactive label)
2. Separator
3. Toggle: `Enabled` / `Disabled` — controls monitoring and hotkey interception
4. Separator
5. Toggle: `Launch at Login` — `SMAppService` registration
6. Separator
7. Info: `History: N entries` (non-interactive)
8. Button: `Clear History` — calls `ring.clear()`
9. Separator
10. Status: `Accessibility: Granted` or `Accessibility: Not Granted` (non-interactive; tapping "Not Granted" opens System Settings)
11. Separator
12. `Quit cowpyfwend`

### Launch at Login

- `SMAppService.mainApp.register()` / `.unregister()`
- Read status with `SMAppService.mainApp.status`
- Surface toggle state from `status == .enabled`

### Permissions

- Check `AXIsProcessTrusted()` to determine Accessibility status
- If not trusted: `HotkeyEngine` is disabled; menu shows `Accessibility: Not Granted`
- On tap-disabled event: update AppController state, surface in menu
- Tapping "Not Granted" in menu opens Privacy & Security settings via `NSWorkspace`

---

## Non-Goals (V1)

- Rich clipboard types (images, files, attributed text, RTF, etc.)
- Popup history browser or search UI
- ~~HUD, overlay, or toast notifications~~ (minimal CycleHUD is now in scope — see Stage 6)
- Clipboard persistence to disk
- ~~Auto-paste into the focused app~~ (debounced auto-paste is in scope via CycleHUD dismiss)
- Cloud sync or cross-device support
- Analytics or telemetry
- Configurable hotkeys
- Configurable ring size
- Multiple named clipboards
- Any inline replacement beyond writing to `NSPasteboard`

---

## Architecture Overview

```
cowpyfwendApp (@main)
    └── MenuBarExtra
            └── MenuBarView ──observes──→ AppController
                                                ├── owns → ClipboardRing    (pure logic)
                                                ├── owns → ClipboardMonitor (platform)
                                                │              └── polls NSPasteboard
                                                ├── owns → HotkeyEngine     (platform)
                                                │              └── CGEventTap
                                                ├── owns → CycleHUD         (UI)
                                                │              └── NSPanel near cursor
                                                └── uses → LaunchAtLoginManager
```

Data flows in one direction: platform events → AppController → ClipboardRing → NSPasteboard write → MenuBarView reflects state.

---

## Major Components

### `ClipboardRing` — `Core/ClipboardRing.swift`

- Pure Swift class (reference semantics for observable mutations, no platform imports)
- Internal storage: `[String]`, cursor: `Int`
- No platform dependencies — fully unit-testable
- Public surface: `append(_:)`, `cycleOlder()`, `cycleNewer()`, `currentEntry() -> String?`, `clear()`, `count: Int`

### `ClipboardMonitor` — `Core/ClipboardMonitor.swift`

- Class; owns a `Timer` and tracks `NSPasteboard.general.changeCount`
- Calls `onNewEntry: (String) -> Void` when a new text entry is detected
- `start()` / `stop()` — controls the polling timer
- Platform-specific; not unit-testable in isolation

### `HotkeyEngine` — `Core/HotkeyEngine.swift`

- Class; manages a `CFMachPort` event tap via `CGEvent.tapCreate`
- Callbacks: `onCycleOlder: () -> Void`, `onCycleNewer: () -> Void`
- `enable()` / `disable()` — attaches/detaches from the run loop
- Returns `nil` from tap callback to swallow matched events
- Handles tap-disabled events; calls `onTapDisabled: () -> Void`
- Platform-specific; requires Accessibility

### `AppController` — `Controller/AppController.swift`

- `ObservableObject`; owns all core services
- `@Published var isEnabled: Bool`
- `@Published var historyCount: Int`
- `@Published var accessibilityGranted: Bool`
- `func onNewEntry(_ text: String)` — appends to ring, resets pointer
- `func cycleOlder()` / `func cycleNewer()` — cycle ring, write to NSPasteboard
- `func clearHistory()` — clears ring, updates historyCount
- `func toggleEnabled()` — starts/stops monitor and hotkey engine
- `func refreshAccessibilityStatus()` — polls `AXIsProcessTrusted()`

### `CycleHUD` — `UI/CycleHUD.swift`

- `NSPanel` subclass; non-activating, floats above all windows
- Appears near the current mouse cursor position on first W/S press
- Displays a single-line snippet of the current ring entry, updates on each cycle press
- Shows position indicator: e.g. `[2 / 5]`
- Auto-dismisses after 1.0s of no W/S presses; on dismiss: simulates Cmd+V paste
- `show(text:position:index:total:)` — updates content and (re)starts dismiss timer
- `hide()` — cancels timer, orders panel out without pasting
- Owned by `AppController`; called from `cycleOlder()` / `cycleNewer()`

### `MenuBarView` — `UI/MenuBarView.swift`

- SwiftUI `View`; observes `AppController` via `@EnvironmentObject` or `@StateObject`
- Renders all required menu items per spec
- No business logic; all actions delegate to `AppController` or `LaunchAtLoginManager`

### `LaunchAtLoginManager` — `Services/LaunchAtLoginManager.swift`

- Stateless wrapper; `register()`, `unregister()`, `isEnabled: Bool`
- Uses `SMAppService.mainApp`
- macOS 13+ only (minimum deployment target)

### `cowpyfwendApp` — `App/cowpyfwendApp.swift`

- `@main struct`; `App` conformance
- `MenuBarExtra("cowpyfwend", systemImage: "doc.on.clipboard")` with `MenuBarView`
- Creates and injects `AppController` as `@StateObject`
- `Info.plist`: `LSUIElement = YES`

---

## Data Flow

### New Copy

```
User copies text
→ NSPasteboard.general.changeCount increments
→ ClipboardMonitor detects difference on next poll
→ Reads NSPasteboard.string(forType: .string)
→ AppController.onNewEntry(text)
→ ClipboardRing.append(text)        [cursor resets to newest]
→ AppController publishes historyCount update
→ MenuBarView reflects new count
```

### Cycle Older (Option+W)

```
User presses Option+W
→ HotkeyEngine CGEventTap fires
→ Event matched; return nil (swallowed)
→ AppController.cycleOlder()
→ ClipboardRing.cycleOlder()
→ ClipboardRing.currentEntry() → text
→ NSPasteboard.general.clearContents()
→ NSPasteboard.general.setString(text, forType: .string)
```

### Cycle Newer (Option+S)

```
[identical flow, cycleNewer path]
```

### Enabled Toggle

```
User clicks Enabled toggle in menu
→ AppController.toggleEnabled()
→ if disabling: ClipboardMonitor.stop(), HotkeyEngine.disable()
→ if enabling:  ClipboardMonitor.start(), HotkeyEngine.enable() [if Accessibility granted]
→ @Published isEnabled flips
→ MenuBarView reflects new state
```

---

## Staged Roadmap

| Stage | Name                     | Description                                                    | Tests                      |
| ----- | ------------------------ | -------------------------------------------------------------- | -------------------------- |
| 0     | Docs                     | README.md, PLAN.md, .gitignore                                 | —                          |
| 1     | Scaffold                 | Menu bar app shell, LSUIElement, MenuBarExtra, Quit            | —                          |
| 2     | ClipboardRing            | Pure ring logic                                                | Full unit tests            |
| 3     | ClipboardMonitor         | NSPasteboard polling, onNewEntry callback                      | Manual                     |
| 4     | HotkeyEngine             | CGEventTap, key match, swallow                                 | Manual                     |
| 5     | AppController            | Full coordinator wiring all services                           | Unit tests for state logic |
| 6     | CycleHUD                 | Floating near-cursor panel, snippet + position, debounce paste | Manual                     |
| 7     | MenuBarView              | All required menu items, live state                            | Manual                     |
| 8     | LaunchAtLoginManager     | SMAppService wired to menu toggle                              | Manual                     |
| 9     | Accessibility Handling   | AXIsProcessTrusted, tap-disabled, menu surface                 | Manual                     |
| 10    | Integration & Acceptance | End-to-end manual, edge cases, polish                          | Manual + all tests green   |

Each stage must compile cleanly and pass all existing tests before the next stage begins.

---

## Stage-by-Stage Implementation Plan

### Stage 0 — Docs

- Replace `README.md` with product-stable documentation
- Create `PLAN.md` (this file)
- Add `.gitignore`
- Resolve `cowpyfwendXCODE/.git` (remove if spurious)
- **Done when:** Both files committed, repo is clean

### Stage 1 — Xcode Project Scaffold

- Create Xcode project: macOS App, SwiftUI, bundle ID `com.partypancake8.cowpyfwend`
- Set deployment target: macOS 13.0
- Set `LSUIElement = YES` in `Info.plist` (suppresses Dock icon and app switcher entry)
- Add `MenuBarExtra` to `@main` App struct with a system image icon
- Add a functional `Quit` menu item (`NSApplication.shared.terminate(nil)`)
- Delete default `ContentView.swift` and window group scaffolding
- Create source group structure: `App/`, `Core/`, `Controller/`, `UI/`, `Services/`
- **Done when:** App runs, menu bar icon appears, Quit works, no Dock icon, no warnings

### Stage 2 — ClipboardRing

- Implement `ClipboardRing` in `Core/ClipboardRing.swift`
- No imports beyond `Foundation`
- Add `ClipboardRingTests.swift` covering:
  - Empty state: `count == 0`, `currentEntry() == nil`
  - Single append: `count == 1`, `currentEntry()` returns it
  - Multiple appends: correct count, cursor at newest
  - `cycleOlder()` from newest: cursor moves back
  - `cycleOlder()` from oldest: wraps to newest
  - `cycleNewer()` from newest: wraps to oldest
  - `cycleNewer()` from oldest: cursor moves forward
  - Append resets cursor to newest regardless of current cursor position
  - `clear()`: count == 0, cursor reset, currentEntry == nil
  - Duplicate entries: both recorded, no deduplication
  - Empty string entry: recorded as-is
  - Whitespace-only entry: recorded as-is
- **Done when:** All tests pass, `ClipboardRing` has no platform imports

### Stage 3 — ClipboardMonitor

- Implement `ClipboardMonitor` in `Core/ClipboardMonitor.swift`
- `import AppKit`
- Polling interval constant: `0.5` seconds
- Track `lastChangeCount: Int`
- On timer fire: compare `NSPasteboard.general.changeCount` to `lastChangeCount`
- If changed: read string, guard non-nil, invoke `onNewEntry`
- `start()` creates and schedules timer; `stop()` invalidates it
- Wire to a stub call in `cowpyfwendApp` to verify console output
- **Done when:** Copy text in any app, see print output confirming detection; existing tests still pass

### Stage 4 — HotkeyEngine

- Implement `HotkeyEngine` in `Core/HotkeyEngine.swift`
- `import CoreGraphics`
- Create `CGEventTap` via `CGEvent.tapCreate`:
  - tap: `.cgSessionEventTap`
  - place: `.headInsertEventTap`
  - options: `.defaultTap`
  - eventsOfInterest: `.keyDown` mask
- In tap callback (C function or `@convention(c)` closure bridged via context pointer):
  - Read `CGEventGetIntegerValueField(event, .keyboardEventKeycode)`
  - Read `event.flags`
  - Match keyCode 13 + `.maskAlternate` → call `onCycleOlder`, return nil
  - Match keyCode 1 + `.maskAlternate` → call `onCycleNewer`, return nil
  - All other events: return `Unmanaged.passRetained(event)`
  - On `tapDisabledByUserInput` / `tapDisabledByTimeout` type: call `onTapDisabled`
- `enable()`: add tap to run loop source, enable tap
- `disable()`: disable tap, remove from run loop
- Initialize disabled; caller must invoke `enable()`
- Requires `AXIsProcessTrusted()` to be true at enable time
- Wire stub callbacks in app; verify in manual test
- **Done when:** Option+W and Option+S are intercepted and swallowed; other keys unaffected; existing tests pass

### Stage 5 — AppController

- Implement `AppController` in `Controller/AppController.swift`
- `ObservableObject`; injected as `@StateObject` in `cowpyfwendApp`
- Wire `ClipboardMonitor.onNewEntry` → `self.onNewEntry(_:)`
- Wire `HotkeyEngine.onCycleOlder` → `self.cycleOlder()`
- Wire `HotkeyEngine.onCycleNewer` → `self.cycleNewer()`
- Wire `HotkeyEngine.onTapDisabled` → `self.refreshAccessibilityStatus()`
- `cycleOlder()` / `cycleNewer()`: cycle ring, call `writeCurrentEntryToClipboard()`
- `writeCurrentEntryToClipboard()`: guard `currentEntry != nil`; clear pasteboard; set string
- `toggleEnabled()`: flip `isEnabled`, start/stop services accordingly
- `refreshAccessibilityStatus()`: set `accessibilityGranted = AXIsProcessTrusted()`
- Call `refreshAccessibilityStatus()` on init and on `NSWorkspace.didActivateApplicationNotification` (catch returning from Settings)
- Add unit tests for: state after init, toggleEnabled transitions, clearHistory resets count
- **Done when:** Copy text → history count increments; hotkeys cycle and update clipboard; disable stops both; tests pass

### Stage 6 — CycleHUD

- Implement `CycleHUD` in `UI/CycleHUD.swift`
- `NSPanel` with `NSWindowStyleMask`: `.borderless`, `.nonactivatingPanel`
- `NSWindowLevel.floating` — always above other windows, never steals focus
- Content: single `NSTextField` (non-editable) showing truncated current entry + `[index / total]`
- Position: near current `NSEvent.mouseLocation`, offset so it doesn't obscure the cursor
- `AppController` calls `hud.show(text:index:total:)` on every cycle press
- `show(...)` updates label, repositions near cursor, orders panel front, resets a 1.0s dismiss timer
- On timer fire: simulate Cmd+V paste, then hide panel
- `hide()` cancels timer and orders panel out without pasting (used on `clearHistory`, `toggleEnabled` disable)
- Remove debounce paste logic from `AppController.schedulePaste()` — CycleHUD owns the paste timing
- **Done when:** HUD appears near cursor on first W/S press, updates each press, auto-pastes and disappears after 1s of inactivity

### Stage 7 — MenuBarView

- Implement `MenuBarView` in `UI/MenuBarView.swift`
- All menu items per spec, in order
- `@EnvironmentObject var controller: AppController`
- Enabled toggle: `Button(controller.isEnabled ? "Enabled" : "Disabled")` → `controller.toggleEnabled()`
- History count: `Text("History: \(controller.historyCount) entries")`
- Clear history: `Button("Clear History")` → `controller.clearHistory()`
- Accessibility row: if not granted, button opens settings via `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)`
- Quit: `Button("Quit cowpyfwend")` → `NSApplication.shared.terminate(nil)`
- Launch at Login toggle: binding computed from `LaunchAtLoginManager` (wired fully in Stage 8)
- **Done when:** All menu items render, actions work, state reflects AppController changes

### Stage 8 — LaunchAtLoginManager

- Implement `LaunchAtLoginManager` in `Services/LaunchAtLoginManager.swift`
- `import ServiceManagement`
- `var isEnabled: Bool` → `SMAppService.mainApp.status == .enabled`
- `func register()` → `try SMAppService.mainApp.register()`
- `func unregister()` → `try SMAppService.mainApp.unregister()`
- Handle thrown errors; log to console
- Wire into `AppController` or pass directly to `MenuBarView` binding
- **Done when:** Launch at Login toggle persists across logout/login

### Stage 9 — Accessibility Permission Handling

- On app launch: call `AXIsProcessTrusted()` — if false, do NOT call with prompt dict yet
- On first `enable()` call: if not trusted, call `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` to trigger system prompt
- Surface state correctly in menu
- Register for `NSWorkspace.didActivateApplicationNotification` to refresh after user visits Settings
- Handle `onTapDisabled` to surface mid-session revocation
- **Done when:** Granting/revoking Accessibility is correctly reflected in menu at all times

### Stage 10 — Integration & Acceptance

- Run full acceptance checklist (see Acceptance Criteria)
- Fix any edge cases found during manual testing
- Ensure all unit tests pass
- Clean compile with no warnings
- Final git tag: `v0.1.0`

---

## Testing Strategy

### Unit Tests (automated, `cowpyfwendTests/`)

| Component       | Tests                                                                      |
| --------------- | -------------------------------------------------------------------------- |
| `ClipboardRing` | Comprehensive — all public methods, edge cases, wraparound, reset behavior |
| `AppController` | State transition tests using mock `ClipboardRing` if appropriate           |

### Manual Tests

| Component              | How to verify                                                                              |
| ---------------------- | ------------------------------------------------------------------------------------------ |
| `ClipboardMonitor`     | Copy text in any app; confirm `historyCount` increments in menu                            |
| `HotkeyEngine`         | Press Option+W / Option+S; confirm clipboard changes and keys do not appear in text fields |
| `MenuBarView`          | Visually inspect all menu items; toggle each; confirm state updates                        |
| `LaunchAtLoginManager` | Enable; log out and log back in; confirm app is running                                    |
| Accessibility handling | Revoke in Settings while app runs; confirm menu updates                                    |

### Platform-Specific Exclusions

`ClipboardMonitor`, `HotkeyEngine`, `LaunchAtLoginManager`, and `MenuBarView` are platform-specific and not unit-tested. Logic is intentionally kept minimal in these components to reduce surface area.

---

## Acceptance Criteria (V1 Done)

- [ ] App launches to menu bar with no Dock icon
- [ ] Every text copy is added to history ring without filtering
- [ ] `Option+W` cycles to an older entry and updates system clipboard; key is swallowed
- [ ] `Option+S` cycles to a newer entry and updates system clipboard; key is swallowed
- [ ] Wraparound works in both directions
- [ ] Pointer resets to newest on each new copy regardless of current position
- [ ] Menu shows correct history count at all times
- [ ] `Clear History` empties ring and resets count in menu
- [ ] Enabled/disabled toggle stops and starts monitoring and hotkeys
- [ ] `Launch at Login` toggle persists correctly across reboots
- [ ] Accessibility permission state is correctly reflected in menu
- [ ] Revoking Accessibility mid-session is reflected in menu
- [ ] Granting Accessibility and re-enabling starts hotkey interception
- [ ] No popup UI, overlay, HUD, or toast appears during cycling
- [ ] App compiles cleanly with zero warnings
- [ ] All unit tests pass

---

## Risks

| Risk                                                                             | Severity | Mitigation                                                                              |
| -------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------- |
| `cowpyfwendXCODE/.git` conflicts with parent repo's git tracking                 | High     | Remove before Stage 1; see setup instructions                                           |
| `CGEventTap` silently fails without Accessibility                                | High     | Always check `AXIsProcessTrusted()` before enabling; surface in menu                    |
| `CGEventTap` disabled mid-session on Accessibility revocation                    | Medium   | Handle `tapDisabledByUserInput/Timeout` event type; update menu state                   |
| NSPasteboard polling delay (~0.5s) causes missed first copy after disable→enable | Low      | Acceptable for V1; document as known behavior                                           |
| `MenuBarExtra` API shape may differ slightly between macOS 13/14/15              | Low      | Test on minimum deployment target (macOS 13); use conditional APIs only where necessary |
| `SMAppService` registration failure (sandboxing, entitlements)                   | Medium   | Wrap in try/catch; log error; surface gracefully                                        |

---

## Git / Checkpoint Workflow

- **Commit format:** `[Stage N] Description`
  - Example: `[Stage 2] Add ClipboardRing with full unit tests`
- **Commit after each stable stage** — never advance with broken build or failing tests
- **Bugfix commits:** `[fix] Short description` when restoring green build between stages
- **No force-push** to main unless explicitly requested
- **Tag** `v0.1.0` after Stage 9 acceptance criteria pass

---

## Definition of Done (per stage)

A stage is done when all of the following are true:

1. Code compiles with no errors
2. No new Xcode warnings introduced
3. All unit tests pass (⌘U green)
4. Manual verification steps for the stage have been performed çd confirmed
5. Git commit has been made with the correct message format

---

## Current Status

**Stage 0 complete.** Docs written and committed.  
**Stage 1 next:** Xcode project scaffold — menu bar shell, LSUIElement, MenuBarExtra, Quit.
