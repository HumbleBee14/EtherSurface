# EtherSurface / Etherpad

A multi-touch synthesizer instrument. Drag fingers across the screen to
play — horizontal position picks pitch, vertical position controls
intensity. Multiple scales, keys, octaves, sound modes. The audio
engine is Csound; the UI is platform-native.

This repo hosts two implementations:

- **[EtherSurface-Android/](EtherSurface-Android/)** — the original 2014
  Android app by Paul Batchelor (CCRMA), modernized to Android 14 /
  AGP 8.5 / Csound 6.19 in 2026.
- **[EtherSurface-iOS/](EtherSurface-iOS/)** — *Etherpad*, the iOS / iPadOS
  app built from scratch in 2026 by Dinesh (HumbleBee). Same Csound
  engine on a native UIKit surface. The two ports share the `etherpad.csd`
  synth definition but otherwise have nothing in common code-wise.

## Layout

| Path | Contents |
| ---- | -------- |
| [`EtherSurface-Android/`](EtherSurface-Android/) | Android app — Gradle / AGP 8.5 / Java, Csound 6.19 via the Oboe Android SDK. See its own README. |
| [`EtherSurface-iOS/`](EtherSurface-iOS/) | Etherpad — Xcode project, Swift + Obj-C, Csound iOS 7. See its own README. |
| [`docs/`](docs/) | Cross-platform reference: architecture, Csound integration notes, the `.csd` synth definition, the 2014→2026 migration log, iOS port planning. |
| `legacy/` | Local-only (gitignored). Decompiled 2014 EtherPad APK and resources, kept for diffing. |

## Build & install

- **Android**: see [`EtherSurface-Android/README.md`](EtherSurface-Android/README.md).
- **iOS / iPadOS**: see [`EtherSurface-iOS/README.md`](EtherSurface-iOS/README.md)
  and [`EtherSurface-iOS/BUILD.md`](EtherSurface-iOS/BUILD.md) for the
  step-by-step Csound framework setup.

## Credits

- Original 2014 Android EtherSurface: **Paul Batchelor** ([batchelorsounds.com](https://batchelorsounds.com))
- 2026 Android modernization + iOS app (Etherpad): **Dinesh / HumbleBee** ([dineshy.com](https://dineshy.com))
- Sound engine: [Csound](https://www.csounds.com) by Barry Vercoe, Victor Lazzarini, et al.
