# Building Etherpad for iOS — step by step

> Plain-English walkthrough for a clean clone of the repo to a `.app`
> running on an iPhone or iPad. Last verified end-to-end on **2026-05-22**
> with Xcode 16.5 (iPhoneOS 26.5 SDK), iPhone 17, Csound iOS 7.0.0-beta.16.

Etherpad links the **Csound for iOS** framework, which is a ~12 MB
binary blob that is **not committed to git**. Every developer who clones
the repo has to do a one-time download + Xcode-link dance. This document
is that dance.

If you skip a step you will get one of these symptoms, all of which
mean "the framework integration is wrong":

- Build succeeds, app launches, touches show yellow circles, **no sound,
  no errors** — the stub `CsoundObj.h/.m` are still being used (Step 4
  not done).
- Build fails: `Undefined symbol: _vDSP_*` — Accelerate framework not
  linked (Step 7).
- Build fails: `'CsoundMIDI.h' file not found` — only `CsoundObj.h/.m`
  copied, not `CsoundMIDI.h/.m` (Step 4).
- App launches, crashes with `EXC_BAD_ACCESS` in `csoundGetChannelPtr` —
  you are on an older `CsoundEngine.swift` that polls for channel
  pointers; pull latest `main`.

---

## Prerequisites

| Tool                          | Version            | How                                         |
| ----------------------------- | ------------------ | ------------------------------------------- |
| **Xcode**                     | 15.0+              | Mac App Store                               |
| **macOS**                     | 13+                | required by recent Xcode                    |
| **An iPhone or iPad**         | iOS 15.0+          | physical device — simulator works too but   |
|                               |                    | not what we tested with                     |
| **Apple ID**                  | any                | free tier installs to your own device for   |
|                               |                    | 7 days at a time; paid Developer Program    |
|                               |                    | ($99/yr) lasts a year and unlocks TestFlight |
| **`git`**                     | any                | comes with Xcode                            |

You do **not** need: XcodeGen, CMake, Homebrew, the Csound source repo.

---

## Step 1 — Clone

```sh
git clone https://github.com/HumbleBee14/EtherSurface.git
cd EtherSurface/EtherSurface-iOS
```

---

## Step 2 — Download the Csound iOS framework

Open <https://github.com/csound/csound/releases> in a browser. Find the
latest release that has an iOS asset (as of writing,
**`csound-ios-7.0.0-beta.16.zip`**, ~8.5 MB). Click to download.

Unzip somewhere — the Downloads folder is fine:

```sh
cd ~/Downloads
unzip csound-ios-7.0.0-beta.16.zip
```

You should now have a folder like `csound-ios-7.0.0-beta.16/` containing:

```
CsoundiOS.xcframework        ← framework (Csound engine)
libSndfileiOS.xcframework    ← framework (audio file I/O)
Csound-iOS-ObjC-Examples/    ← Obj-C examples, contains CsoundObj wrapper source
Csound-iOS-Swift-Examples/   ← Swift examples (we don't need these)
```

> **Csound 7 vs Csound 6.** The xcframework is the Csound *C library*.
> The `CsoundObj` Objective-C wrapper that our Swift code uses is shipped
> as **source code** inside the `Csound-iOS-ObjC-Examples/` folder. Our
> repo already includes patched copies of those `.h/.m` files at
> `EtherSurface-iOS/Headers/` — don't replace them.

---

## Step 3 — Copy the frameworks into the project

From the unzipped folder, copy both `.xcframework`s into the
`EtherSurface-iOS/` folder of the repo. From Finder, or:

```sh
cp -R ~/Downloads/csound-ios-7.0.0-beta.16/CsoundiOS.xcframework \
      ~/Documents/GitHub/EtherSurface/EtherSurface-iOS/
cp -R ~/Downloads/csound-ios-7.0.0-beta.16/libSndfileiOS.xcframework \
      ~/Documents/GitHub/EtherSurface/EtherSurface-iOS/
```

Both folders are gitignored so git will not track them.

