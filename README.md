<div align="center">

<img src="assets/NotchBay-NeonTitanium-1024.png" width="140" height="140" alt="NotchBay App Icon" />

# NotchBay

**Dock, drop, and monitor at the top edge of your Mac.**  
A sleek, zero-dependency native **macOS Dynamic Island & Camera Notch Companion** built with **SwiftUI** and **AppKit**.

[![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-00E5FF?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/PraveenWijewardana/NotchBay)
[![Swift 6](https://img.shields.io/badge/Swift-6.0-FF5722?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Universal Binary](https://img.shields.io/badge/Apple_Silicon_%26_Intel-Universal-9C6ADE?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/PraveenWijewardana/NotchBay/raw/main/NotchBay.dmg)
[![Download DMG](https://img.shields.io/badge/Download-NotchBay.dmg-00F5A0?style=for-the-badge&logo=apple&logoColor=black)](https://github.com/PraveenWijewardana/NotchBay/raw/main/NotchBay.dmg)

<br />

<img src="assets/notchbay-hero.png" width="100%" alt="NotchBay Hero Showcase" />

</div>

---

## ✨ Overview

**NotchBay** anchors directly to your MacBook camera notch—or floats seamlessly as an iPhone-style Dynamic Island on external monitors and non-notch Macs. With fluid Apple spring physics, it transforms the dead space around your camera cutout into a live command center for system telemetry, network sparklines, media control, focus timers, file holding, and AI coding agent tracking.

---

## 📦 Installation (`.dmg` Installer)

<div align="center">
  <a href="https://github.com/PraveenWijewardana/NotchBay/raw/main/NotchBay.dmg">
    <img src="assets/dmg_installer_preview.png" width="540" alt="NotchBay Drag to Applications Installer" />
  </a>
</div>

1. **[Download `NotchBay.dmg`](https://github.com/PraveenWijewardana/NotchBay/raw/main/NotchBay.dmg)** from this repository.
2. Double-click **`NotchBay.dmg`** and drag **NotchBay** onto **Applications**.
3. If macOS Gatekeeper shows an *"unidentified developer"* prompt on first launch, either **Right-Click → Open** or run:
   ```bash
   xattr -cr /Applications/NotchBay.app
   ```

---

## 🚀 Key Features

### 1. 🖥️ Real-Time System Telemetry HUD
Powered directly by low-overhead Darwin kernel APIs (`mach_host`, `host_processor_info`, `vm_statistics64`, `getifaddrs`, `statfs`, and `IOKit.ps`):
- **CPU & GPU**: Live multi-core processor and Apple Silicon Metal load with vector sparkline history.
- **Memory & Swap**: Active, wired, and compressed RAM breakdowns plus swap pressure alerts.
- **Disk & Storage**: Instantaneous read (`R`) / write (`W`) throughput and filesystem capacity.
- **Power & Thermals**: Battery health, charging state, wattage, and thermal state (`Cool`, `Nominal`, `Warm`).

### 2. 🌐 Network Deep-Dive & Dual-Line Waveform
- Live instantaneous download (`↓`) and upload (`↑`) transfer rates.
- Dual-line Bezier-smoothed real-time waveform chart (30-second rolling window).
- Session telemetry cards tracking **Peak Down**, **Session Downloaded**, and **Session Uploaded**.

### 3. 🎵 Now Playing & Audio Equalizer
- Native integration with **Apple Music** and **Spotify**.
- Live album artwork, track title, artist metadata, and multi-bar animated audio visualizer.
- Instant playback controls (`Play / Pause`, `Next`, `Previous`).

### 4. 📁 The Notch Drop Bay (File Shelf)
- Drag and drop files, screenshots, links, or text snippets straight into the notch to hold them temporarily.
- Quick file preview with icons and byte sizes, plus one-click copy or drag-out into any app.

### 5. ⏱️ Timers, Pomodoro & Tactile Ruler Slider
- **Modes**: Countdown Timer (`5m`, `10m`, `25m` presets), automatic **Pomodoro** (`25m Focus / 5m Break`), and **Stopwatch** with lap tracking.
- **Interactive Ruler Dial**: Scrub visually across tick marks (`1m` – `30m`) with dynamic completion time calculation (e.g., *"Ends around 6:45 PM"*).

### 6. 🤖 AI Code Agent & Calendar / Weather Companion
- **Agent Companion**: Auto-detects running terminal/IDE coding agents and surfaces live task progress in the notch.
- **Calendar & Weather**: Quick glance at upcoming EventKit calendar meetings and local weather conditions.

---

## ⌨️ Keyboard Shortcuts & Menu Bar

NotchBay lives quietly in your macOS menu bar (`circle.circle` icon) and responds to quick shortcuts:

| Shortcut | Action |
| :--- | :--- |
| **`⌘ + I`** | Toggle NotchBay (Compact Pill ↔ Expanded Dashboard) |
| **`⌘ + 1`** | Open **Home** Overview |
| **`⌘ + 2`** | Open **System Telemetry** |
| **`⌘ + 3`** | Open **Timers & Pomodoro** |
| **`⌘ + 4`** | Open **Now Playing Media** |
| **`⌘ + 5`** | Open **Notch Drop Shelf** |
| **`⌘ + 6`** | Open **Code Agents Monitor** |
| **`⌘ + R`** | Recenter / Reposition NotchBay on Active Screen |
| **`⌘ + Q`** | Quit NotchBay |

---

## 🛠️ Build from Source

### Requirements
- **macOS 14.0 (Sonoma)** or later
- **Xcode 16+** or **Swift 6.0+** toolchain

### Clone & Run
```bash
git clone https://github.com/PraveenWijewardana/NotchBay.git
cd NotchBay
open DynamicIsland.xcodeproj
```
In Xcode, select **My Mac** as the run destination and press **`⌘ + R`**, or build via Swift Package Manager:
```bash
swift run
```

---

## 🏗️ Architecture

```text
NotchBay/
├── DynamicIsland/
│   ├── DynamicIslandApp.swift       # @main entry point
│   ├── AppDelegate.swift            # Menu bar item & lifecycle controller
│   ├── Window/                      # Non-activating floating NSPanel & ViewModel
│   ├── Models/                      # Telemetry, Timer, Media, Weather, Calendar & Agent models
│   ├── Services/                    # Darwin Mach/IOKit monitors, AppleScript Media, EventKit
│   ├── Views/                       # SwiftUI Compact Pill, Expanded Island & Bento Dashboards
│   └── Resources/                   # Info.plist, Entitlements, AppIcon.icns & Assets.xcassets
├── assets/                          # High-res icons, DMG Retina background & README artwork
├── NotchBay.dmg                     # Ready-to-install macOS Universal Disk Image
└── Package.swift                    # Swift Package Manager manifest
```

---

<div align="center">
  Built with ❤️ in SwiftUI & AppKit · <a href="https://github.com/PraveenWijewardana/NotchBay">GitHub Repository</a>
</div>
