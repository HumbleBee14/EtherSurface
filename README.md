# EtherSurface (EtherPad)

A multi-touch synthesizer for Android, originally written in 2014 by Paul
Batchelor at CCRMA, modernized in 2026 to run on current Android versions.

The instrument is essentially a touch-driven theremin: drag fingers across the
screen to play notes, with horizontal position selecting pitch and vertical
position controlling intensity. Up to ten simultaneous touches are supported.

## Features

- Selectable scales: Major, Minor, Pentatonic, Blues, Chromatic, Whole-Tone,
  Octatonic, Flamenco, Bohlen-Pierce, plus the original hybrid Default.
- Twelve chromatic keys, five-octave range, four to fourteen notes across the
  surface.
- Three sound modes: Ether Pad, Distorted Dreams, Xanpalamin.
- Multi-touch polyphony via Csound 6.

## Build

Requirements:
- JDK 17 or 21 (AGP 8.5 does not yet support 25)
- Android SDK with Platform 34 and Build-Tools 34
- `ANDROID_HOME` set, or a `local.properties` with `sdk.dir=...`

```sh
./gradlew assembleDebug
```

The resulting APK lands at `app/build/outputs/apk/debug/app-debug.apk` (~74 MB,
mostly the bundled Csound engine).

## Project layout

```
app/
  src/main/
    AndroidManifest.xml
    java/com/zebproj/etherpad/    Activities and custom views
    res/                          Layouts, menus, strings, drawables
    assets/                       About-page HTML
    jniLibs/{arm64-v8a,armeabi-v7a,x86_64}/
                                  libcsoundandroid.so + libc++_shared.so
  libs/csnd.jar                   Csound Java bindings
scripts/fetch-csound.sh           Re-extracts native libs and JAR from a
                                  gogins/csound-android release
```

## Updating Csound

The native engine is pinned to gogins/csound-android v48beta2. To pull a newer
release, edit `CSOUND_RELEASE_TAG` in `scripts/fetch-csound.sh` and run the
script — it will refresh the `.so` files (and, if `d2j-dex2jar.sh` is on your
PATH, the `csnd.jar` as well).

## Docs

- [docs/BUILD.md](docs/BUILD.md) — build, install, runtime debug.
- [docs/CSOUND.md](docs/CSOUND.md) — Csound vendoring, API changes since 2014.
- [docs/CSD.md](docs/CSD.md) — the synth definition, channels, known issues.
- [docs/MIGRATION.md](docs/MIGRATION.md) — what changed from the 2014 Eclipse project.

## License

GPL-3.0. See `gpl-3.0.txt`.
