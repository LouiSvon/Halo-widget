# Halo

A minimal macOS menubar widget that lives in your MacBook's notch — inspired by [Alcove](https://alcove.app).

Halo extends your notch into a Dynamic Island-style pill that shows your currently playing Spotify track with album art, playback controls, and connected Bluetooth devices.

![macOS](https://img.shields.io/badge/macOS-13.0+-black?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?style=flat-square&logo=swift)

## Features

- **Notch integration** — album art and animated equalizer bars extend from your MacBook's notch, always visible when music plays
- **Hover to expand** — track info, progress bar, playback controls appear in a compact pill below the notch
- **Spotify controls** — play/pause, next, previous directly from the notch
- **Bluetooth devices** — see connected audio devices at a glance
- **Smooth animations** — `matchedGeometryEffect` transitions, spring animations, real-time equalizer
- **Battery friendly** — polling only when authenticated, progress interpolation between API calls
- **Fallback mode** — classic StatusItem + Popover on Macs without a notch

## Requirements

- macOS 13.0+
- MacBook with notch (Pro 14"/16", Air M2/M3) for the notch experience
- [Xcode 15+](https://developer.apple.com/xcode/)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- A [Spotify Developer](https://developer.spotify.com/dashboard) app with `halo://spotify-callback` as redirect URI

## Installation

```bash
# 1. Clone the repo
git clone https://github.com/LouisMusic/Halo-widget.git
cd Halo-widget

# 2. Install XcodeGen (if needed)
brew install xcodegen

# 3. Set your Spotify Client ID
# Open Halo/Services/SpotifyService.swift and replace the clientID value

# 4. Generate the Xcode project
xcodegen generate

# 5. Open in Xcode
open Halo.xcodeproj
```

In Xcode:
1. Select the **Halo** target
2. Set your **Development Team** in Signing & Capabilities
3. `Cmd+R` to build and run

## Spotify Setup

1. Go to [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)
2. Create an app (or use an existing one)
3. Add `halo://spotify-callback` to **Redirect URIs**
4. Copy the **Client ID** into `SpotifyService.swift`

The app uses OAuth 2.0 PKCE — no client secret needed.

## Architecture

```
Halo/
├── HaloApp.swift                    # Entry point
├── AppDelegate.swift                # NSStatusItem fallback + URL scheme handler
├── Extensions/
│   └── Color+Hex.swift              # Color(hex:) convenience
├── Helpers/
│   └── KeychainHelper.swift         # Secure token storage
├── Services/
│   ├── SpotifyService.swift         # OAuth PKCE, Now Playing API, playback controls
│   └── BluetoothService.swift       # IOBluetooth device detection + disconnect
├── NotchWindow/
│   ├── NotchWindowController.swift  # NSPanel management, hover detection, state machine
│   └── NotchIslandView.swift        # Dynamic Island UI, equalizer, controls
└── Views/
    ├── ContentView.swift            # Popover layout (fallback mode)
    ├── SpotifyView.swift            # Popover Spotify section
    └── BluetoothView.swift          # Popover Bluetooth section
```

## How It Works

**Notch detection** — checks `NSScreen.safeAreaInsets.top > 0` and uses `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` to compute the exact notch position.

**Three states:**
| State | Trigger | What you see |
|-------|---------|--------------|
| `idle` | No music playing | Nothing (blends with notch) |
| `collapsed` | Music detected | Album art + equalizer bars extending from notch |
| `expanded` | Hover over pill | Track info, progress bar, controls, BT icon |

**Mouse tracking** — polls `NSEvent.mouseLocation` every 50ms instead of SwiftUI `onHover` (which doesn't work reliably above the menu bar).

## Built With

- SwiftUI + AppKit (NSPanel, NSStatusItem)
- IOBluetooth (classic Bluetooth device management)
- CryptoKit (PKCE code challenge)
- Security.framework (Keychain token storage)
- Zero external dependencies

## License

MIT
