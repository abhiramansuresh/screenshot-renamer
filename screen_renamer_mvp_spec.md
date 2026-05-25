# Screen Renamer — MVP Spec (macOS)

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

`Figma_Login_Flow.png`

`Safari_Amazon_Checkout.png`

`Finder_Game_Assets.png`

`Chrome_Research_Notes.png`

without any user interaction.

---

## Confirmed MVP Decisions

- Build as a fresh native Xcode SwiftUI macOS project.
- Minimum supported macOS version: macOS 13+.
- Bundle identifier: `com.amorphicLabs.ScreenshotRenamer` (kept as the legacy identifier so macOS Accessibility permissions continue to match after the product rename).
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

Also listen for app activation events so fast app switches are captured immediately.
This covers the case where a user moves into an app and takes a screenshot before
the next polling tick runs.

On `NSWorkspace.didActivateApplicationNotification`:

- capture the activated app context immediately
- capture it again in a short burst (~50 ms and ~150 ms) so quick screenshots
  get fresh context while the focused window title still has time to settle

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
- max ~80 entries, enough to cover polling plus activation bursts over the
  recent 10-second window
- `NSWorkspace.shared.notificationCenter` activation observer
- keep periodic polling as a fallback for window-title changes within the same app

### Data model

```swift
struct AppContext {
    let timestamp: Date
    let appName: String
    let windowTitle: String?
    let tabName: String?
    let browserDomain: String?
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
- NSWorkspace.didActivateApplicationNotification
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

Newly detected screenshots should be tracked as pending while the delay is
active, but should not be permanently marked as known. The known set is only for
screenshots that already existed before watching/resuming.

Reason:

macOS can create or restore the same native screenshot path after the app has
already moved the first file. If the app remembers every scheduled path forever,
that recreated screenshot is skipped and never renamed.

---

## Debug Logging

The app should keep a lightweight diagnostic log so missed renames can be
debugged from the user's machine.

Log file:

```text
~/Library/Application Support/Screen Renamer/debug.log
```

The menu bar UI should expose:

- Open Debug Log
- Clear Debug Log

The watcher logs:

- watched folder changes
- directory change events
- scan start/end counts
- screenshot candidate rejection reasons
- scheduling decisions
- processing start/skip reasons
- resolved context and destination filename
- move success/failure with error text

This log is for diagnosing rename misses and should not be required for normal
operation.

---

# 3. Context Matcher

## Purpose

Match screenshot to the correct app/window context.

### Approach

When screenshot appears:

Read the default screenshot filename timestamp.

Compare against context buffer.

Treat filename timestamps as a one-second capture bucket.

Default screenshot filenames only include seconds, not milliseconds. A file
named `Screenshot ... at 10.00.01` could have been captured any time from
`10:00:01.000` through `10:00:01.999`.

When a filename timestamp is available:

- first look for context entries inside that one-second bucket
- read the file creation and modification timestamps for millisecond precision
- if either file timestamp is also inside that bucket, use it as a reference
  point and choose the closest context inside the bucket
- if the file timestamp is outside the bucket, choose the latest context inside
  the bucket
- if there is no context inside the bucket, choose the latest context just
  before the bucket start
- fall back to nearest timestamp matching only when the bucket-based fallbacks
  have no usable context

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
[App]_[PageName]
```

Examples:

```text
Figma_Login_Flow.png
Safari_Pull_Request.png
Chrome_How_To_Center_Div.png
Finder_Game_Assets.png
```

The app name is always first. `Google Chrome` is normalized to `Chrome`, and
`Microsoft Edge` is normalized to `Edge`.

The page name comes from the selected tab title when available, otherwise the
focused window title.

Browser domains are tracked in context, but they are not included as their own
filename segment. The cleaned browser domain is used only to avoid repeating the
same value as the page name. For example, if the cleaned page name and cleaned
domain compare equal after removing punctuation and casing, omit the page name
and use the app name only.

Known browser domain display names:

```text
figma.com         → Figma
github.com        → GitHub
google.com        → Google
notion.so         → Notion
openai.com        → OpenAI
stackoverflow.com → StackOverflow
```

Cleaned browser domain display names have an internal safety limit of 32
characters.

Maximum generated base filename length before the file extension is 80
characters. When an incrementing collision suffix is needed, reserve space for
that suffix inside the 80-character limit.

Fallback filename when no app/title data survives cleanup:

```text
Screenshot.png
```

---

## Filename Cleanup Rules

All tab/window titles run through this exact order before building the filename:

```text
1. Strip raw URLs and extract one meaningful segment when possible
2. Strip domain tokens for browser apps
3. Strip app-name suffixes and variants
4. Detect search queries and truncate to 4 words
5. General title truncation to 5 words
6. Title-case all words
7. Drop low-quality titles and fall back to app name only
8. Sanitize and collapse duplicate separators
```

### Rule 1 — Strip raw URLs

If the title looks like a raw URL, reduce it to a meaningful segment before any
other title cleanup.

Detection:

- contains `://`
- starts with `http`
- starts with `www.`
- contains a long hyphenated domain pattern such as
  `brainmo-backdoor-staging.vercel.app`

Extraction behavior:

- Parse the URL host when possible.
- Remove a leading `www`.
- If the first host label is meaningful, use its first alphanumeric segment.
- Generic first host labels are `docs`, `drive`, `github`, `google`,
  `localhost`, `notion`, and `vercel`; for these, prefer the first path segment
  when present.
