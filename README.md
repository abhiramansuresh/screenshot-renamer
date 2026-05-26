# Screen Renamer

  

Screen Renamer is a tiny macOS menu bar utility that automatically renames screenshots into meaningful, human-readable filenames based on the app and window or browser tab you captured.

  

Instead of files like:

  

```text

Screenshot 2026-05-25 at 08.57.15.png

```

  

you get names like:

  

```text

Figma_Login_Flow.png

Safari_Amazon_Checkout.png

Finder_Game_Assets.png

Chrome_Research_Notes.png

```

  

The goal is simple: take screenshots as usual, then let the app clean up the filenames quietly in the background.

  

## Why

  

macOS screenshots are easy to create but hard to find later. Default screenshot filenames tell you when a screenshot was taken, but not what it was about. Screen Renamer keeps screenshots searchable by using the context that already exists on your Mac: the foreground app, focused window title, selected browser tab, and browser domain where available.

  

The app is intentionally local-first:

  

- No internet access

- No cloud service

- No analytics

- No image upload

- No OCR or AI naming

  

## Features

  

- Runs as a native macOS menu bar app

- Watches the Desktop by default

- Follows the macOS screenshot save location when one is configured

- Detects new screenshots and renames them automatically

- Uses a short rolling app/window context buffer to avoid app-switch timing mistakes

- Reads browser tab and domain context where macOS Accessibility APIs expose it

- Sanitizes filenames for macOS compatibility

- Avoids overwriting existing files by adding an incrementing suffix

- Supports pause and resume from the menu bar

- Can launch at startup

- Includes a debug log for diagnosing missed renames

  

## How It Works

  

Screen Renamer has four main pieces:

  

1. `ContextTracker` records the frontmost app, focused window title, selected browser tab, and browser domain every 500 ms. It also listens for app activation events so fast app switches are captured promptly.

2. `ScreenshotWatcher` watches the screenshot save folder, waits briefly for new files to finish writing, then schedules them for processing.

3. `ContextMatcher` matches the screenshot timestamp to the best available recent context.

4. `FilenameGenerator` turns that context into a clean filename such as `Chrome_GitHub_Pull_Request.png`.

  

The app only renames newly detected screenshots. It does not batch-process older screenshots that existed before the watcher started.

  

## Privacy

  

Screen Renamer runs entirely on your Mac. It does not send screenshot names, window titles, URLs, images, logs, or any other data to a server.

  

The app asks for Accessibility access because macOS requires it before an app can read the active app and window title. That context is used only locally to generate filenames.

  

## Requirements

  

- macOS 13 Ventura or newer

- Xcode with a macOS 13 SDK or newer

- Swift 5

  

## Installation

  

### From Source

  

Clone the repository:

  

```sh

git clone https://github.com/YOUR_USERNAME/screenshot_renamer.git

cd screenshot_renamer

```

  

Open the Xcode project:

  

```sh

open "Screen Renamer.xcodeproj"

```

  

In Xcode:

  

1. Select the `Screen Renamer` scheme.

2. Choose your Mac as the run destination.

3. Press `Cmd+R` to build and run.

4. Grant Accessibility access when prompted.

  

You can also build from the command line:

  

```sh

xcodebuild \

-project "Screen Renamer.xcodeproj" \

-scheme "Screen Renamer" \

-configuration Release \

-destination "platform=macOS" \

clean build

```

  

The release app is written to:

  

```text

Prod/Screen Renamer.app

```

  

Copy `Prod/Screen Renamer.app` to `/Applications`, launch it, and grant Accessibility access in:

  

```text

System Settings -> Privacy & Security -> Accessibility

```

  

If macOS still shows stale permission state after replacing the app, remove the old Screen Renamer entry from Accessibility settings, then add the app again.

  

## Usage

  

1. Launch Screen Renamer.

2. Grant Accessibility access.

3. Take screenshots normally with macOS.

4. New screenshots in your screenshot save folder will be renamed automatically.

  

