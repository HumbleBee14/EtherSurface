# EtherSurface / Etherpad

A multi-touch synthesizer instrument. Drag fingers across the screen to
play — horizontal position picks pitch, vertical position controls
intensity. Multiple scales, keys, octaves, sound modes. The audio
engine is Csound; the UI is platform-native.

This repo hosts three implementations:

- **[EtherSurface-Android-v2/](EtherSurface-Android-v2/)** — *Etherpad v2*, a
  from-scratch Kotlin + Jetpack Compose rewrite of the Android app in 2026
  by Dinesh (HumbleBee). Mirrors the iOS architecture: raw `csoundPerformKsmps`
  driven by Oboe in a small C++ engine; Compose handles the UI. Dropped the
  v1 `csnd.CsoundOboe` Java wrapper because its threaded score scheduler
  crashes Csound 6.19 with `FORTIFY pthread_mutex_lock` on score-end.
- **[EtherSurface-Android/](EtherSurface-Android/)** — the original 2014
  Android app by Paul Batchelor (CCRMA), modernized to Android 14 /
  AGP 8.5 / Csound 6.19 in 2026. Kept for history; v2 is the active build.
- **[EtherSurface-iOS/](EtherSurface-iOS/)** — *Etherpad*, the iOS / iPadOS
  app built from scratch in 2026 by Dinesh (HumbleBee). Same Csound
  engine on a native UIKit surface. The three ports share the `etherpad.csd`
  synth definition but otherwise have nothing in common code-wise.


## Build & install

- **Android (v2, current)**: see [`EtherSurface-Android-v2/README.md`](EtherSurface-Android-v2/README.md).
- **Android (v1, legacy)**: see [`EtherSurface-Android/README.md`](EtherSurface-Android/README.md).
- **iOS / iPadOS**: see [`EtherSurface-iOS/README.md`](EtherSurface-iOS/README.md)
  and [`EtherSurface-iOS/BUILD.md`](EtherSurface-iOS/BUILD.md) for the
  step-by-step Csound framework setup.

## Credits

- Original 2014 Android EtherSurface: ([**Paul Batchelor**](https://paulbatchelor.github.io/about/))
- 2026 Android modernization + iOS app (Etherpad): ([**Dinesh**](https://dineshy.com/))
- Sound engine: [Csound](https://www.csound.com) by Barry Vercoe, Victor Lazzarini, et al.
