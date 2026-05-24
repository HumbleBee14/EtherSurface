# Etherpad — Android v2

A from-scratch Kotlin + Jetpack Compose rewrite of the original 2014
Android EtherSurface, with the iOS app's audio architecture ported to
Android instead of the broken `csnd.CsoundOboe` wrapper used by v1.

## Why v2 exists

v1 used `csnd.CsoundOboe`, a threaded Java wrapper around Csound 6.19's
score scheduler. On score-end, that wrapper races its internal pthread
mutexes during teardown and crashes the app with
`FORTIFY: pthread_mutex_lock called on a destroyed mutex`. We exhausted
every patch angle on it without finding a safe fix.

v2 mirrors the iOS app instead: a tiny C++ engine that drives Csound
directly via the C API and feeds samples to an Oboe `AudioStreamCallback`.
No threaded wrapper, no broken score scheduler, no crash.

## Stack

| Layer    | Version              |
| -------- | -------------------- |
| AGP      | 9.2.1                |
| Gradle   | 9.4.1                |
| Kotlin   | 2.2.10               |
| Compose BOM | 2026.05.01 (Material 3) |
| Oboe     | 1.10.0 (Maven, Prefab AAR) |
| Csound   | 6.19, rebuilt with NDK r30 and `-Wl,-z,max-page-size=16384` (16 KB ELF aligned for Play Store) |
| `minSdk` / `targetSdk` | 24 / 36 |
| Package  | `com.humblebee.etherpad` |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Compose UI (Kotlin)                                     │
│   TouchSurface  ── pointerInput → Synth.touchDown/Move/Up
│   TopMenuBar    ── AlertDialog  → Synth.setKey/Scale/…  │
└────────────────────────┬────────────────────────────────┘
                         │ JNI (sparse — touch + menu events only)
                         ▼
┌─────────────────────────────────────────────────────────┐
│ EtherEngine (C++) — owns Csound + Oboe lifecycle        │
│   Oboe AudioStream  → onAudioReady() runs on audio thread
│                       calls csoundPerformKsmps()        │
│                       copies csoundGetSpout() to buffer │
│                       never tears down on score-end     │
└────────────────────────┬────────────────────────────────┘
                         │ links against
                         ▼
   libcsoundandroid.so   (Csound 6.19, 16 KB aligned)
```

The C++ engine never calls `csoundCleanup` / `csoundReset` from inside
the audio callback. If `csoundPerformKsmps` returns non-zero (score
finished), we zero-fill the buffer and keep the stream alive — the next
user touch spawns a fresh instr 1 instance and audio resumes. This is
exactly what kills v1 and works fine here.

## Source layout

```
app/src/main/
├── kotlin/com/humblebee/etherpad/
│   ├── MainActivity.kt          activity lifecycle, builds Synth, sets Compose content
│   ├── engine/
│   │   ├── EtherEngine.kt       JNI facade (one `external fun` per native entry)
│   │   └── Synth.kt             typed wrapper, owns score-message formatting
│   ├── synth/
│   │   └── Presets.kt           scale tables, labels, defaults (pure data)
│   └── ui/
│       ├── EtherSurfaceApp.kt   top-level composable
│       ├── TouchSurface.kt      Compose Canvas + multi-touch handler
│       ├── TopMenuBar.kt        five-button bar + dialog opener
│       ├── ChoiceDialog.kt      Material 3 single-choice picker
│       └── Theme.kt             palette
├── cpp/
│   ├── CMakeLists.txt           links Oboe (Maven) + libcsoundandroid (prebuilt)
│   └── engine.cpp               Oboe callback + Csound C API + JNI surface
├── jniLibs/{arm64-v8a, armeabi-v7a, x86_64}/
│   └── libcsoundandroid.so      Csound 6.19, 16 KB-aligned
└── res/raw/etherpad.csd         legacy 2014 synth definition (with $INF defined)
```


## Build

```sh
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Requires:
- JDK 17
- Android SDK Platform 36, Build-Tools 36
- NDK r28 or newer (Android Studio → SDK Manager → SDK Tools → NDK)


