# AppWindowFinder

[![Build Status](https://github.com/zamataku/app-window-finder/actions/workflows/ci.yml/badge.svg)](https://github.com/zamataku/app-window-finder/actions/workflows/ci.yml)
[![Release](https://github.com/zamataku/app-window-finder/actions/workflows/release-production.yml/badge.svg)](https://github.com/zamataku/app-window-finder/actions/workflows/release-production.yml)
[![Swift](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2013.0+-blue.svg)](https://www.apple.com/macos/)

A macOS app for switching between applications, windows, and browser tabs using fuzzy search.

## Features

- Fuzzy search across open applications, windows, and browser tabs
- Global hotkey: `Cmd+Shift+Space`
- Browser integration: Safari, Chrome, Brave, Edge, and Arc tabs
- Advanced browser history integration with SQLite database reading
- Keyboard navigation: arrow keys and Enter to select
- Universal binary: Intel and Apple Silicon support
- Comprehensive test coverage with 60+ tests for reliability

## Installation

### Option 1: Download DMG (Recommended)

1. **Download the DMG file**:
   - Go to [Releases](https://github.com/zamataku/app-window-finder/releases)
   - Download the latest `AppWindowFinder-v*.dmg` file

2. **Install the application**:
   - Double-click the downloaded DMG file to mount it
   - A window will open showing the AppWindowFinder app
   - Drag the AppWindowFinder app to the Applications folder
   - Eject the DMG by clicking the eject button in Finder or dragging it to Trash

3. **Remove quarantine attributes** (required for downloaded apps):
   ```bash
   xattr -rc /Applications/AppWindowFinder.app
   ```

4. **Launch the application**:
   - Open the Applications folder
   - Double-click AppWindowFinder to launch
   - Grant necessary permissions when prompted

> **Important**: The `xattr` command removes quarantine flags that macOS adds to downloaded applications. This step is essential for downloaded apps to launch properly. For self-built apps, this is usually handled automatically during DMG creation.

### Option 2: Build from Source

1. **Clone the repository**:
   ```bash
   git clone https://github.com/zamataku/app-window-finder.git
   cd app-window-finder
   ```

2. **Build and install**:
   ```bash
   chmod +x build-and-package.sh
   ./build-and-package.sh
   ```

3. **Copy to Applications**:
   ```bash
   cp -r dist/AppWindowFinder.app /Applications/
   # Remove quarantine attributes if needed (usually automatic via DMG)
   xattr -rc /Applications/AppWindowFinder.app
   ```

## Development

### Building and Packaging

For complete build and distribution:
```bash
./build-and-package.sh
```

For development builds only:
```bash
swift build
```

### Testing

Run all tests:
```bash
swift test
```

Run specific test suites:
```bash
# Core functionality tests
swift test --filter "FuzzySearchTests|SearchItemTests|WindowManagerTests"

# Browser integration tests
swift test --filter "BrowserHistoryServiceTests|BrowserIntegrationTests"

# Performance and error handling tests
swift test --filter "PerformanceTests|ErrorHandlingTests"
```

Current test coverage includes:
- 60+ passing tests across 21 test suites
- Unit tests for all core services
- Browser integration and SQLite database tests
- Performance benchmarks and error handling
- E2E integration tests

### Running in Development

```bash
swift run
```

## Usage

1. **Launch**: Open AppWindowFinder (it runs in the background)
2. **Search**: Press `Cmd+Shift+Space` to open the search window
3. **Type**: Start typing to search for apps, windows, or tabs
4. **Navigate**: Use arrow keys to navigate results
5. **Select**: Press Enter to switch to the selected item
6. **Close**: Press Escape to close the search window

## Permissions Setup

AppWindowFinder requires accessibility permissions to work properly:

1. **First Launch**: The app will automatically prompt for permissions
2. **Manual Setup**: System Preferences → Security & Privacy → Privacy → Accessibility
3. **Add AppWindowFinder**: Check the box next to AppWindowFinder
4. **Restart**: Restart the app after granting permissions


## Troubleshooting

### Hotkey Not Working

If `Cmd+Shift+Space` doesn't work:

1. Check accessibility permissions in System Preferences → Security & Privacy → Privacy → Accessibility
2. Restart the app after granting permissions  
3. Verify no other app is using the same hotkey

### Browser Tabs Not Showing

Grant automation permissions when prompted on first use of browser tab features.

### Performance Issues

Restart the app to clear cache if experiencing slow performance.


## Architecture

```
Sources/AppWindowFinder/
├── App/                    # Application layer (AppDelegate, main app)
├── Core/                   # Core functionality and shared utilities
│   ├── Cache/             # Cache management
│   ├── Logging/           # Application logging
│   ├── Permissions/       # Accessibility permission handling
│   └── Search/            # Fuzzy search algorithm
├── Extensions/             # Swift extensions (NSImage, etc.)
├── Models/                 # Data structures for search items
├── Services/               # Business logic layer
│   ├── BrowserIntegration/ # Browser history and tab retrieval
│   │   ├── BrowserHistoryService.swift # SQLite browser history integration
│   │   └── BrowserTabService.swift     # Live browser tab retrieval
│   ├── HotkeyManager.swift     # Global hotkey handling
│   ├── SearchHistoryManager.swift # Search history tracking
│   ├── WindowManager.swift     # Window information management
│   └── FaviconService.swift    # Favicon caching and retrieval
├── Views/                  # SwiftUI-based search interface
└── Resources/              # Localization files (en, ja)
```

## Privacy

- All data stays on your Mac
- No network requests or data collection
- Only accesses window titles and browser tabs when searching
