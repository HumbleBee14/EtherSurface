# EtherSurface on iOS / iPadOS — Port Plan

A planning document for bringing EtherSurface to iPhone and iPad. Builds on
[ARCHITECTURE.md](ARCHITECTURE.md) — read that first if you want to know
what the Android app actually does internally.

iPad is, frankly, a *better* home for this instrument than Android: bigger
glass, more reliable multitouch (up to 11 simultaneous points), lower audio
latency through Core Audio, ProMotion 120 Hz touch sampling on iPad Pro, and
a music-app ecosystem (AUv3 hosts, MIDI, Ableton Link, Audiobus) that Android
genuinely does not have an equivalent of.

There are two credible paths. They are not mutually exclusive — Path A is the
fast, faithful port; Path B is the longer-term native rewrite.

---

## TL;DR recommendation

1. **Path A first** (1–2 weeks of work for one iOS dev): port directly using
   the official **Csound for iOS** framework. The `.csd` file ships unchanged.
   You get a working iPad build that sounds identical to the Android one.
2. **Path B as v2** (4–8 weeks): rebuild the synth in **AudioKit** /
   AVAudioEngine. Smaller binary, App Store friendly, unlocks **AUv3** so
   EtherSurface becomes a plugin loadable inside GarageBand, Logic, AUM,
   Cubasis, etc. — which is what serious iPad musicians actually want.

---

## Path A — Direct port with Csound for iOS

### Why this works

Csound is the same engine on both platforms. The Android app's entire DSP
layer ([etherpad.csd](../app/src/main/res/raw/etherpad.csd)) is portable
verbatim. Every opcode it uses — `foscili`, `vco2`, `lpf18`, `reverbsc`,
`delay`, `linsegr`, `chnget` / `chnset`, the custom `vowel` opcode, all the
function tables — is in the iOS build.