---

## Step 4 — Confirm the CsoundObj source is in place

The repo *does* track the Objective-C wrapper sources at
`EtherSurface-iOS/Headers/` because they are tiny and patched for
Csound 7. After cloning, you should already have:

```
EtherSurface-iOS/Headers/
  CsoundObj.h      ← patched: removed csoundGetOutputBufferSize forward decl
  CsoundObj.m      ← patched: uses csoundGetKsmps + .playback fix
  CsoundMIDI.h     ← unchanged, required #import target
  CsoundMIDI.m     ← unchanged
```

Do not replace these with the ones from the Csound release zip — they
will not compile against Csound 7. If you accidentally did, the fix is
`git checkout EtherSurface-iOS/Headers/`.

---

## Step 5 — Open the project in Xcode

```sh
open EtherSurface-iOS/Etherpad.xcodeproj
```

---

## Step 6 — Tell Xcode about the two frameworks

In Xcode:

1. In the left sidebar, drag both `CsoundiOS.xcframework` and
   `libSndfileiOS.xcframework` from a Finder window onto the blue
   **Etherpad** project icon at the top of the sidebar.
2. In the dialog: **uncheck "Copy items if needed"** (files are
   already in the right place), keep **Etherpad target** checked,
   click **Finish**.
3. Click the blue **Etherpad** project icon → **Etherpad** target →
   **General** tab.
4. Scroll down to **"Frameworks, Libraries, and Embedded Content"**
   (called **"Embedded Content"** on newer Xcode versions).
5. If either framework is missing from the list, click the **`+`** under
   the list and add it.
6. For both frameworks the right column dropdown must say
   **"Embed & Sign"** — not "Do Not Embed".

**Common mistake**: ending up with the frameworks listed three or four
times in "Link Binary With Libraries" under the **Build Phases** tab.
This happens easily through drag-and-drop. Open Build Phases → Link
Binary With Libraries — there should be exactly **2 items** total.
Remove duplicates with the `–` button.

---

## Step 7 — Verify the linker flags include Accelerate

Csound's FFT library calls Apple's vDSP_* functions, which live in
`Accelerate.framework`. The repo's `project.pbxproj` already has this:

```
OTHER_LDFLAGS = "-lc++ -framework Accelerate";
```

You only need to touch this if you see linker errors like
`Undefined symbol: _vDSP_create_fftsetup`. In that case:

1. Etherpad target → **Build Settings** tab → search for
   `OTHER_LDFLAGS`.
2. Set its value to `-lc++ -framework Accelerate`.

---

## Step 8 — Configure code signing

1. Etherpad target → **Signing & Capabilities** tab.
2. Check **"Automatically manage signing"**.
3. Pick your Apple ID under **Team**.
4. If you get "Bundle identifier is taken", change **Bundle Identifier**
   from `com.humblebee.etherpad` to something unique like
   `com.<yourname>.etherpad`.

---

## Step 9 — Pick your device and run

1. Plug iPhone/iPad in via USB. Trust the computer if prompted.
2. On the device: **Settings → Privacy & Security → Developer Mode → On**
   (you may need to restart the device once).
3. In Xcode's top toolbar, click the device picker (it shows the
   simulator by default) → select your device under "iOS Device".
4. Press **⌘R**.
5. First-time only: the app will install but fail to launch with
   "Untrusted Developer". On the device,
   **Settings → General → VPN & Device Management → [your Apple ID] → Trust**.
   Then press ⌘R again.

You should see:
- App launches to a dark screen with vertical grid lines and a toolbar
  at the top showing "Scale: Default", "Key: C", "Octave: 0", "Size: 8",
  "Sound: Ether Pad", "About".
- Console (⌘⇧Y) prints **`[Etherpad] Csound channels bound: 10/10`**
  within ~1 second of launch.
- Touching the screen plays notes.

---

## Step 10 — Sanity-check the audio

