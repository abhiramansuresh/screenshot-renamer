# Screenshot Renamer — MVP Spec (macOS)

## Vision

A tiny macOS utility that automatically renames screenshots into meaningful, human-readable filenames based on the app and window/tab the screenshot came from.

The app should feel invisible:

> Install → grant permissions → forget it exists.

No manual input. No cloud. No server. Runs locally.

---

## Product Goal

Replace default screenshot filenames like:

`Screenshot 2026-05-25 at 08.57.15.png`

with:

`Figma_LoginFlow.png`

`Safari_AmazonCheckout.png`

`Finder_GameAssets.png`

`Chrome_ResearchNotes.png`

without any user interaction.

---

## Confirmed MVP Decisions

- Build as a fresh native Xcode SwiftUI macOS project.
- Minimum supported macOS version: macOS 13+.
- Bundle identifier: `com.amorphicLabs.ScreenshotRenamer`.
- Enable automatic launch at login for the MVP.
- Watch the Desktop by default and support the user's custom screenshot save location when macOS exposes one through `com.apple.screencapture`.

---

## Core UX Principles

- Automatic by default
- Invisible background utility
- Native macOS feel
- No friction
- Reliable over clever
- Local-first (no internet/server)

---

## MVP Scope

### Included

- Background macOS app (SwiftUI)
- Menu bar utility
- Watches screenshot save location
- Detects newly created screenshots
- Automatically renames screenshots
- Captures app + active window title context
- Uses rolling context heuristic to avoid app-switch timing issues
- Filename cleanup/sanitization
- Accessibility permission onboarding

### Explicitly NOT Included (v1)

- OCR
- AI naming
- Image understanding
- Popups
- User editing
- Batch rename
- Finder extension
- Smart folder organization
- Sync/cloud
- Settings/preferences UI
- Localization support
- Analytics

---

# Architecture Overview

The app has four responsibilities:

1. Context Tracker
2. Screenshot Watcher
3. Context Matcher
4. Filename Renamer

---

# 1. Context Tracker

## Purpose

Continuously track what the user is doing so screenshot context is available **before** screenshots are saved.

This solves macOS delayed screenshot saving caused by the floating screenshot preview.

### Problem Being Solved

When a screenshot is taken, macOS may delay writing the file to disk.

During this delay, users may switch apps.

Bad behavior:

Figma screenshot → user switches to Slack → screenshot renamed as Slack.

We want:

Figma screenshot → renamed using Figma context.

---

## Approach

Maintain a rolling context buffer.

Every 500 ms:

Capture:

- timestamp
- frontmost app name
- focused window title

Store in memory.

### Example buffer

```text
08:57:11 → Figma → Wireframes
08:57:12 → Figma → Login Flow
08:57:13 → Figma → Login Flow
08:57:14 → Slack → Team Chat
```

Keep approximately the last 10 seconds.

Suggested implementation:

- ring buffer (in-memory)
- max ~20 entries

### Data model

```swift
struct AppContext {
    let timestamp: Date
    let appName: String
    let windowTitle: String?
}
```

---

## Technical Notes

Use macOS accessibility APIs.

Retrieve:

- frontmost application
- focused window title

Likely APIs:

- NSWorkspace.shared.frontmostApplication
- AXUIElement

Requires Accessibility Permission.

---

# 2. Screenshot Watcher

## Purpose

Detect when screenshots are actually written to disk.

### Behavior

Watch screenshot save location.

When a new file appears:

- verify it is a screenshot
- wait briefly for write completion
- process rename

---

## Screenshot Detection

Initial heuristic:

File name starts with:

```text
Screenshot
```

Supported examples:

```text
Screenshot 2026-05-25 at 08.57.15.png
```

Ignore non-screenshot files.

### v1 Assumption

User uses default English screenshot naming.

Localization can come later.

---

## Save Location

v1 behavior:

- Default to Desktop.
- If available, read the user's configured screenshot save location from `com.apple.screencapture`.

