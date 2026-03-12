# copyfwend — Internal Engineering Plan

## Product Summary

copyfwend is a native macOS menu bar app that maintains an in-memory ring of all text strings the user copies to the clipboard. Global hotkeys allow silent backward and forward cycling through that ring, with each cycle writing the selected entry to the live system clipboard. No UI is shown during cycling. The app lives entirely in the menu bar and has no Dock presence.

The goal is a minimal, well-engineered tool that does one thing correctly, stays out of the way, and can be iterated safely.

---

## Locked Decisions

These decisions are fixed for V1 and must not be changed without an explicit spec update.

| Decision           | Value                                                                           |
| ------------------ | ------------------------------------------------------------------------------- |
| Clipboard content  | Text only                                                                       |
| Storage            | In-memory only; nothing written to disk                                         |
| Cycle older hotkey | `Option+W` (keyCode 13, maskAlternate)                                          |
| Cycle newer hotkey | `Option+S` (keyCode 1, maskAlternate)                                           |
| Cancel hotkey      | `Option+Q` (keyCode 12, maskAlternate) — cancel paste, active only during cycle |
| Erase hotkey       | `Option+E` (keyCode 14, maskAlternate) — clear all history, always active       |
| Paste trigger      | Option key release (not auto-timer) — HUD stays visible until release           |
| Hotkey handling    | Fully swallowed — not passed through                                            |
| Filtering          | None — all text entries recorded                                                |
| Duplicates         | Recorded as-is                                                                  |
| Empty strings      | Recorded as-is                                                                  |
| Whitespace-only    | Recorded as-is                                                                  |
| Pointer reset      | Resets to newest entry on every new copy                                        |
| Wraparound         | Enabled at both ends                                                            |
| Auto-paste         | Yes — Cmd+V simulated on Option release                                         |
| App Sandbox        | Disabled — `ENABLE_APP_SANDBOX = NO` (CGEventTap requires non-sandboxed)        |
| Persistence        | Not in V1                                                                       |
| Launch at login    | Included via `SMAppService` (macOS 13+)                                         |
| Accessibility      | Required; must be surfaced in menu if not granted                               |
| Minimum OS         | macOS 13.0 (Ventura)                                                            |
| Build tooling      | Xcode only                                                                      |
| App type           | Menu bar agent — `LSUIElement = YES`, no Dock icon                              |

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
- Listen for `.keyDown` and `.flagsChanged` events
- Match `Option+W`: flags contain `.maskAlternate`, keyCode == 13
- Match `Option+S`: flags contain `.maskAlternate`, keyCode == 1
- Match `Option+Q`: flags contain `.maskAlternate`, keyCode == 12 (cancel cycle, only during active cycling session)
- Match `Option+E`: flags contain `.maskAlternate`, keyCode == 14 (erase all history, always active regardless of cycling state)
- On match: invoke callback, return `nil` from tap callback (swallows event)
- On non-match: return event unmodified
- Handle `CGEvent.tapDisabledByUserInput` and `CGEvent.tapDisabledByTimeout` to surface Accessibility loss
- `isCycling` flag: set `true` on W/S press, set `false` on Q press, E press, or Option release; `resetCyclingSession()` clears it without firing the release callback

### Cycling Behavior

- On hotkey: cycle ring → read `currentEntry()` → if non-nil, write to `NSPasteboard`, show/update CycleHUD
- Write: `NSPasteboard.general.clearContents()` then `NSPasteboard.general.setString(_:forType:)`
- Paste on release: paste fires when the user releases the Option modifier key after cycling. The HUD stays visible until Option is released or cycling is interrupted.
- Simulate paste: post CGEvent Cmd+V (keyCode 9, `.maskCommand`) to `.cgSessionEventTap`
- Rapid W/S cycles update the clipboard each press; only the final resting entry (selected when Option is released) gets pasted
- If ring is empty: hotkey is swallowed, clipboard unchanged, no paste
- `Option+Q` during a session: cancel cycle, hide HUD, no paste
- `Option+E` at any time: erase all history, reset cycling state, hide HUD; **no paste fires even if Option is held and released afterward**
- `commitPaste()` guards on HUD visibility: if the HUD is not visible (hidden by erase or cancel), releasing Option is a no-op — no silent paste

### Menu Bar UI

Menu items, in order:

1. Title: `copyfwend` (non-interactive label)
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
12. `Quit copyfwend`

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
- ~~Auto-paste into the focused app~~ (paste-on-release is in scope via CycleHUD + Option key release)
- Cloud sync or cross-device support
- Analytics or telemetry
- Configurable hotkeys
- Configurable ring size
- Multiple named clipboards
- Any inline replacement beyond writing to `NSPasteboard`