1. **Silent switch off** (the orange-showing switch on the iPhone's
   side). `.playback` audio session category usually overrides this, but
   confirm anyway.
2. **Volume up** (physical buttons).
3. **Plug headphones in**, then try with the device speaker.

If the console shows `Csound channels bound: 10/10` but you hear
nothing, the issue is almost always #1 or #2 above. The engine is
correctly running.

---

## CLI builds (optional)

You can build from the command line without opening Xcode:

```sh
cd EtherSurface-iOS
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild \
    -project Etherpad.xcodeproj \
    -scheme Etherpad \
    -destination 'generic/platform=iOS' \
    -configuration Debug \
    build
```

Useful for CI. `xcodebuild` cannot deploy to a device — for that you
still need Xcode + a USB-connected phone.

---

## Console messages you can safely ignore

These appear at launch and are not problems — they're info logs from
inside Apple's own frameworks, not from our code:

```
Reading from public effective user settings.
CoreUI: CUIThemeStore: No theme registered with id=0
```

Apple has not silenced these despite years of developer feedback. They
appear in *every* iOS app and cannot be removed from app code.

---

## Troubleshooting

### Symptom: silent, no errors, yellow circles draw fine

You are running against the stub `CsoundObj`. Either Step 3 or Step 6
was skipped.
- Check `EtherSurface-iOS/CsoundiOS.xcframework/` exists on disk.
- Check Xcode → target → General → Embedded Content lists both
  frameworks with "Embed & Sign".
- Check the console — if you see `[CsoundObj STUB] ...` lines per
  touch, the real framework is not linked. Clean build folder
  (**⇧⌘K**) and rebuild.

### Symptom: crash on launch with `dyld: Library not loaded`

Frameworks are linked but not embedded.
- Xcode → target → General → Embedded Content → set both frameworks
  to **"Embed & Sign"**.

### Symptom: `EXC_BAD_ACCESS` in `csoundGetChannelPtr`

You're on an old version of `CsoundEngine.swift` that polled for
channel pointers before the engine was ready. Pull latest `main` —
the current version uses `CsoundObjListener` and waits for
`csoundObjStarted:` before binding channels.

### Symptom: linker error `Undefined symbol: _vDSP_*`

`Accelerate.framework` not linked. See Step 7.

### Symptom: linker error `Undefined symbol: _csoundGetOutputBufferSize`

You copied a fresh `CsoundObj.m` from the Csound 7 release zip on top
of our patched version. Revert with
`git checkout EtherSurface-iOS/Headers/CsoundObj.m`.

### Symptom: `'CsoundMIDI.h' file not found`

You only copied `CsoundObj.h/.m`, not `CsoundMIDI.h/.m`. Pull fresh
from the repo (they are tracked there) or copy them from
`Csound-iOS-ObjC-Examples/CsoundObj/classes/midi/` in the Csound zip.

### Symptom: build fails with "no signing certificate"

Step 8 not done.

### Symptom: app installs but "Untrusted Developer" on launch

First-time only — trust your developer profile on the device. See
Step 9.

---

## Why is this so much work?

The iOS app depends on Csound, which Apple has no ecosystem support
for. There is no Swift Package, no CocoaPod, no Homebrew formula that
gives you the binary in one command. Csound publishes the binary on
GitHub Releases but does not ship a stable Obj-C wrapper as a
framework — only as source code in their examples directory. So every
new developer has to:

1. Find the right release on GitHub
2. Download the xcframework
3. Drag it into Xcode
4. Embed-and-sign it
5. Link Accelerate manually
6. Patch the wrapper source for whatever C-API changes happened in the
   latest Csound

Two ways out long-term:

- **Migrate to AudioKit** (proper Swift Package, one-line `import
  AudioKit`, no framework dance). The cost is rewriting the synth.
  See [../docs/IOS_PORT.md](../docs/IOS_PORT.md) Path B.
- **Vendor the framework in the repo with Git LFS**. 12 MB binary in
  git history is not free but reduces cloning to one command.

For now, this doc is the workaround.
