# cowpyfwend – Website Build Instructions for AI

This document is a plain-text plan that instructs an AI (or developer) to build a
marketing / project website for **cowpyfwend**, a native macOS menu-bar clipboard
history app. The site should look polished, professional, and developer-friendly.
Do NOT build anything in this file; this is the specification only.

---

## 1. Project Overview (for the AI's context)

**cowpyfwend** is a lightweight, native macOS menu-bar application that keeps a
silent, in-memory clipboard history ring and lets the user cycle through it with
global hotkeys:

- **Option + W** — step backward (older entries)
- **Option + S** — step forward (newer entries)

Every time a hotkey is pressed, the selected entry is instantly written to the
system clipboard and auto-pasted (Cmd+V simulated). A floating, translucent
"HUD" panel near the cursor shows the current entry, its position in the ring
(e.g., "3 / 12"), and a countdown timer.

Key facts to weave into copy and visuals:
- Runs entirely in the menu bar — no Dock icon
- Nothing written to disk; fully in-memory (privacy-first)
- No external dependencies — pure Swift + system frameworks
- macOS 13 Ventura minimum; Xcode 15+
- Accessibility permission required for global hotkey interception
- 31 comprehensive unit tests on the core ring logic
- Hotkeys are swallowed (not passed to other apps)
- HUD dismiss delay is logarithmic: short text ≈ 0.9 s, long text ≈ 3.0 s (capped)

---

## 2. Site Goals

1. Communicate what the app does in five seconds or less.
2. Show a live-feeling demo (animated or video) of the HUD cycling through history.
3. Present cool figures / stats (architecture, test coverage, etc.).
4. Give clear installation / build instructions.
5. Link to the GitHub repository.
6. Look great on macOS Safari, Chrome, and Firefox (desktop primary; mobile-friendly is a bonus).

---

## 3. Tech Stack Recommendation

- **Framework:** Plain HTML + CSS + a little vanilla JavaScript (or Astro / Next.js if the AI prefers a static-site generator)
- **Styling:** Tailwind CSS (utility-first) or a custom CSS file — whichever the AI is most fluent with
- **Animations:** CSS keyframes or GSAP for the HUD demo
- **Fonts:** System font stack (San Francisco / -apple-system) to feel native on macOS; monospaced sections can use `ui-monospace` / `SF Mono`
- **Color scheme:** Dark mode primary (slate-900 / zinc-900 background) with an accent of electric indigo or macOS-blue. Provide a light-mode variant via `prefers-color-scheme`.
- **No build tool required** unless the AI chooses a framework — keep it simple.

---

## 4. Page Layout & Sections

Build a single-page site (one HTML file, one CSS file, one JS file max) with
smooth scroll between these sections:

### 4.1 Hero Section

- Full-viewport-height opening panel.
- **Headline:** "Your clipboard has a memory now." (or similar punchy line)
- **Subheadline:** One sentence explaining the app.
- **CTA buttons:**
  - "Download on GitHub" (links to the repo releases page)
  - "See How It Works" (smooth-scrolls to the demo section)
- **Background:** Subtle animated noise / grain texture or a dark macOS-style wallpaper blur. Do not use solid plain black.
- **Hero graphic:** An animated mock-up of the macOS menu bar with the cowpyfwend icon and, floating beside it, the HUD panel cycling through example clipboard entries (see Section 5 for demo details).

### 4.2 Feature Highlights (3-column grid, or cards)

Six feature cards, each with an icon, short title, and one-sentence description:

| Icon suggestion | Title | Description |
|---|---|---|
| ⌛ or cycling arrows | Silent Cycling | Cycle through your full clipboard history with Option+W / Option+S — no popup menu, no friction. |
| 🔒 | Privacy First | Nothing ever written to disk. All history lives in memory and disappears when you quit. |
| 🎯 | Smart Auto-Paste | Selecting an entry auto-pastes it into whatever you're typing. No extra keypress needed. |
| 🍎 | Native macOS | Written in pure Swift with system frameworks only. Zero external dependencies. Feels at home on macOS. |
| 🕒 | Adaptive HUD | The floating HUD adjusts its dismiss timer to the length of your text — quick for short snippets, longer for paragraphs. |
| ♻️ | Wraparound Ring | The history wraps at both ends, so you can keep cycling in either direction without hitting a dead end. |

### 4.3 Demo Section (most important section)

**Goal:** Give visitors a tactile feel for the app without installing it.

Build a CSS/JS animated "demo terminal" or "app mockup" that plays through the
following scenario automatically (loops every 8–10 seconds):

**Script for the animation:**

1. A macOS-style desktop background is shown (blurred dark wallpaper).
2. A text editor window (fake, drawn in CSS) is visible with a cursor blinking.
3. Text label fades in: "You've copied several things…"
4. Four clipboard bubbles slide in from the right and stack up in a "history" visualization:
   - `git commit -m "fix: null pointer in ring"`
   - `https://github.com/partypancake8/cowpyfwend`
   - `Option + W to go back`
   - `cowpyfwend — clipboard history ring`
