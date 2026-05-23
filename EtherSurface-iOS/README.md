# Etherpad for iOS / iPadOS

A multi-touch synthesizer for iPhone and iPad. Drag fingers across the
screen to play — horizontal position picks the pitch, vertical position
controls intensity and timbre. Up to 5 simultaneous voices on iPhone (a
hardware limit), 10+ on iPad.

Built fresh for iOS in 2026. Inspired by Paul Batchelor's original 2014
Android version, EtherSurface.

## Features

- Full-screen multi-touch surface
  - **5** simultaneous fingers on iPhone (iOS digitizer hardware limit)
  - **10–11** on iPad
- X axis = pitch (quantized to scale), Y axis = intensity / timbre
- 12 scales: Default, Major, Minor, Pentatonic, Flamenco, Blues,
  Chromatic, Whole-Tone, Octatonic, Bohlen-Pierce, Overtone Series
  (Low/High)
- 12 chromatic keys (C through B)
- 5-octave range
- 4 to 14 notes across the surface
- 5 sound modes: Ether Pad, Distorted Dreams, Xanpalamin, Give it a Tri,
  Digital Monk
- Delay + reverb effects

## Building

**Read [BUILD.md](BUILD.md).** Etherpad depends on the Csound for iOS
framework (~12 MB), which is not committed to git and must be downloaded
and integrated into Xcode by each developer. The doc walks through the
steps in order.

TL;DR for someone who already knows the drill:

1. Download `csound-ios-7.0.0-beta.16.zip` from
   [csound/csound releases](https://github.com/csound/csound/releases)
2. Copy `CsoundiOS.xcframework` and `libSndfileiOS.xcframework` into
   `EtherSurface-iOS/`
3. Open `Etherpad.xcodeproj`, drag both into the target, set
   **Embed & Sign**
4. Pick your signing team, pick your device, ⌘R

Console should print `[Etherpad] Csound channels bound: 10/10`
within a second of launch. Touch the screen → sound.

## Project structure

```
EtherSurface-iOS/                  ← folder name kept for repo history
  BUILD.md                         Step-by-step build instructions
  Etherpad.xcodeproj/              The Xcode project
  Headers/                         Patched CsoundObj.h/.m + CsoundMIDI.h/.m
                                   — Obj-C wrapper sources, tracked in git
  CsoundiOS.xcframework/           (gitignored — download per BUILD.md)
  libSndfileiOS.xcframework/       (gitignored — download per BUILD.md)
  Etherpad/
    AppDelegate.swift              App entry point (UIScene config)
    SceneDelegate.swift            UIScene lifecycle, owns the UIWindow
    EtherpadViewController.swift   Main VC — Csound lifecycle, menus,
                                   touch → engine
    Etherpad-Bridging-Header.h     Imports CsoundObj.h for Swift
    Info.plist                     App configuration (scene manifest, etc.)
    LaunchScreen.storyboard        Launch screen (solid dark bg)
    Engine/
      CsoundEngine.swift           Wraps CsoundObj — channels, score,
                                   lifecycle, CsoundObjListener bridge
    Views/
      TouchSurfaceView.swift       Full-screen UIView — grid, finger
                                   circles, touch tracking
    Resources/
      etherpad.csd                 The synth definition (Csound)
    About/
      AboutViewController.swift    Native About sheet
      logo.png, logo_shadow.png
    Assets.xcassets/               App icon
```

## Architecture deep dive

See [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) for the full
walk-through of how the synth works (instruments, channels, the touch
data path).

See [../docs/IOS_PORT.md](../docs/IOS_PORT.md) for the two-path
analysis of porting strategies (this is Path A — Csound + native UI;
Path B would be an AudioKit-only rewrite).

## Credits

- iOS app by **Dinesh (aka HumbleBee)** — [dineshy.com](https://dineshy.com)
- Sound engine: [Csound](https://www.csounds.com)
- Inspired by the original 2014 Android EtherSurface by Paul Batchelor.