What changes is the *bridge layer*: instead of `csnd.CsoundOboe` you use
`CsoundObj`, the Objective-C wrapper that Csound ships under
[csound/csound/iOS](https://github.com/csound/csound/tree/develop/iOS). It is
fully callable from Swift via a bridging header.

### API mapping

The Android calls used in [MainActivity.java](../app/src/main/java/com/zebproj/etherpad/MainActivity.java)
map almost one-to-one:

| Android (`CsoundOboe`)                                  | iOS (`CsoundObj`)                                  |
| ------------------------------------------------------- | -------------------------------------------------- |
| `new CsoundOboe()`                                      | `CsoundObj()`                                      |
| `CompileCsdText(csdString)` + `Start()` + `Play()`      | `csound.play(csd: url)` / `csound.read(csd:)` then `csound.play()` |
| `SetControlChannel("touch.0.x", 0.42f)`                 | `csound.setValue(0.42, forChannelName: "touch.0.x")` |
| `InputMessage("i1.0 0 -2 0")`                           | `csound.sendScore("i1.0 0 -2 0")`                 |
| `Stop()` / `Cleanup()`                                  | `csound.stop()`                                    |

Audio output: CsoundObj sits on top of **AVAudioEngine** / Core Audio. On
iOS you don't manage buffer sizes the way `-b512 -B2048` does on Android —
Core Audio's hardware buffer is set via `AVAudioSession.setPreferredIOBufferDuration`.
Sensible default: 5 ms (256 frames @ 48 kHz). Drop the Csound `-b`/`-B`
flags from the `<CsOptions>` block or leave them; they're advisory.

### Module-by-module port

| Android module                                                                          | iOS replacement                                                                                                       |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| [MainActivity.java](../app/src/main/java/com/zebproj/etherpad/MainActivity.java)        | `ViewController` (UIKit) or `@main App` (SwiftUI). Owns the `CsoundObj` instance, lifecycle, menu state.              |
| [MultiTouchView.java](../app/src/main/java/com/zebproj/etherpad/MultiTouchView.java)    | A `UIView` subclass overriding `touchesBegan/Moved/Ended/Cancelled`. Or a SwiftUI `Canvas` with `.gesture(...)`.       |
| [res/menu/*.xml](../app/src/main/res/menu/) popups                                      | `UIMenu` attached to navigation-bar buttons (iOS 14+), or SwiftUI `Menu { … }`. Same picker semantics.                |
| [res/layout/actionbar.xml](../app/src/main/res/layout/actionbar.xml)                    | `UINavigationBar` items, or a SwiftUI `.toolbar { … }`.                                                               |
| [scripts/fetch-csound.sh](../scripts/fetch-csound.sh)                                   | Swift Package Manager dependency on Csound's iOS package, or drop in the prebuilt `CsoundObj.xcframework`.            |
| [jniLibs/](../app/src/main/jniLibs/)                                                    | XCFramework — universal binary covering arm64 device + arm64/x86_64 simulator. ~20 MB unstripped.                     |

### Touch handling — the part that gets *simpler* on iOS

The Android touch loop has to manually maintain `touchIds[10]` because
`MotionEvent.getPointerId(i)` returns opaque integers that can be reused
arbitrarily. On iOS, `UITouch` is itself the stable identity for the lifetime
of a finger:

```swift
private var voices: [UITouch: Int] = [:]   // UITouch → voice slot 0..9

override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    for t in touches {
        guard let slot = (0..<10).first(where: { !voices.values.contains($0) })
        else { continue }
        voices[t] = slot
        let p = t.location(in: self)
        let x = p.x / bounds.width
        let y = 1 - p.y / bounds.height
        csound.setValue(Float(x), forChannelName: "touch.\(slot).x")
        csound.setValue(Float(y), forChannelName: "touch.\(slot).y")
        csound.sendScore("i1.\(slot) 0 -2 \(slot)")
    }
}

override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    for t in touches {
        guard let slot = voices[t] else { continue }
        let p = t.location(in: self)
        csound.setValue(Float(p.x / bounds.width),  forChannelName: "touch.\(slot).x")
        csound.setValue(Float(1 - p.y / bounds.height), forChannelName: "touch.\(slot).y")
    }
}

override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    for t in touches {
        guard let slot = voices.removeValue(forKey: t) else { continue }
        csound.sendScore("i-1.\(slot) 0 0 \(slot)")
    }
}
override func touchesCancelled(_ t: Set<UITouch>, with e: UIEvent?) {
    touchesEnded(t, with: e)
}
```

That's the entire equivalent of the 60-line `OnTouchListener` block in
[MainActivity.java:155-213](../app/src/main/java/com/zebproj/etherpad/MainActivity.java#L155-L213).

### iPad-specific upsides for free

- **Apple Pencil pressure** → use `UITouch.force / UITouch.maximumPossibleForce`
  as a third axis. Map it to a new control channel (`touch.N.z`) and add a
  branch in instr 1 so e.g. pressure modulates filter resonance or FM index.
- **ProMotion (120 Hz)** on iPad Pro means `touchesMoved` fires at twice the
  rate, so glissandi feel noticeably smoother than the same `.csd` running
  on an Android phone capped at 60 Hz touch reporting.
- **Stage Manager / Split View** — works for free if you implement the audio
  session correctly (see Pitfalls).
- **MIDI input** — `CoreMIDI` is two screens of code; you could map a MIDI
  keyboard onto the scale and let the surface continue to do timbre.
- **Ableton Link** — one CocoaPod / SPM dependency, exposes the global tempo
  grid. Not strictly needed for a free-time instrument but trivial to add.

### Pitfalls / gotchas

1. **Audio session category**. You must configure `AVAudioSession` early:
   ```swift
   try AVAudioSession.sharedInstance().setCategory(.playback,
       mode: .default, options: [.mixWithOthers])
   try AVAudioSession.sharedInstance()
       .setPreferredIOBufferDuration(0.005)   // ~5 ms
   try AVAudioSession.sharedInstance().setActive(true)
   ```
   Without `.mixWithOthers` you can't run alongside Spotify / other AUv3
   hosts. `.playback` (not `.playAndRecord`) is right — no mic needed.
2. **Background behaviour**. iOS will kill audio when the app backgrounds
   unless you declare the `audio` background mode in Info.plist. Decide
   whether you *want* that — for a touch-driven theremin probably not (it's
   a foreground instrument), but if a user is recording into a host you do.
3. **Interruptions**. Phone calls, Siri, alarm clocks — register for
   `AVAudioSession.interruptionNotification` and call `csound.stop()` /
   `csound.play(...)` to resume. The Android port punted on this; iOS users
   will notice if you do the same.
4. **GPL-3 and the App Store**. EtherSurface is GPL-3.0. The App Store's
   standard licence agreement has historically conflicted with GPL-3 in ways
   that have led to GPL apps (e.g. VLC, GNU Go) being pulled. You will need
   to either:
   - Publish under an additional licence from the copyright holder
     (Paul Batchelor) granting App Store distribution, or
   - Relicense the *new iOS code* under something compatible (the original
     `.csd` would remain GPL-3 but is just a data asset), or
   - Distribute via TestFlight + AltStore / sideloading only.
   This is a *non-technical blocker* — clarify before writing code.
5. **The "Bohlen-Pierce / overtone series" menu bug** documented in
   [ARCHITECTURE.md §8](ARCHITECTURE.md#8-known-issues--rough-edges) should
   be fixed *before* porting, not after — it's a one-line CSD change and you
   don't want it duplicated in two codebases.

### Estimated effort (Path A)

| Task                                                              | Time      |
| ----------------------------------------------------------------- | --------- |
| Scaffold Xcode project, add CsoundObj XCFramework                 | 0.5 day   |
| Port touch surface (UIView + drawing)                             | 0.5 day   |
| Wire CsoundObj to channels, verify a single note plays            | 0.5 day   |
| Port the five menus + parameter setters                           | 1 day     |
| Audio session, interruptions, background mode                     | 0.5 day   |
| Polish: launch screen, icon, About page (WKWebView)               | 0.5 day   |
| QA on iPhone + iPad, fix touch / latency / lifecycle bugs         | 1–2 days  |
| **Total**                                                         | **~5 days** |

---

## Path B — Native rewrite on AudioKit / AVAudioEngine

### Why this exists

Path A ships a 30+ MB native binary, locks you to GPL-3 (because Csound is
LGPL but distribution alongside GPL `.csd` muddies it on the App Store), and
gives you no path to AUv3. If you want EtherSurface to be a *first-class
iPad music app* — installable as a plugin in GarageBand and Logic, downloadable
at <10 MB, reviewed without legal friction — you need to drop Csound.

[AudioKit](https://github.com/AudioKit/AudioKit) is the obvious replacement.
It's Swift-native, built on AVAudioEngine, MIT-licensed, and is what
AudioKit Pro's commercial synths (Synth One, Super J8, Retro Keys) are built
on. [AudioKitSynthOne](https://github.com/AudioKit/AudioKitSynthOne) is open
source and an excellent reference for "how do I build a real polyphonic
synth on AudioKit" — it implements voice management, AUv3 wrapping, MIDI,
preset storage, all of it.

### Reconstructing the five sound modes

| `.csd` sound mode | AudioKit / AVAudioEngine equivalent                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **0 Ether Pad** (FM sine)         | `FMOscillator` or two `Oscillator`s with `Operation` modulation; long attack via `AmplitudeEnvelope`                |
| **1 Distorted Dreams** (saw+LPF)  | `Oscillator(waveform: .sawtooth)` → `MoogLadder` (Y → cutoff, resonance)                                            |
| **2 Xanpalamin** (waveshaper FM)  | `WaveShaper` with a custom Chebyshev table + `Oscillator` for the ping, `Panner` LFO. This is the *hardest* to match.|
| **3 Give It a Tri** (triangle)    | `Oscillator(waveform: .triangle)` + envelope                                                                        |
| **4 Digital Monk** (vowel)        | `VocalTract` or `FormantFilter` (AudioKit has both)                                                                 |

Voice management: keep a pool of 10 voice nodes, allocate on touch-down,
release on touch-up, voice-steal oldest when the pool is exhausted. This is
~50 lines of Swift; [AudioKitSynthOne's voice manager](https://github.com/AudioKit/AudioKitSynthOne)
is a copy-pasteable reference.

Effects:
- Delay bus → `Delay` (`feedback`, `lowPassCutoff` already match instr 888's
  knobs)
- Reverb bus → `CostelloReverb` (Sean Costello / FreeVerb — same lineage as
  Csound's `reverbsc`)
- Master clip → `Clipper`

### What you gain

- **AUv3**: wrap the engine as `AUAudioUnit`. EtherSurface now appears in
  any iOS DAW's plugin list. This is the single biggest reason to do Path B.
- **Binary size**: ~5 MB instead of ~37 MB.
- **App Review**: no GPL conflict, no concerns about an embedded scripting
  engine (`CompileCsdText` is technically dynamic code execution from a
  resource file; Apple has historically been jumpy about this).
- **Tighter latency**: AVAudioEngine straight to the hardware buffer, no
  Csound `ksmps` granularity (32 samples ≈ 0.73 ms) in the way. Probably
  saves 1–2 ms round-trip.
- **MIDI / Bluetooth MIDI / Ableton Link** are dependencies, not features
  you build.

### What you lose

- **The exact sound.** Xanpalamin in particular is going to require careful
  matching against the Csound reference. `gipalamin`'s Chebyshev polynomial
  (`ftgen 0, 0, 8192, -12, 20.0`) is a specific waveshaping curve; you'd
  port it as a hardcoded table.
- **The `.csd` as a single source of truth.** Right now Paul Batchelor (or
  anyone) can tweak the synth by editing one file. After Path B the synth
  is Swift code, distributed across N files.
- **Csound's "free" port** — the Android version cannot use the new engine
  without a parallel rewrite there too. You'd be maintaining two synths.

### Estimated effort (Path B)

| Task                                                              | Time       |
| ----------------------------------------------------------------- | ---------- |
| Project scaffold, AudioKit SPM integration, basic Oscillator → out | 1 day      |
| Voice manager (10 voices, allocate/release/steal)                 | 1–2 days   |
| Sound mode 0 (Ether Pad FM)                                       | 1 day      |
| Sound mode 1 (Distorted Dreams)                                   | 0.5 day    |
| Sound mode 2 (Xanpalamin) — *the hard one*                        | 3–5 days   |
| Sound modes 3 & 4                                                 | 1 day      |
| Delay + reverb + master clip                                      | 1 day      |
| Scale system (lookup tables for all 10 scales + BP / overtones)   | 1 day      |
| UI port (same as Path A)                                          | 2 days     |
| Audio session, MIDI, Link                                         | 1 day      |
| **AUv3 wrapping**                                                 | 3–5 days   |
| QA and sound-matching against Android reference                   | 3–5 days   |
| **Total**                                                         | **~4–6 weeks** |

---

## Hybrid path (worth considering)

Do **Path A** end-to-end. Ship it on TestFlight under GPL-3 to a small
group of users to validate the touch-feel and the scales. While that's
soaking, start Path B in parallel with the `.csd` as your specification.
When Path B sounds right, switch the App Store build to Path B and keep
the Csound version as the GPL "reference implementation" for desktop /
sideload.

This gives you a real iPad version in a week without committing to the
6-week rewrite, and ensures you don't ship Path B until it sounds at
least as good as the original.

---

## Suggested first commit (Path A)

A minimal Swift package proving the concept:

```swift
import UIKit
import CsoundObj

final class EtherSurfaceViewController: UIViewController {
    private let csound = CsoundObj()
    private let surface = TouchSurfaceView()
    private var voices: [UITouch: Int] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        view = surface
        surface.touchHandler = { [weak self] phase, touches in
            self?.handle(phase: phase, touches: touches)
        }
        let csd = Bundle.main.url(forResource: "etherpad", withExtension: "csd")!
        csound.play(csd)
    }
    // … handle(phase:touches:) as in the snippet earlier
}
```

`etherpad.csd` is *literally the same file as on Android* — copy it from
[app/src/main/res/raw/etherpad.csd](../app/src/main/res/raw/etherpad.csd)
into the iOS bundle.

If that one screen plays sound when you touch it, the entire port is just
filling in menus and polish.

---

## References

- [Csound for iOS source & examples](https://github.com/csound/csound/tree/develop/iOS)
- [Csound iOS Swift examples (Nikhil Singh)](https://github.com/nikhilsinghmus/CsoundiOS_SwiftExamples)
- [Csound for iOS — A Beginner's Guide (PDF)](https://www-users.york.ac.uk/~adh2/iOS-CsoundABeginnersGuide.pdf)
- [AudioKit](https://github.com/AudioKit/AudioKit)
- [AudioKit Synth One (open-source reference app)](https://github.com/AudioKit/AudioKitSynthOne)
- [AudioKit homepage](https://www.audiokit.io/)
- [Apple — Audio Session Programming Guide](https://developer.apple.com/library/archive/documentation/Audio/Conceptual/AudioSessionProgrammingGuide/Introduction/Introduction.html)
- [Apple — AUv3 / AUAudioUnit](https://developer.apple.com/documentation/audiotoolbox/auaudiounit)