5. The user presses **Option+W** (show a keyboard pill animation: `⌥ W`).
6. A frosted-glass HUD panel fades in near the cursor:
   - Shows the text: `Option + W to go back`
   - Shows `[ 2 / 4 ]` in the corner
   - A countdown arc shrinks around the timer digit
7. The HUD fades out, and the text appears pasted into the fake text editor.
8. The keyboard pill shows `⌥ W` again.
9. HUD updates to: `git commit -m "fix: null pointer in ring"` / `[ 3 / 4 ]`
10. Loop restarts with a soft crossfade.

**Notes for the AI building this:**
- The HUD should be rendered with `backdrop-filter: blur(20px)` + semi-transparent
  dark background to mimic the real NSVisualEffectView popover material.
- The ring position indicator (e.g., `2 / 4`) should use monospaced digits.
- The countdown can be a shrinking circle SVG stroke-dashoffset animation.
- Keep the animation speed comfortable — not too fast, not too slow.

### 4.4 Architecture / "How It Works" Diagram

A clean architecture diagram (rendered in SVG or drawn with CSS boxes/arrows)
showing the four main layers:

```
┌─────────────────────────────────────────────────────┐
│                     Menu Bar UI                      │
│           MenuBarView (SwiftUI MenuBarExtra)         │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│                  AppController                       │
│         (Orchestrates all state & callbacks)         │
└──────┬───────────────────────────────────┬──────────┘
       │                                   │
┌──────▼──────────┐             ┌──────────▼──────────┐
│ ClipboardMonitor│             │   HotkeyEngine       │
│ (polls NSPaste- │             │  (CGEventTap global  │
│  board @ 0.5 s) │             │   hotkey intercept)  │
└──────┬──────────┘             └──────────┬───────────┘
       │                                   │
       └──────────────┬────────────────────┘
                      │
          ┌───────────▼────────────┐
          │      ClipboardRing     │
          │  (pure Swift; in-mem   │
          │   array + cursor)      │
          └────────────────────────┘
                      │
          ┌───────────▼────────────┐
          │        CycleHUD        │
          │  (floating NSPanel +   │
          │   countdown + paste)   │
          └────────────────────────┘
```

Render this as a clean, dark-mode SVG diagram with labeled boxes and arrows.
Use the same accent color as the rest of the site.

### 4.5 Cool Figures / Stats Section

Present these figures in large-number "stat card" style (big number + label below):

| Stat | Value | Label |
|---|---|---|
| Lines of source code | ~700 | Swift source lines |
| Unit tests | 31 | Passing tests on ClipboardRing |
| External dependencies | 0 | Zero third-party packages |
| Clipboard poll interval | 0.5 s | Real-time monitoring |
| HUD max width | 620 pt | Or 40% of screen width |
| HUD max lines | 5 | Before text is truncated |
| HUD max dismiss delay | 3.0 s | Logarithmic scaling |
| macOS minimum | 13.0 | Ventura and later |
| Hotkeys | 2 | Option+W (older), Option+S (newer) |

Animate each number counting up from 0 when the section scrolls into view
(use IntersectionObserver in JS).

### 4.6 Installation / Build Instructions

A code-block styled section with dark background and copy-to-clipboard button.
Content:

**Requirements:**
- macOS 13.0 (Ventura) or later
- Xcode 15 or later

**Steps:**
```
1. Clone the repository
   git clone https://github.com/partypancake8/cowpyfwend.git

2. Open the Xcode project
   open cowpyfwendXCODE/cowpyfwend.xcodeproj

3. Build & Run
   Press ⌘R in Xcode

4. Grant Accessibility permission
   System Settings → Privacy & Security → Accessibility → Enable cowpyfwend

5. App appears in the menu bar — start copying!
```

After granting permission, the app starts monitoring the clipboard immediately.
Use Option+W and Option+S to cycle through history in any app.

### 4.7 Footer

- App name + tagline: "cowpyfwend — your clipboard, with memory."
- GitHub link (icon + text)
- "Built with Swift & system frameworks. No telemetry. No phoning home."
- Copyright / license line (MIT if applicable — check the repo)

---

## 5. Visual Style Guide

### Colors (dark mode default)
| Token | Hex | Usage |
|---|---|---|
| `--bg-base` | `#0f1117` | Page background |
| `--bg-surface` | `#1a1d27` | Cards, HUD mock-up |
| `--bg-elevated` | `#252836` | Code blocks, diagram boxes |
| `--accent` | `#6366f1` | Indigo — CTAs, highlights, arrows |
| `--accent-light` | `#a5b4fc` | Hover states, stat numbers |
| `--text-primary` | `#f1f5f9` | Body text |
| `--text-muted` | `#94a3b8` | Secondary text, labels (NOTE: verify contrast against bg-surface and bg-elevated; if < 4.5:1, lighten to `#b0bec5` or similar to meet WCAG AA) |
| `--green` | `#22c55e` | "Passing tests" badge |
| `--border` | `rgba(255,255,255,0.08)` | Card borders |