- Split meaningful labels at non-alphanumeric boundaries, so
  `brainmo-backdoor-staging.vercel.app` becomes `Brainmo`.

Example:

```text
Chrome_brainmo-backdoor-staging.vercel.app_...
```

becomes:

```text
Chrome_Brainmo.png
```

---

### Rule 2 — Strip domain tokens for browsers

For browser apps only, remove tokens that look like domains from the title.

Supported browser app names:

```text
Arc
Brave
Brave Browser
Chrome
Chromium
Firefox
Google Chrome
Microsoft Edge
Edge
Opera
Safari
```

Domain token patterns removed:

- any token matching a dotted domain such as `word.word` or `word.word.word`
- any dotted domain ending in a normal TLD such as `.com`, `.io`, `.app`,
  `.dev`, `.ai`, `.org`, `.net`, or `.co`
- `localhost`, with or without a port

Example:

```text
Chrome_docs.google.com_ANT_I_am_cold
```

becomes:

```text
Chrome_Ant_I_Am_Cold.png
```

---

### Rule 3 — Remove app suffix noise

Strip known app names only when they appear as the final title segment separated
by one of:

```text
" - "
" – "
" — "
" | "
```

Known suffixes:

```text
current app name
cleaned current app name
Google Chrome
Chrome
Safari
Firefox
Mozilla Firefox
Microsoft Edge
Edge
Arc
Brave
Brave Browser
Notion
Xcode
Visual Studio Code
VSCode
VS Code
Figma
Slack
Linear
```

The stripping repeats until no matching suffix remains.

Input:

```text
How to center a div - Stack Overflow - Google Chrome
```

Output:

```text
Chrome_How_To_Center_A_Div.png
```

Input:

```text
main.swift — MyProject — Xcode
```

Output:

```text
Xcode_Main_Swift_Myproject.png
```

---

### Rule 4 — Detect and collapse search queries

Treat a title as a search query when any of these are true:

- contains `- Google Search` or `| Google Search`
- contains `- Bing` or `| Bing`
- contains `- DuckDuckGo` or `| DuckDuckGo`
- contains `Search results for`
- title has more than 6 words, the app is a browser, and the raw title did not
  contain a domain token or raw URL

Search-query handling:

- Strip `Search results for` from the front when present.
- Strip a trailing search-engine segment and everything after it, matching
  `Google Search`, `Bing`, or `DuckDuckGo`.
- If the remaining query starts with naked `Google`, `Bing`, or `DuckDuckGo`,
  drop that first word.
- Keep only the first 4 words.
- Title-case each word.

Examples:

```text
What the fuck is happening in this world - Google Search
```

becomes:

```text
Chrome_What_The_Fuck_Is.png
```

```text
Fees for registering OPC in India in Razorpay - Google Search
```

becomes:

```text
Chrome_Fees_For_Registering_OPC.png
```

---

### Rule 5 — General word truncation and title casing

For non-search titles:

- Split the cleaned title into words.
- Keep the first 5 words maximum.
- Cut only at word boundaries.
- Join words with underscores.
- Title-case every word.
- The formatted tab/window title has an internal safety limit of 120 characters.

Example:

```text
Fees_For_Registering_OPC_In_India_In_Razorpay
```

becomes:

```text
Fees_For_Registering_OPC_In
```

Acronym casing:

Known acronym words of 2 to 4 characters are emitted uppercase even if the
source casing differs:

```text
AI
API
CPU
CSS
DNS
GPU
HTML
HTTP
IP
JSON
LLM
OPC
PDF
SQL
UI
URL
UX
VPN
XML
```

Special casing:

```text
figma  → Figma
github → GitHub
ios    → iOS
macos  → macOS
openai → OpenAI
xcode  → Xcode
```

---

### Rule 6 — Remove illegal filename characters

Remove:

```text
/ \ : ? * " < > |
```

---

### Rule 7 — Normalize separators

Replace whitespace with underscores, collapse duplicate underscores, and trim
leading/trailing dots, underscores, hyphens, and spaces.

Example:

```text
Login Flow
```

becomes:

```text
Login_Flow
```

---

### Rule 8 — Low-quality title fallback

If the final cleaned title is low quality, fewer than 2 comparable alphanumeric
characters, or equal to the app name, omit the title and use the app name only.

Examples:

```text
Spotify.png
Slack.png
Figma.png
```

Low-quality titles are normalized by lowercasing, replacing non-alphanumeric
runs with `_`, and trimming `_`. The implemented low-quality set is:

```text
untitled
new_tab
newtab
home
google
bing
duckduckgo
emptytitle
empty_title
start_page
startpage
aboutblank
about_blank
```

---

### Rule 9 — Base-name length limit

After app and page name are joined, trim the base filename to a maximum of 80
characters before the extension.

When trimming:

- Prefer the last separator boundary (`_`, `-`, `.`, or space) after at least
  60% of the allowed length, with a minimum preferred boundary of 20 characters.
- If no good boundary exists, hard-trim and remove leading/trailing separator
  characters.

This limit also applies during collision handling, reserving room for `_2`,
`_3`, etc.

---

## Collision Handling

If filename already exists:

Append incrementing suffix.

Examples:

```text
Figma_Login_Flow.png
Figma_Login_Flow_2.png
Figma_Login_Flow_3.png
```

---

# Menu Bar App

Minimal menu bar utility.

Menu:

```text
Screen Renamer ✓

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
Enable Accessibility access so Screen Renamer
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
Screen Renamer/
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
