# copyfwend

> **v0.1.0** — all 10 stages shipped.

A native macOS menu bar app that maintains a text-only clipboard history ring and lets you silently cycle the live system clipboard backward and forward with global hotkeys.

A small floating HUD appears near the cursor while you cycle, showing the current entry and a countdown until it auto-pastes. No chooser. No palette. No search UI. Just your clipboard history, cycling silently behind the scenes.

---

## What It Does

- Monitors your clipboard and records every text entry you copy
- `Option+W` cycles to an older clipboard entry and writes it to the live system clipboard
- `Option+S` cycles to a newer clipboard entry and writes it to the live system clipboard
- After a short idle period a floating HUD auto-pastes the selected entry via Cmd+V and dismisses
- Hotkeys are fully swallowed — they do not pass through to other apps
- Runs always-on from the menu bar with no Dock presence

## V1 Scope

- Text-only clipboard history
- In-memory history only — nothing written to disk
- `Option+W` = cycle older
- `Option+S` = cycle newer
- All text entries recorded — no filtering of duplicates, empty strings, or whitespace
- Pointer resets to newest entry on each new copy
- Wraparound enabled at both ends of the ring
- Menu bar exposes:
  - Enabled / disabled toggle
  - Launch at login toggle
  - History count (read-only)
  - Clear history
  - Permission / trust state
  - Quit

## Non-Goals (V1)

- No rich clipboard types (images, files, attributed text, etc.)
- No popup history browser or search UI
- No clipboard persistence to disk
- No cloud sync or cross-device support
- No analytics or telemetry
- No configurable hotkeys or ring size

## Stack

- Swift
- SwiftUI — menu bar shell (`MenuBarExtra`), minimal settings surface
- AppKit / CoreGraphics — where required for platform integration
- `NSPasteboard` — clipboard read/write
- Quartz Event Services (`CGEventTap`) — global hotkey interception and swallowing
- `SMAppService` — launch at login (macOS 13+)
- In-memory history store

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 16 or later
- Accessibility permission required at runtime for global hotkey interception

## Local Development

### Build & Run

Open `copyfwendXCODE/copyfwend.xcodeproj` in Xcode and run the `copyfwend` scheme.

> **Note:** Xcode created the project as `copyfwendXCODE/copyfwend.xcodeproj` with sources at `copyfwendXCODE/copyfwend/`.

On first launch, the app will request Accessibility permission. Grant it in:  
**System Settings → Privacy & Security → Accessibility**

The app lives in the menu bar. There is no Dock icon.

### Run Tests

In Xcode: **Product → Test** (`⌘U`), or select the `copyfwendTests` target.

Tests cover pure logic only (primarily `ClipboardRing`). Platform-specific components are verified manually.

### VS Code

You may browse and edit source files in VS Code alongside Xcode. Xcode is the build and test source of truth — do not rely on any non-Xcode build tooling.

## Repo Structure

```
copyfwend/
├── README.md                        ← This file
├── PLAN.md                          ← Internal engineering plan and roadmap
├── .gitignore
└── copyfwendXCODE/                 ← Xcode project root
    ├── copyfwend.xcodeproj/
    ├── copyfwend/                  ← App source
    │   ├── App/                     ← Entry point and app struct
    │   ├── Core/                    ← Pure logic and platform services
    │   ├── Controller/              ← App coordinator
    │   ├── UI/                      ← SwiftUI views
    │   └── Services/                ← Launch at login, etc.
    └── copyfwendTests/             ← Unit tests
```

## Status

**v0.1.0 — complete.** All acceptance criteria met. See [PLAN.md](PLAN.md) for the full engineering record.
