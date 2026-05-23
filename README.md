# EtherSurface

A multi-touch synthesizer, originally written in 2014 by Paul Batchelor at
CCRMA. Drag fingers across the screen to play notes — horizontal position
picks pitch, vertical position controls intensity. Up to ten simultaneous
touches, ten scales, twelve keys, five octaves, five sound modes. The audio
engine is Csound; the UI is platform-native.

This repo hosts both the Android and iOS ports of the same instrument, each
in its own subfolder so the two platforms can evolve independently while
sharing project-level context (docs, the original 2014 reference material).

## Layout

| Path | Contents |
| ---- | -------- |
| [`EtherSurface-Android/`](EtherSurface-Android/) | Android app — Gradle / AGP 8.5 / Java, Csound 6.19 via the Oboe Android SDK. See its own README inside. |
| `EtherSurface-iOS/` | iOS port (separate branch, work in progress). |
| [`docs/`](docs/) | Cross-platform reference: architecture, Csound integration notes, the `.csd` synth definition, the 2014→2026 migration log. |
| `legacy/` | Local-only (gitignored). Decompiled 2014 EtherPad APK and resources, kept for diffing. |

## Build & install

See [`EtherSurface-Android/README.md`](EtherSurface-Android/README.md) for the
Android build, install, and debugging instructions.

iOS instructions live on the iOS branch.

## License

GPL-3.0. See [`gpl-3.0.txt`](gpl-3.0.txt).