If the configured location cannot be resolved, fall back to Desktop.

---

## Write Delay

After file detection:

Wait ~500–1000 ms.

Reason:

Avoid renaming while file write still happening.

---

# 3. Context Matcher

## Purpose

Match screenshot to the correct app/window context.

### Approach

When screenshot appears:

Read file creation timestamp.

Compare against context buffer.

Select closest context entry by timestamp.

### Example

Buffer:

```text
08:57:11 → Figma → Wireframes
08:57:12 → Figma → Login Flow
08:57:13 → Figma → Login Flow
08:57:14 → Slack → Team Chat
```

Screenshot creation:

```text
08:57:12
```

Result:

```text
Figma → Login Flow
```

Use nearest timestamp match.

---

# 4. Filename Renamer

## Purpose

Generate readable filenames.

### Naming Formula

```text
[App]_[WindowTitle]
```

Examples:

```text
Figma_LoginFlow.png
Safari_AmazonCheckout.png
Chrome_ResearchNotes.png
Finder_GameAssets.png
```

---

## Filename Cleanup Rules

### Rule 1 — Remove app suffix noise

Examples:

Remove:

```text
- Google Chrome
- Safari
- Figma
```

Input:

```text
How to center div - Stack Overflow - Google Chrome
```

Output:

```text
HowToCenterDiv
```

---

### Rule 2 — Remove illegal filename characters

Remove:

```text
/ \ : ? * " < > |
```

---

### Rule 3 — Normalize spacing

Replace spaces with underscores.

Example:

```text
Login Flow
```

becomes:

```text
Login_Flow
```

---

### Rule 4 — Trim excessive length

Max filename length:

40 characters for window title.

Reason:

Prevent ugly filenames.

---

### Rule 5 — Remove duplicate separators

Avoid:

```text
Chrome___Research
```

Instead:

```text
Chrome_Research
```

---

### Rule 6 — Low-quality title fallback

If title is empty/useless:

Fallback to app name only.

Examples:

```text
Spotify.png
Slack.png
Figma.png
```

Potential low-quality titles:

- Untitled
- New Tab
- Home
- Empty title

Simple heuristic acceptable.

---

## Collision Handling

If filename already exists:

Append incrementing suffix.

Examples:

```text
Figma_LoginFlow.png
Figma_LoginFlow_2.png
Figma_LoginFlow_3.png
```

---

# Menu Bar App

Minimal menu bar utility.

Menu:

```text
Screenshot Renamer ✓

Pause Renaming
Resume Renaming

Quit
```

No settings screen in v1.

The app should register itself to launch at login, using the native macOS 13+ login item APIs.

---

# First Launch Experience

On first launch:

If Accessibility permission missing:

Explain briefly:

```text
Enable Accessibility access so Screenshot Renamer
can detect the active app and window title.
```

Provide shortcut/open flow to System Settings.

Then continue running.

---

# Performance Requirements

- Low CPU usage
- Low memory usage
- Entirely local
- No network calls
- Lightweight background process

Sampling frequency:

500 ms

Context buffer:

10 seconds max

---

# Suggested Project Structure

```text
ScreenshotRenamer/
├── App/
├── Services/
│   ├── ContextTracker.swift
│   ├── ScreenshotWatcher.swift
│   ├── ContextMatcher.swift
│   ├── FilenameGenerator.swift
│   └── PermissionManager.swift
├── Models/
│   └── AppContext.swift
├── UI/
│   └── MenuBarView.swift
```

---

# Success Criteria (MVP)

A successful MVP means:

> 80%+ of screenshots receive a more useful filename than the default macOS screenshot naming.

Not perfection.

Useful > smart.

---

# Recommended Stack

- SwiftUI
- AppKit where needed
- Accessibility APIs
- FileManager
- NSWorkspace
- DispatchSource / file observation APIs

Use AI coding assistance (Codex/ChatGPT) to accelerate implementation.

Keep implementation simple and reliable.
