# WebitBrowser

WebitBrowser is a native iOS browser architecture scaffold designed for sideloading on iPhone and iPad. The production path on iOS is Apple WebKit via WKWebView, while the project structure is layered so a Chromium or CEF abstraction can be inserted behind the browser core interface without rewriting the app shell.

## Architecture overview

- Native app shell: SwiftUI/UIKit
- Browser host: WKWebView-based container with navigation, reload, and toolbar controls
- Core logic: C++ wrapper that normalizes URLs, searches, and manages downloads
- Safety/filters: Rust module for URL sanitization and blocklist checks
- Performance hooks: Assembly routine for a fast hash primitive, included as an example of low-level optimization
- Bridge layer: Objective-C++ and C ABI boundary used to connect C++, Rust, and Swift

This layered design keeps the browser chrome native while the actual rendering engine remains Apple WebKit for legal and practical iOS deployment.

## Recommended directory layout

```text
WebitBrowser/
├── App/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   └── Info.plist
├── Sources/
│   ├── BrowserCore/
│   │   ├── BrowserCore.hpp
│   │   └── BrowserCore.mm
│   ├── RustBridge/
│   │   └── filters.rs
│   ├── Assembly/
│   │   └── hash_asm.S
│   └── NativeUI/
│       └── BrowserViewController.swift
├── Scripts/
│   ├── build_release.sh
│   └── export_ipa.sh
├── Certificates/
│   └── README.md
├── README.md
├── LICENSE
└── .gitignore
```

## Xcode integration notes

1. Add the C++/Objective-C++ files to the app target and set the file type to Objective-C++ Source (.mm).
2. Add the Rust module as a generated static library or C ABI bridge. Use Cargo to build a static library and link it into your iOS app target.
3. Add the assembly file as a source in the app target, ensuring the build is arm64 for device builds.
4. Keep the browser chrome fully native in Swift or UIKit; avoid embedding HTML/CSS/JS for the app UI.
5. Use NSURLSessionDownloadTask for the file download manager and store files to the iOS Documents or Files sandbox area.
6. Create a valid provisioning profile and signing identity before exporting a release archive.

## C++ wrapper design

The C++ layer exposes a clean browser API:

- loadURL()
- goBack(), goForward(), reload()
- normalizeURL()
- searchQueryToURL()
- handleDownload()

It is implemented using Objective-C++ to host a WKWebView and relay navigation and download callbacks back into the native app.

## Rust safety module

The Rust layer should provide sanitization and blocking functions for URL validation, phishing heuristics, or custom ad-blocking rules. A safe C ABI keeps the code isolated and memory-safe while still connecting to the native app.

## Assembly example

This example is intentionally small. In production, assembly is best used for very narrow hot paths such as cryptographic hashes or specialized packet-processing primitives. It should not be used for general browser UI logic.

## Compile, sign, and package as an .ipa

### Prerequisites

- macOS with Xcode 15+
- Apple Developer account for ad hoc signing or developer provisioning
- A registered iPhone or iPad for device testing
- Optional: AltStore or Sideloadly for installation

### Build in Xcode

Open the app target in Xcode and build for a connected device. For command-line builds:

```bash
xcodebuild -scheme WebitBrowser -configuration Release -sdk iphoneos -archivePath build/WebitBrowser.xcarchive archive
```

### Export the archive to .ipa

```bash
xcodebuild -exportArchive \
  -archivePath build/WebitBrowser.xcarchive \
  -exportPath build/ipa \
  -exportOptionsPlist ExportOptions.plist
```

Example ExportOptions.plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
    <key>method</key>
    <string>ad-hoc</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

### Install via sideloading tools

- AltStore: install AltServer on a Mac, then drag the .ipa into AltStore.
- Sideloadly: select the .ipa, sign it, and install it to the device.
- Xcode: use the device window to install directly to a registered device.

## Chromium and CEF note

A full Chromium-based browser on iOS is not the normal production path for a sideloaded app. Apple’s platform expectations push iOS apps toward WebKit-based rendering, and Chromium/CEF can only be integrated realistically in a specialized or desktop-focused build. This scaffold therefore uses WKWebView as the actual rendering engine while keeping the C++/Rust/assembly boundary ready for future engine evolution.

## Source examples included in this repo

The generated source scaffold includes:

- C++ core wrapper in [Sources/BrowserCore/BrowserCore.hpp](Sources/BrowserCore/BrowserCore.hpp)
- Objective-C++/WKWebView bridge in [Sources/BrowserCore/BrowserCore.mm](Sources/BrowserCore/BrowserCore.mm)
- Rust URL safety module in [Sources/RustBridge/filters.rs](Sources/RustBridge/filters.rs)
- Assembly routine in [Sources/Assembly/hash_asm.S](Sources/Assembly/hash_asm.S)
- Native UIKit browser UI in [Sources/NativeUI/BrowserViewController.swift](Sources/NativeUI/BrowserViewController.swift)

These are example building blocks for a real iOS browser project and should be adapted to your full Xcode target setup.