### Typography
- **Headings:** `font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif`; weight 700
- **Body:** Same family, weight 400, `font-size: 1rem`, `line-height: 1.7`
- **Code / monospace:** `ui-monospace, "SF Mono", "Fira Code", monospace`
- **Stat numbers:** Very large (4–6rem), weight 800, accent-light color

### Spacing & Layout
- Max content width: 1100px, centered
- Section padding: `6rem` vertical
- Card gap: `1.5rem`
- Border radius on cards: `12px`; on code blocks: `8px`
- Subtle grain/noise texture overlay at 3–5% opacity across the entire page

---

## 6. Interactions & Micro-animations

- **Scroll-triggered fade-in** for each section (translate Y + opacity, 0.4 s ease-out)
- **Stat counter animation** (IntersectionObserver, count-up over 1.5 s)
- **Demo animation** (auto-playing loop, 8–10 s cycle, no user input required)
- **Copy-to-clipboard** button on code blocks (icon toggles to checkmark on copy)
- **Keyboard pill animation** in demo: pill appears, scales up slightly, then fades (0.3 s)
- **HUD mock-up** fade-in/out in demo: `opacity` + `transform: scale(0.95 → 1.0)`, 0.2 s

---

## 7. Assets the AI Should Generate or Source

| Asset | How to obtain |
|---|---|
| macOS menu bar mock-up | Draw in CSS (dark bar at top, white icons, app icon) |
| HUD panel | Draw in CSS with `backdrop-filter: blur` |
| App icon placeholder | Use the clipboard emoji 📋 styled in a rounded-square |
| Architecture diagram | Render as inline SVG |
| Keyboard pill (⌥ W) | CSS `kbd` element styled like a macOS key cap |
| Stat cards | Pure CSS |
| Background texture | CSS `background-image` using an SVG feTurbulence noise filter (generate a `<filter id="noise">` with `<feTurbulence type="fractalNoise" baseFrequency="0.65" numOctaves="3"/>` and `<feColorMatrix type="saturate" values="0"/>`, then reference it on a pseudo-element). Do not use a literal `…` placeholder — write the full inline SVG. |

Do NOT hotlink any external images. Everything should be self-contained in the
HTML/CSS/JS files.

---

## 8. File Structure the AI Should Produce

```
website/
├── index.html          ← entire single-page site
├── style.css           ← all styles (or inline in <style> if the AI prefers)
└── main.js             ← demo animation + scroll effects + stat counters
```

Optionally the AI may inline the CSS and JS into index.html for a true
single-file delivery.

---

## 9. Accessibility Requirements

- All images / SVGs must have `alt` or `aria-label`
- Color contrast ≥ 4.5:1 for body text (WCAG AA)
- Demo animation must have a `prefers-reduced-motion` media query that disables
  or simplifies animations
- Interactive elements (buttons, links) must have visible focus outlines
- The demo section should have an `aria-label="App demo animation"` wrapper

---

## 10. SEO & Meta Tags

Include in `<head>`:

```html
<title>cowpyfwend — Clipboard History Ring for macOS</title>
<meta name="description" content="A native macOS menu-bar app that keeps your clipboard history in a silent ring. Cycle through past copies with Option+W and Option+S — no fuss, no UI clutter.">
<meta property="og:title" content="cowpyfwend">
<meta property="og:description" content="Silent clipboard history ring for macOS. Cycle through your past copies with global hotkeys.">
<meta property="og:type" content="website">
<meta name="theme-color" content="#0f1117">
<link rel="icon" href="data:image/svg+xml,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%20100%20100%22%3E%3Ctext%20y%3D%22.9em%22%20font-size%3D%2290%22%3E%F0%9F%93%8B%3C%2Ftext%3E%3C%2Fsvg%3E">
```

---

## 11. Do NOT Include

- No analytics / tracking scripts (no GA, no Plausible, nothing)
- No cookie banners
- No social media share buttons
- No email signup forms
- No paid font CDN calls
- No frameworks that require a Node.js build step unless the AI is comfortable
  with static output

---

## 12. Quality Checklist (AI should self-verify before finishing)

- [ ] Page loads with no console errors
- [ ] Demo animation loops cleanly with no janky resets
- [ ] All stat numbers animate on scroll into view
- [ ] Dark-mode colors used throughout; light-mode variant tested
- [ ] `prefers-reduced-motion` disables animations
- [ ] All text is legible (contrast checked)
- [ ] Code block copy button works
- [ ] GitHub link opens in a new tab
- [ ] Page is responsive down to 375px width (iPhone SE)
- [ ] No external network requests at all (fully self-contained)