---

## Architecture Overview

```
copyfwendApp (@main)
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
- Callbacks: `onCycleOlder: () -> Void`, `onCycleNewer: () -> Void`, `onOptionReleased: () -> Void`
- `enable()` / `disable()` — attaches/detaches from the run loop
- Returns `nil` from tap callback to swallow matched W/S events; never swallows `flagsChanged`
- Handles tap-disabled events; calls `onTapDisabled: () -> Void`
- Tracks `isCycling: Bool`; set to `true` on W/S press, cleared on Option release; `resetCyclingSession()` clears without firing
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
- Displays a snippet of the current ring entry, updates on each cycle press
- Shows position indicator: e.g. `[2 / 5]`
- Paste fires when `commitPaste()` is called (triggered by `AppController` on Option key release)
- `show(text:index:total:)` — updates content, repositions near cursor
- `commitPaste()` — **guards on `isVisible`**; if panel is hidden (e.g. after erase or cancel), returns immediately without pasting; otherwise simulates Cmd+V paste, fires `onPaste`, hides panel
- `hide()` — orders panel out without pasting
- Owned by `AppController`; called from `cycleOlder()` / `cycleNewer()` / `commitPaste()`

### `MenuBarView` — `UI/MenuBarView.swift`

- SwiftUI `View`; observes `AppController` via `@EnvironmentObject` or `@StateObject`
- Renders all required menu items per spec
- No business logic; all actions delegate to `AppController` or `LaunchAtLoginManager`

### `LaunchAtLoginManager` — `Services/LaunchAtLoginManager.swift`

- Stateless wrapper; `register()`, `unregister()`, `isEnabled: Bool`
- Uses `SMAppService.mainApp`
- macOS 13+ only (minimum deployment target)

### `copyfwendApp` — `App/copyfwendApp.swift`

- `@main struct`; `App` conformance
- `MenuBarExtra("copyfwend", systemImage: "doc.on.clipboard")` with `MenuBarView`
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

| Stage | Name                     | Description                                                             | Tests                      |
| ----- | ------------------------ | ----------------------------------------------------------------------- | -------------------------- |
| 0     | Docs                     | README.md, PLAN.md, .gitignore                                          | —                          |
| 1     | Scaffold                 | Menu bar app shell, LSUIElement, MenuBarExtra, Quit                     | —                          |
| 2     | ClipboardRing            | Pure ring logic                                                         | Full unit tests            |
| 3     | ClipboardMonitor         | NSPasteboard polling, onNewEntry callback                               | Manual                     |
| 4     | HotkeyEngine             | CGEventTap, key match, swallow                                          | Manual                     |
| 5     | AppController            | Full coordinator wiring all services                                    | Unit tests for state logic |
| 6     | CycleHUD                 | Floating near-cursor panel, snippet + position, paste on Option release | Manual                     |
| 7     | MenuBarView              | All required menu items, live state                                     | Manual                     |
| 8     | LaunchAtLoginManager     | SMAppService wired to menu toggle                                       | Manual                     |
| 9     | Accessibility Handling   | AXIsProcessTrusted, tap-disabled, menu surface                          | Manual                     |
| 10    | Integration & Acceptance | End-to-end manual, edge cases, polish                                   | Manual + all tests green   |

Each stage must compile cleanly and pass all existing tests before the next stage begins.

---

## Stage-by-Stage Implementation Plan

### Stage 0 — Docs

- Replace `README.md` with product-stable documentation
- Create `PLAN.md` (this file)
- Add `.gitignore`
- Resolve `copyfwendXCODE/.git` (remove if spurious)
- **Done when:** Both files committed, repo is clean

### Stage 1 — Xcode Project Scaffold

- Create Xcode project: macOS App, SwiftUI, bundle ID `com.partypancake8.copyfwend`
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
- Wire to a stub call in `copyfwendApp` to verify console output
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
- `ObservableObject`; injected as `@StateObject` in `copyfwendApp`
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

### Stage 6 — CycleHUD ✅

- `UI/CycleHUD.swift` — `NSPanel` subclass, `.borderless + .nonactivatingPanel`, `NSWindowLevel.floating`
- `NSVisualEffectView` content with `.popover` material (frosted glass, adaptive light/dark), 8pt corner radius
- Main label: 13pt monospaced, `.labelColor`, word-wrap up to 5 lines
- Displays: normalized entry text (real newlines preserved) + `[N / Total]` where 1 = most recent
- Dynamic sizing: width shrinks to content or expands to `min(620pt, 40% screen width)`; height measured via `boundingRect` per wrapped content; char cap computed from font metrics × maxLines × screen width
- Position: `NSEvent.mouseLocation + (16, 20)` offset, clamped to visible screen frame
- **Paste on Option release**: no auto-dismiss timer; HUD stays visible until `commitPaste()` is called
- `commitPaste()` → `pasteAndHide()` → simulate Cmd+V, fire `onPaste` callback, hide panel
- `onPaste` callback → `AppController` → `ring.promoteCurrentToNewest()` — moves pasted entry to newest ring position so clipboard state and ring order agree
- `hide()` orders panel out without pasting
- `ClipboardRing.currentIndex: Int?` added to expose cursor position for `[N / Total]` display
- `ClipboardRing.promoteCurrentToNewest()` added; 5 new unit tests; total 31 tests passing
- **Done when:** HUD appears near cursor on first W/S, updates each press, pastes + disappears on Option release

### Stage 7 — MenuBarView

- Implement `MenuBarView` in `UI/MenuBarView.swift`
- All menu items per spec, in order
- `@EnvironmentObject var controller: AppController`
- Enabled toggle: `Button(controller.isEnabled ? "Enabled" : "Disabled")` → `controller.toggleEnabled()`
- History count: `Text("History: \(controller.historyCount) entries")`
- Clear history: `Button("Clear History")` → `controller.clearHistory()`
- Accessibility row: if not granted, button opens settings via `NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)`
- Quit: `Button("Quit copyfwend")` → `NSApplication.shared.terminate(nil)`
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

### Unit Tests (automated, `copyfwendTests/`)

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

- [x] App launches to menu bar with no Dock icon
- [x] Every text copy is added to history ring without filtering
- [x] `Option+W` cycles to an older entry and updates system clipboard; key is swallowed
- [x] `Option+S` cycles to a newer entry and updates system clipboard; key is swallowed
- [x] Wraparound works in both directions
- [x] Pointer resets to newest on each new copy regardless of current position
- [x] Menu shows correct history count at all times
- [x] `Clear History` empties ring and resets count in menu
- [x] Enabled/disabled toggle stops and starts monitoring and hotkeys
- [x] `Launch at Login` toggle persists correctly across reboots
- [x] Accessibility permission state is correctly reflected in menu
- [x] Revoking Accessibility mid-session is reflected in menu
- [x] Granting Accessibility and re-enabling starts hotkey interception
- [x] CycleHUD appears near cursor during cycling, pastes on Option key release (Stage 6, in scope)
- [x] App compiles cleanly with zero warnings
- [x] All unit tests pass

---

## Risks

| Risk                                                                             | Severity | Mitigation                                                                              |
| -------------------------------------------------------------------------------- | -------- | --------------------------------------------------------------------------------------- |
| `copyfwendXCODE/.git` conflicts with parent repo's git tracking                  | High     | Remove before Stage 1; see setup instructions                                           |
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

**Stage 10 complete. All stages shipped. Tagged `v0.1.0`. Post-release improvements merged.**

| Stage                         | Status                   |
| ----------------------------- | ------------------------ |
| 0 — Docs                      | ✅                       |
| 1 — Scaffold                  | ✅                       |
| 2 — ClipboardRing             | ✅ 31 unit tests passing |
| 3 — ClipboardMonitor          | ✅                       |
| 4 — HotkeyEngine              | ✅                       |
| 5 — AppController             | ✅                       |
| 6 — CycleHUD                  | ✅                       |
| 7 — MenuBarView               | ✅                       |
| 8 — LaunchAtLoginManager      | ✅                       |
| 9 — Accessibility Handling    | ✅                       |
| 10 — Integration & Acceptance | ✅                       |

### Post-v0.1.0 Changes

| Commit | Description |
| ------ | ----------- |
| `[feat]` | **Paste on Option release** — removed auto-dismiss timer from CycleHUD; paste fires when user releases the Option modifier key. `HotkeyEngine` gained `.flagsChanged` monitoring and `onOptionReleased` callback; `AppController` wires it to `hud.commitPaste()`. |
| `[feat]` | **Option+E — erase all history** — new global hotkey (keyCode 14); fires at any time (cycling or not); resets `isCycling`; wired to `AppController.clearHistory()`. |
| `[fix]` | **Disable App Sandbox** — `ENABLE_APP_SANDBOX = YES` was silently blocking all `CGEventTap` creation; NSPasteboard monitoring still worked inside the sandbox but hotkeys didn't. Set `ENABLE_APP_SANDBOX = NO` in both Debug and Release. |
| `[fix]` | **Prevent silent paste after erase** — `AppController.commitPaste()` now guards on `hud.isVisible`; if the HUD is hidden (e.g. cleared by Option+E mid-cycle), releasing Option is a no-op and no Cmd+V is simulated. |