The menu bar item shows the most recent rename and total screenshots renamed. From the menu you can:

  

- Pause renaming for 5 minutes, 1 hour, until tomorrow, or indefinitely

- Resume renaming

- Enable or disable launch at startup

- In debug builds, open or clear the debug log

  

The debug log is stored at:

  

```text

~/Library/Application Support/Screen Renamer/debug.log

```

  

## Screenshot Save Location

  

Screen Renamer watches the Desktop by default. If you changed the macOS screenshot location, the app attempts to read it from:

  

```text

com.apple.screencapture

```

  

To change the system screenshot location yourself, press `Cmd+Shift+5`, choose `Options`, then select a save location.

  

## Filename Rules

  

Generated names use this general shape:

  

```text

[App]_[Page_Or_Window_Title].[extension]

```

  

Examples:

  

```text

Google Chrome + "GitHub Pull Request" -> Chrome_GitHub_Pull_Request.png

Microsoft Edge + "Research Notes" -> Edge_Research_Notes.png

Finder + "Game Assets" -> Finder_Game_Assets.png

```

  

The generator:

  

- Normalizes app names like `Google Chrome` to `Chrome`

- Prefers selected browser tab names when available

- Falls back to the focused window title

- Removes browser domains and common app suffix noise

- Shortens long titles and search queries

- Preserves common acronyms like `API`, `JSON`, `UI`, and `PDF`

- Limits generated base filenames to 80 characters

  

Supported screenshot file extensions:

  

```text

png, jpg, jpeg, heic, tiff, pdf

```

  

## Packaging For Distribution

  

For local testing, the command-line Release build is enough:

  

```sh

xcodebuild \

-project "Screen Renamer.xcodeproj" \

-scheme "Screen Renamer" \

-configuration Release \

-destination "platform=macOS" \

clean build

```

  

Then package the built app as a zip:

  

```sh

ditto -c -k --keepParent "Prod/Screen Renamer.app"  "Prod/Screen Renamer.zip"

```

## Project Structure

  

```text

Screen Renamer/

App/

ScreenRenamerApp.swift

AppController.swift

Info.plist

Models/

AppContext.swift

Services/

ContextMatcher.swift

ContextTracker.swift

DirectoryWatcher.swift

FilenameGenerator.swift

LoginItemManager.swift

PermissionManager.swift

ScreenshotDebugLogger.swift

ScreenshotLocationResolver.swift

ScreenshotWatcher.swift

UI/

MenuBarView.swift

```

  

## Development Notes

  

- Minimum macOS version is set to 13.0.

- Bundle identifier is `com.amorphicLabs.ScreenshotRenamer`.

- The app uses `LSUIElement` so it appears as a menu bar utility instead of a Dock app.

- Release builds are configured to output to `Prod/`.

- Debug builds are configured to output to `Debug/`.

- Build artifacts and local Xcode state are ignored by `.gitignore`.

  

## Known Limitations

  

- The MVP assumes English macOS screenshot filenames beginning with `Screenshot`.

- It does not inspect image contents.

- It does not OCR text from screenshots.

- It does not rename screenshots that existed before the app started watching.

- Context quality depends on what macOS Accessibility APIs expose for the foreground app.

- Browser tab and domain extraction can vary by browser and browser version.

  

## Roadmap Ideas

  

Potential future improvements:

  

- Preferences UI

- Batch rename for existing screenshots

- Optional filename format customization

- Localization support for non-English screenshot filenames

- More robust browser metadata support

- Optional Finder integration

  

## Contributing

  

Issues and pull requests are welcome once the repository is public. Please keep changes aligned with the core product principles:

  

- Local-first

- Lightweight

- Native macOS feel

- Reliable over clever

- No network dependency for core behavior

  

## License

  

This project is licensed under the MIT License. See [LICENSE](LICENSE) for the full license text.

MIT is a permissive open-source license. It allows people to use, copy, modify, merge, publish, distribute, sublicense, and sell copies of the project, as long as the copyright notice and license text are included.
