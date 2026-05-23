# EtherSurface for iOS / iPadOS

A faithful port of the EtherSurface multi-touch synthesizer from Android to
iOS, using the same Csound 6/7 engine and the identical `etherpad.csd` synth
definition.

## Features (identical to Android)

- Full-screen multi-touch surface, up to 10 simultaneous fingers (11 on iPad)
- X axis = pitch (quantized to scale), Y axis = intensity / timbre
- 12 scales: Default, Major, Minor, Pentatonic, Flamenco, Blues, Chromatic,
  Whole-Tone, Octatonic, Bohlen-Pierce, Overtone Series (Low/High)
- 12 chromatic keys (C through B)
- 5-octave range
- 4 to 14 notes across the surface
- 5 sound modes: Ether Pad, Distorted Dreams, Xanpalamin, Give it a Tri,
  Digital Monk
- Delay + reverb effects

## Requirements

- Xcode 15.0+
- iOS 15.0+ deployment target
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- CMake 3.20+ (for building Csound from source: `brew install cmake`)

## Setup

### 1. Build the Csound iOS framework

```sh
cd EtherSurface-iOS
bash scripts/fetch-csound-ios.sh
```

This clones the Csound repo, runs the iOS build script, and places:
- `Frameworks/CsoundLib.xcframework` — the universal framework
- `Headers/` — `CsoundObj.h` and related headers

### 2. Generate the Xcode project

```sh
cd EtherSurface-iOS
xcodegen generate
```

This reads `project.yml` and produces `EtherSurface.xcodeproj`.

### 3. Open and build

```sh
open EtherSurface.xcodeproj
```

- Select a development team in Signing & Capabilities
- Build for a physical device (Csound requires arm64; the simulator may
  work if the xcframework includes simulator slices)

## Project structure

```
EtherSurface-iOS/
  project.yml                    XcodeGen project definition
  scripts/
    fetch-csound-ios.sh          Builds Csound xcframework from source
  Frameworks/                    CsoundLib.xcframework (generated)
  Headers/                       CsoundObj.h etc. (generated)
  EtherSurface/
    AppDelegate.swift            App entry point
    EtherSurfaceViewController.swift  Main VC: Csound lifecycle, menus, touch→engine
    EtherSurface-Bridging-Header.h    Imports CsoundObj.h for Swift
    Info.plist                   App configuration
    LaunchScreen.storyboard      Launch screen (solid dark bg)
    Engine/
      CsoundEngine.swift         Wraps CsoundObj: channels, score, lifecycle
    Views/
      TouchSurfaceView.swift     Full-screen UIView: grid, circles, touch tracking
    Resources/
      etherpad.csd               The synth — identical to the Android version
    About/
      AboutViewController.swift  WKWebView modal sheet
      about.html                 About page content (from Android assets)
      logo.png, logo_shadow.png
    Assets.xcassets/             App icon
```

## How it maps to the Android version

| Android                        | iOS                                          |
| ------------------------------ | -------------------------------------------- |
| `MainActivity.java`            | `EtherSurfaceViewController.swift`           |
| `MultiTouchView.java`          | `TouchSurfaceView.swift`                     |
| `AboutActivity.java`           | `AboutViewController.swift`                  |
| `CsoundOboe` (csnd.jar)       | `CsoundObj` (CsoundLib.xcframework)          |
| `res/raw/etherpad.csd`         | `Resources/etherpad.csd` (byte-identical)    |
| `res/menu/*.xml` popups        | `UIMenu` on toolbar `UIBarButtonItem`s       |
| `jniLibs/*.so` native libs     | `CsoundLib.xcframework` universal binary     |
| `SetControlChannel()`          | `getInputChannelPtr()` → write `float*`      |
| `InputMessage()`               | `sendScore()`                                |

## License

GPL-3.0 — same as the Android version. See `../gpl-3.0.txt`.
