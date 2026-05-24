# Android v2 — clean-slate rewrite plan

The current `EtherSurface-Android/` (v1) reaches a known dead end:
`csnd.CsoundOboe` has unfixable thread / mutex races in its score-end path
that crash the app with `FORTIFY: pthread_mutex_lock called on a destroyed
mutex` after ~30–60 s of play on Csound 6.19. We exhausted every patch
angle (5 native C++ patches, 1 Java watchdog, 2 CSD heartbeats) and each
fix revealed a new failure mode.

iOS works flawlessly with the same Csound engine because it bypasses the
broken layer entirely: raw `csoundPerformKsmps()` driven by Apple's
`AudioUnit` render callback, all in Objective-C. v2 mirrors that
architecture for Android.

## Stack

| Layer | What | Version |
| ----- | ---- | ------- |
| Build | Android Gradle Plugin | 9.2.0 (Apr 2026, latest stable) |
| Build | Gradle | 9.x (required by AGP 9) |
| Build | JDK | 17 |
| Language | Kotlin | 2.3.21 (Compose compiler bundled) |
| UI | Jetpack Compose BOM | 2026.05.00 (Material 3 1.4.x) |
| UI | activity-compose | 1.12.4 (ComponentActivity, enableEdgeToEdge) |
| Audio | Oboe | 1.9.3 from `com.google.oboe:oboe:1.9.3` via Maven (Prefab AAR) |
| Audio engine | Csound 6.19 | reuse `libcsoundandroid.so` (rebuild for 16 KB alignment) |
| `targetSdk` | 36 (Android 16) | required by Play Store Aug 31, 2026 |
| `minSdk` | 24 (Android 7) | unchanged from v1 |

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ Kotlin / Jetpack Compose                                │
│ ┌─────────────────┐  ┌───────────────────────────────┐  │
│ │ TouchSurface    │  │ Top bar (Octave / Scale / …)  │  │
│ │  (Compose       │  │ Modal Material 3 menus with   │  │
│ │   Canvas)       │  │ radio-button current pick     │  │
│ └────────┬────────┘  └─────────────┬─────────────────┘  │
│          │ touch X/Y                │ score events       │
│          ▼                          ▼                    │
│        EtherEngine (Kotlin facade over a tiny JNI lib)  │
└──────────┬──────────────────────────────────────────────┘
           │ JNI (called only on sparse events:           │
           │ note-on, note-off, menu change, X/Y update)  │
           ▼
┌─────────────────────────────────────────────────────────┐
│ C++ render layer (small, ~200 LOC, our code)            │
│ - Oboe AudioStream, MODE_LOW_LATENCY, PCM_FLOAT         │
│ - onAudioReady() calls csoundPerformKsmps() directly    │
│ - copies csound->spout into Oboe output buffer          │
│ - never calls Csound's Cleanup() / Reset() in callback  │
│ - exposes setControlChannel + inputMessage to Kotlin    │
└────────────────────┬────────────────────────────────────┘
                     │ links against
                     ▼
            libcsoundandroid.so (vendored, 16 KB aligned)
```

Key contrasts to v1:

- **No `CsoundOboe` wrapper.** We call into the raw Csound 6 C API
  (`csoundCreate`, `csoundCompileCsdText`, `csoundStart`,
  `csoundPerformKsmps`, `csoundGetSpout`) ourselves.
- **No `CsoundThreaded` score scheduler.** Score events arrive only when
  the UI sends them. No background thread inside Csound is running its own
  loop.
- **No Java audio thread.** Oboe owns the high-priority audio callback.
  We never read `spout` from Java — the C++ render thread does it in-place.
- **JNI traffic is bounded.** Touch events fire at ≤120 Hz, not at the
  audio sample rate. Channel writes are 1 JNI call per axis per event.
- **No XML layouts.** Compose end to end. No Holo theme, no AppCompat.

## Folder plan

```
EtherSurface-Android-v2/
├── settings.gradle.kts
├── build.gradle.kts                (root, plugin versions only)
├── gradle/
│   ├── libs.versions.toml          (version catalog)
│   └── wrapper/                    (Gradle 9.x wrapper)
├── app/
│   ├── build.gradle.kts
│   ├── proguard-rules.pro
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── kotlin/com/zebproj/etherpad/
│       │   ├── MainActivity.kt
│       │   ├── ui/                 (Compose surface + menus)
│       │   └── engine/             (Kotlin facade over JNI)
│       ├── cpp/                    (our C++ render layer + CMakeLists.txt)
│       ├── res/
│       │   └── raw/etherpad.csd    (reused from v1, unchanged)
│       └── jniLibs/                (16 KB-aligned libcsoundandroid.so)
```

The `.csd` synth definition and the 5 sound modes are reused as-is —
that's the actual creative work and there's nothing to gain by rewriting.

## Phasing

1. **Tonight**: empty Gradle/Compose project scaffold that launches and
   shows "EtherSurface v2" text. No audio, no touch logic yet. Confirms
   the modern build pipeline works.
2. **Day 2**: write the C++ render layer (Oboe + Csound). Test with a
   fixed sine wave first, then with the .csd compiled. Confirm audio works
   without the crash.
3. **Day 3**: Compose multi-touch surface (Canvas + pointerInput). Wire
   touch X/Y to channel writes.
4. **Day 4**: Compose menus (TopAppBar + AlertDialog single-choice).
   Wire to score events.
5. **Day 5**: About / polish / migrate icons.
6. **Day 6**: cut v1 over. Rename `EtherSurface-Android-v2/` to
   `EtherSurface-Android/`, archive the old one.

## What v1 had that v2 won't carry over

- **`csnd.CsoundOboe`** (the crash source — replaced with our C++ layer)
- **XML layouts** (`actionbar.xml`, `activity_*.xml`) — Compose-only
- **AppCompat / Holo / `Theme.Holo.Light.DarkActionBar`** — Material 3
- **AlertDialog from `android.app`** — Material 3 `AlertDialog`
- **`R.id.size_*` / `R.id.key_*` menu item ids** — Compose state, no IDs
- **`MultiTouchView extends View`** — Compose `Canvas` with `pointerInput`
- **The vendored `csnd.jar`** — drop entirely, we link the native lib directly

## What v1 had that v2 reuses

- `etherpad.csd` — the synth definition (no changes)
- The five sound modes, ten scales, twelve keys, five-octave range — same
- Touch model: 10 simultaneous touches, x = pitch, y = intensity
- App icons (PNGs from `res/drawable-*dpi/`) — same artwork
- About-page concept — re-implemented in Compose

## Open questions for tomorrow

- **Csound .so 16 KB alignment**: gogins v48beta2 prebuilt isn't aligned.
  Either rebuild from source with NDK r27+, or accept the warning until
  upstream ships a 16 KB-aligned release. (We already explored the
  rebuild path and got the libs built once today — knowledge is captured.)
- **Whether to include MIDI input** — iOS app has a MIDI bridge but the
  Android app never has. Probably skip for v2 first cut.
- **Whether to expose visualization effects** (ripple, finger trail, etc.)
  like the iOS app's About menu. Easy in Compose. Add in phase 5.
