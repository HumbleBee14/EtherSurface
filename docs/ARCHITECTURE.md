# EtherSurface — Architecture Deep Dive

A complete, end-to-end walk-through of how the EtherSurface (EtherPad) Android
app works: what it is musically, how a finger on the glass becomes sound, and
where every piece of that pipeline lives in the codebase.

This document is intended as a reference for anyone modifying the DSP,
porting the app, or just trying to understand a 12-year-old Csound-on-Android
instrument that has been dragged into 2026.

---

## 1. What the instrument is

EtherSurface is a **touch-driven theremin / pad synth**. The entire screen is
one continuous instrument surface — there are no discrete keys. The width of
the screen is divided into 4–14 pitch zones (configurable), and the height
controls intensity / timbre / vibrato depth depending on the active sound.

- **X axis** → pitch, quantized to the active scale
- **Y axis** → loudness + a sound-specific second parameter (filter cutoff,
  modulation index, vibrato depth)
- Up to **10 simultaneous fingers**, each an independent voice

Configurable from the ActionBar popups:
- **Scale** — Major, Minor, Pentatonic, Blues, Chromatic, Whole-Tone,
  Octatonic, Flamenco, Bohlen-Pierce, and the original hybrid "Default"
- **Key** — twelve chromatic roots (C through B)
- **Octave** — five-octave range (−2 to +2)
- **Size** — 4 to 14 notes across the surface
- **Sound** — Ether Pad, Distorted Dreams, Xanpalamin (three exposed modes;
  the CSD actually defines five — see §4)

---

## 2. High-level architecture

Three layers, top to bottom:

```
 ┌─────────────────────────────────────────────────┐
 │  UI layer (pure Android / Java)                 │
 │  - MainActivity: lifecycle, menus, touch→Csound │
 │  - MultiTouchView: background, grid lines,      │
 │    translucent yellow touch circles             │
 └─────────────────────────┬───────────────────────┘
                           │  SetControlChannel / InputMessage
 ┌─────────────────────────▼───────────────────────┐
 │  Bridge layer (csnd.jar — Java↔C++ JNI)         │
 │  - CsoundOboe: Csound 6.19 engine wrapper       │
 │  - CsoundCallbackWrapper: log capture           │
 └─────────────────────────┬───────────────────────┘
                           │  chnget / score events
 ┌─────────────────────────▼───────────────────────┐
 │  DSP layer (etherpad.csd — Csound orchestra)    │
 │  - instr 1: per-voice synth (5 sound modes)     │
 │  - instr 888: delay bus                         │
 │  - instr 999: reverb bus                        │
 │  - instr Mixer: clip + outs                     │
 │  - instr 100–104: parameter setters             │
 └─────────────────────────┬───────────────────────┘
                           │  Oboe (C++ audio lib)
 ┌─────────────────────────▼───────────────────────┐
 │  Android audio (AAudio on 8.1+, OpenSL ES else) │
 └─────────────────────────────────────────────────┘
```

The 95% of the ~37 MB APK that is *not* Java is the Csound 6.19 native
library (`libcsoundandroid.so`, `libsndfile.so`, `liboboe.so`, `libc++_shared.so`)
shipped under [app/src/main/jniLibs/](../app/src/main/jniLibs/).

---

## 3. UI layer — Android side

### 3.1 [MainActivity.java](../app/src/main/java/com/zebproj/etherpad/MainActivity.java)

Single full-screen Activity. Responsibilities:

1. **Boot Csound** in [`onCreate`](../app/src/main/java/com/zebproj/etherpad/MainActivity.java#L135) →
   `startCsound()` which compiles the embedded `.csd`, calls `Start()`, then
   `Play()` to begin pulling audio.
2. **Own the touch state**: arrays of size 10 tracking pointer ID, normalized
   X, normalized Y for each slot ([MainActivity.java:70-77](../app/src/main/java/com/zebproj/etherpad/MainActivity.java#L70-L77)).
3. **Pre-build hot-path strings** in an instance initializer
   ([MainActivity.java:79-86](../app/src/main/java/com/zebproj/etherpad/MainActivity.java#L79-L86))
   — `touch.0.x`, `touch.0.y`, `i1.0 0 -2 0`, `i-1.0 0 0 0`, …, ×10 — so the
   touch event loop never allocates. (This was added during the 2026
   modernization; the 2014 code used `String.format` per move.)
4. **Forward MotionEvents to Csound** in the `OnTouchListener` at
   [MainActivity.java:155-213](../app/src/main/java/com/zebproj/etherpad/MainActivity.java#L155-L213):
   - `ACTION_DOWN` / `ACTION_POINTER_DOWN`: allocate a slot, write
     `SetControlChannel(touch.N.x/y)`, fire `InputMessage("i1.N 0 -2 N")` to
     start a held voice (negative p3 = indefinite).
   - `ACTION_MOVE`: just rewrite the X/Y control channels for each active
     pointer.
   - `ACTION_POINTER_UP` / `ACTION_UP`: fire `InputMessage("i-1.N 0 0 N")` to
     turn off that instance.
5. **Menu plumbing** — the ActionBar custom view ([res/layout/actionbar.xml](../app/src/main/res/layout/actionbar.xml))
   shows five labels that open PopupMenus inflated from
   [res/menu/](../app/src/main/res/menu/). Each click maps to one of:
   - `setSize(n)` → `i100 0 0.5 n` (changes `gisize` global)
   - `setKey(0..11)` → `i101 0 0.5 k`
   - `setOctave(-2..2)` → `i102 0 0.5 o`
   - `setSound(0..2)` → `i104 0 0.5 s`
   - `setScale(int[14])` → `i103 0 0.5` followed by 14 scale-step integers
6. **Lifecycle** — `onPause` lifts all held fingers ([MainActivity.java:259-269](../app/src/main/java/com/zebproj/etherpad/MainActivity.java#L259-L269))
   so backgrounding the app doesn't strand stuck notes. `onDestroy` calls
   `Stop()` + `Cleanup()`. The engine itself is **kept running** during
   pause/resume (an earlier experiment with pause/resume was reverted because
   it caused audio glitches — see observation 3472 in claude-mem).

### 3.2 [MultiTouchView.java](../app/src/main/java/com/zebproj/etherpad/MultiTouchView.java)

A custom `View` set as the Activity's content view. Purely visual:

- `onDraw` paints a dark slate background, then `numberOfNotes − 1` vertical
  grid lines at fractions of the width, then a translucent yellow circle
  (60 dp radius) for each visible touch.
- Has its own `onTouchEvent` that mirrors MainActivity's pointer tracking
  *only to drive its own redraw*. It does **not** talk to Csound — the
  MainActivity `OnTouchListener` calls `multiTouchView.onTouchEvent(event)`
  explicitly to keep visuals in sync ([MainActivity.java:158](../app/src/main/java/com/zebproj/etherpad/MainActivity.java#L158)).
- `setNumberOfNotes(double)` is called from `MainActivity.setSize` to redraw
  the grid when the user changes the size. This is a push model — the 2026
  refactor replaced an earlier pull-based `NumberOfNotesProvider` lambda
  (observations 3465–3467).

### 3.3 [AboutActivity.java](../app/src/main/java/com/zebproj/etherpad/AboutActivity.java)

A trivial WebView that loads [assets/about.html](../app/src/main/assets/about.html).

---

## 4. DSP layer — [etherpad.csd](../app/src/main/res/raw/etherpad.csd)

The Csound orchestra. This is where the actual music happens; everything
above is plumbing.

### 4.1 Engine settings

```csound
nchnls = 2          ; stereo
0dbfs  = 1          ; floating-point amplitude, full-scale = 1.0
ksmps  = 32         ; 32 audio samples per control period (~0.73 ms @ 44.1k)
sr     = 44100
-o dac -d -b512 -B2048
```

`-b512` software buffer, `-B2048` hardware buffer — conservative values
chosen so even budget Android devices don't underrun.

### 4.2 Tables (function tables, generated at orchestra load)

| Table          | Purpose                                                     |
| -------------- | ----------------------------------------------------------- |
| `giscale`      | 14-step scale lookup, rewritten when user picks a new scale |
| `gisine`       | one-cycle sine, 4096 points                                 |
| `giadd`        | additive sine with 4 equal harmonics                        |
| `gicosine`     | cosine wave                                                 |
| `gienv`        | exponential decay envelope, used by Xanpalamin's "ping"     |
| `gisig`        | sigmoid waveshaper                                          |
| `gipalamin`    | Chebyshev polynomial (GEN12, alpha=20) for Xanpalamin       |
| `givow_a..u`   | five sets of vowel formant frequencies / amps / bandwidths  |
| `givowindx`    | index table that morphs A→E→I→O→U for the vowel filter      |

### 4.3 The `vowel` user-defined opcode

A five-band parallel `butbp` (Butterworth bandpass) bank whose centre
frequencies, amps, and bandwidths are linearly interpolated between two
adjacent vowels in `givowindx`. This is what gives sound mode 4
("Digital Monk") its singing-formant character.

### 4.4 instr 1 — the voice

Instantiated once per finger via `i1.N 0 -2 N`. Lifecycle ends with
`i-1.N 0 0 N`. Inside:

1. **Read normalized touch** (sprintf the channel name from `p4`, the
   instance number — Java pre-builds the same strings on its side so they
   match):
   ```csound
   kx chnget S_xName
   ky chnget S_yName
   kx = 1 - kx           ; flip so left=low, right=high
   kx port kx, 0.01      ; 10 ms smoothing
   ky port ky, 0.01
   ```
2. **Vibrato** — a 6 Hz sine LFO scaled by Y: `kvib oscili ky * 0.4, 6, gisine`.
3. **Pitch** — four branches keyed off `giscale_type`:
   - **0 (ET MIDI, default)** — scale `kx` to `[0, gisize)`, integer-truncate,
     look up the step in `giscale`, add `gikey + 12*(gioct+1)` plus vibrato,
     convert MIDI→Hz with `cpsmidinn`.
   - **1 (Bohlen-Pierce)** — `kpow = 3^(kstep/13)`, multiply against the
     root frequency. A non-octave scale based on the tritave (3:1).
   - **2 & 3 (Overtone Series)** — integer multiples of the root (mode 2
     starts at the 2nd harmonic, mode 3 at the 5th).
   The orchestra computes both `kcps` (with vibrato) and `kcps_flat`
   (without) for sounds that want a clean carrier.
4. **Sound generator** — switch on `gisound`:

   | `gisound` | Name              | Opcodes / character                                                                             |
   | --------- | ----------------- | ----------------------------------------------------------------------------------------------- |
   | **0**     | Ether Pad         | `foscili` (sine-on-sine FM), `linsegr 0,0.5,1,1,0` — 0.5 s soft attack pad                       |
   | **1**     | Distorted Dreams  | `vco2` sawtooth → `lpf18` resonant lowpass (Y → cutoff, resonance, distortion), 5 ms attack     |
   | **2**     | Xanpalamin        | Xenakis-style FM with `tablei` waveshaping through `gipalamin`, plus a panned "ping" oscillator |
   | **3**     | Give It a Tri     | `vco2` triangle, fast attack (hidden — only sounds 0–2 are exposed in the menu)                 |
   | **4**     | Digital Monk      | `vco2` saw → `vowel` formant filter morphing A→E→I→O→U as `1 - ky` (hidden)                     |

   Each branch writes the voice's stereo output to `a1, a2`.
5. **Bus routing**:
   ```csound
   gaMainL = gaMainL + a1               ; dry mix
   gaMainR = gaMainR + a2
   gadelL  = gadelL + a1 * ksend        ; delay send
   gadelR  = gadelR + a1 * ksend
   gaL     = gaL + a1 * ksend           ; reverb send
   gaR     = gaR + a2 * ksend
   ```
   `ksend` is 1 for sounds 0/1/3/4, 0.5 for Xanpalamin (which has its own
   prominent internal delay-ping).

### 4.5 instr 888 — delay bus

Stereo feedback delay, 800 ms, 70% feedback, 6 kHz lowpassed on each repeat.
Mixes back into `gaMainL/R`.

### 4.6 instr 999 — reverb bus

`reverbsc gaL, gaR, 0.985, 10000` — Sean Costello / Csound's built-in
Schroeder reverb with feedback 0.985 and cutoff 10 kHz. Long tail.

### 4.7 instr Mixer

```csound
aL clip gaMainL, 1, 1
aR clip gaMainR, 1, 1
outs aL, aR
clear gaMainL, gaMainR
```
Soft-clip with method 1 (sigmoid), send to DAC, zero the bus. This is the
*only* place audio leaves Csound for the device.

### 4.8 instr 100–104 — parameter setters

Triggered by the Java menu callbacks. They run for 0.5 s, write a global
(`gisize`, `gikey`, `gioct`, `giscale_type`, `gisound`), and exit. instr 103
also rewrites the `giscale` ftable when the user picks an ET scale.

### 4.9 Always-on score

```csound
i888 0 $INF      ; delay bus
i999 0 $INF      ; reverb bus
i"Mixer" 0 $INF
i100 0 0.5 8     ; initial size = 8
i101 0 4 0       ; initial key = C (held 4 s but the global stays)
```

`$INF` is defined as 360000 — i.e., 100 hours. The instrument simply does
not last that long in a single session.

---

## 5. Csound bridge layer

### 5.1 [csnd.jar](../app/libs/csnd.jar)

The official Java bindings shipped with Csound's Android build. Provides:

- `csnd.Csound` — the C++ Csound class
- `csnd.CsoundOboe` — wrapper that opens an **Oboe** audio stream (Google's
  low-latency C++ audio lib) and pumps Csound's `PerformKsmps` from the
  audio callback
- `csnd.CsoundCallbackWrapper` — for capturing Csound's `printf` messages
  into Java

### 5.2 Native libraries — [app/src/main/jniLibs/](../app/src/main/jniLibs/)

Loaded explicitly in [MainActivity.java:57-62](../app/src/main/java/com/zebproj/etherpad/MainActivity.java#L57-L62):

```java
System.loadLibrary("c++_shared");     // libc++ runtime
System.loadLibrary("sndfile");        // libsndfile (WAV/AIFF I/O)
System.loadLibrary("oboe");           // Google Oboe
System.loadLibrary("csoundandroid"); // Csound 6.19 + JNI glue
```

Order matters — Csound depends on Oboe and sndfile, which depend on libc++.

### 5.3 Provenance — [scripts/fetch-csound.sh](../scripts/fetch-csound.sh)

Re-pulls the native libs from a `gogins/csound-android` GitHub release.
Currently pinned to `v48beta2`. Bumping the engine is one variable change
plus running the script.

---

## 6. The data path for a single finger

End-to-end, what happens when you touch the screen:

```
1. Android dispatches MotionEvent (ACTION_POINTER_DOWN)
       │
       ▼
2. MainActivity.onTouch
   - finds first free slot (id=N in 0..9)
   - touchX[N] = event.getX(i) / view.width
   - touchY[N] = 1 - event.getY(i) / view.height
       │
       ▼
3. csound.SetControlChannel("touch.N.x", touchX[N])
   csound.SetControlChannel("touch.N.y", touchY[N])
   csound.InputMessage("i1.N 0 -2 N")
       │  (JNI → C++ Csound)
       ▼
4. Csound schedules instance N of instr 1, indefinite duration
       │
       ▼
5. Every ksmps (32 samples ≈ 0.73 ms):
   - instr 1.N: kx = chnget "touch.N.x", ky = chnget "touch.N.y"
   - compute kcps, run the active sound generator
   - sum into gaMainL/R + sends
       │
       ▼
6. instr 888 (delay) + instr 999 (reverb) add their tails
       │
       ▼
7. instr Mixer: clip + outs → Oboe callback
       │
       ▼
8. Oboe → AAudio → device DAC → speaker
```

Finger moves → only step 3a (`SetControlChannel`) runs again. Finger up →
`InputMessage("i-1.N ...")` which fires the `linsegr` release stage on the
voice.

---

## 7. Build & packaging

- **Gradle KTS** ([app/build.gradle.kts](../app/build.gradle.kts)) — AGP 8.5,
  Java 17/21, minSdk 21, targetSdk 34.
- **ABI splits** enabled, producing three APKs:
  - `arm64-v8a` ≈ 37 MB (modern phones — the only one most users need)
  - `armeabi-v7a` ≈ 27 MB (legacy 32-bit)
  - `x86_64` ≈ 34 MB (emulators, ChromeOS)
- **ProGuard** ([app/proguard-rules.pro](../app/proguard-rules.pro)) keeps
  `csnd.**` so JNI bindings survive R8 shrinking.

The 95%-native size is dominated by `libcsoundandroid.so`. There is no
practical way to shrink this without rebuilding Csound with most opcodes
stripped, which would mean auditing the `.csd` for every opcode it uses
and forking the engine. Not worth it for an app this small.

---

## 8. Known issues & rough edges

(See [docs/CSD.md](CSD.md) for more.)

- **Click on sound 1 attack** — the `linsegr 0, 0.005, 1, 0.15, 0` envelope
  on Distorted Dreams has a 5 ms attack which can pop on percussive touches.
- **Sounds 3 and 4** (Tri, Digital Monk) exist in the CSD but are not exposed
  in the menu. The `sounds.xml` menu only lists three options.
- **Bohlen-Pierce scale** — the user picks "Bohlen-Pierce" from the Scales
  menu but that sends `i103 0 0.5 -1`, which sets `giscale_type=1` and
  ignores the actual scale array entirely. The other "overtone" variants
  (`giscale_type` 2 & 3) have no menu entry at all.
- **Stuck notes after onPause** — fixed in 2026 by lifting all touches in
  `onPause` ([MainActivity.java:259-269](../app/src/main/java/com/zebproj/etherpad/MainActivity.java#L259-L269)).

---

## 9. File map (quick reference)

| Path                                                                                  | What it is                                      |
| ------------------------------------------------------------------------------------- | ----------------------------------------------- |
| [MainActivity.java](../app/src/main/java/com/zebproj/etherpad/MainActivity.java)      | Activity, touch→Csound bridge, menu plumbing    |
| [MultiTouchView.java](../app/src/main/java/com/zebproj/etherpad/MultiTouchView.java)  | Visual surface (background, grid, finger blobs) |
| [AboutActivity.java](../app/src/main/java/com/zebproj/etherpad/AboutActivity.java)    | WebView for the About page                      |
| [etherpad.csd](../app/src/main/res/raw/etherpad.csd)                                  | The synth — all DSP lives here                  |
| [res/menu/](../app/src/main/res/menu/)                                                | Scale / key / octave / size / sound popups      |
| [res/layout/actionbar.xml](../app/src/main/res/layout/actionbar.xml)                  | Custom ActionBar with the five menu buttons     |
| [assets/about.html](../app/src/main/assets/about.html)                                | About page content                              |
| [libs/csnd.jar](../app/libs/csnd.jar)                                                 | Csound Java bindings                            |
| [jniLibs/](../app/src/main/jniLibs/)                                                  | `libcsoundandroid.so`, `liboboe.so`, etc.       |
| [scripts/fetch-csound.sh](../scripts/fetch-csound.sh)                                 | Re-extracts native libs from a Csound release   |
| [docs/CSD.md](CSD.md)                                                                 | Channel/instrument map + known synth issues     |
| [docs/CSOUND.md](CSOUND.md)                                                           | Csound vendoring, API changes since 2014        |
| [docs/MIGRATION.md](MIGRATION.md)                                                     | What changed from the 2014 Eclipse project      |
| [docs/BUILD.md](BUILD.md)                                                             | Build, install, runtime debug                   |
