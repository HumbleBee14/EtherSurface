# Wiring the Real Csound iOS Framework

> **If the app is silent on device, this is almost certainly why.**

The iOS port currently ships with a **stub** `CsoundObj.h` / `CsoundObj.m`
under `Headers/` so the project compiles before the real framework is
integrated. The stub's `play()`, `sendScore()`, and `getInputChannelPtr()`
methods just `NSLog` and return — no audio engine, no sound.

You can confirm you're hitting the stub by searching the Xcode console for
`[CsoundObj STUB]`. Every touch fires one of those lines.

This document walks through replacing the stubs with the real Csound for iOS
framework.

---

## Step 1 — Get the framework

There are two reasonable sources.

### Option A — Prebuilt `CsoundObj.xcframework` (easiest)

Csound publishes prebuilt iOS binaries on the official GitHub releases page:

- <https://github.com/csound/csound/releases>

Look for an asset named something like `csound-iOS-x.y.z.zip` or
`Csound-iOS.xcframework.zip`. As of writing the most reliable build is
**Csound 6.18+** for iOS. Download and unzip; you should end up with a
`CsoundObj.xcframework` (or `csound-iOS/CsoundObj.framework`) folder.

If the official release page doesn't have a prebuilt iOS framework for the
current release, fall back to:

- <https://github.com/csound/csound/tree/develop/iOS> — clone and build with
  the included Xcode project (see Option B).

### Option B — Build from source

```sh
git clone https://github.com/csound/csound.git
cd csound/iOS
open Csound\ iOS\ Examples.xcodeproj
```

In Xcode pick the **CsoundiOS** scheme and build for "Any iOS Device
(arm64)" + "Any iOS Simulator". Then create an XCFramework from both
slices:

```sh
xcodebuild -create-xcframework \
  -framework path/to/Release-iphoneos/CsoundObj.framework \
  -framework path/to/Release-iphonesimulator/CsoundObj.framework \
  -output CsoundObj.xcframework
```

---

## Step 2 — Add the framework to the EtherSurface project

1. Open `EtherSurface-iOS/EtherSurface.xcodeproj` in Xcode.
2. **File → Add Files to "EtherSurface"…** → select `CsoundObj.xcframework`
   → check "Copy items if needed" → "Create groups" → ensure the
   **EtherSurface** target is checked.
3. Click the blue **EtherSurface** project icon → **EtherSurface** target →
   **General** tab → scroll to **Frameworks, Libraries, and Embedded
   Content**.
4. Confirm `CsoundObj.xcframework` is listed and **Embed** is set to
   **"Embed & Sign"**.

The framework should now be at the project root, embedded in the app
bundle, and signed with your development team.

---

## Step 3 — Remove the stubs

The stubs in `Headers/` are no longer needed and will *conflict* with the
real framework if both are linked.

1. In Xcode's Project Navigator, select `Headers/CsoundObj.h` and
   `Headers/CsoundObj.m`.
2. Right-click → **Delete** → choose **"Move to Trash"** (not just "Remove
   Reference"). The files must not be in the build.

If you prefer to keep the stub files on disk as documentation but exclude
them from the build, instead: select each file → File Inspector (right
panel) → uncheck the **EtherSurface** target under "Target Membership".

---

## Step 4 — Fix the bridging header import

The current bridging header imports the stub by relative path. Update it
to import from the framework instead:

`EtherSurface-iOS/EtherSurface/EtherSurface-Bridging-Header.h`:

```objc
// Before (using the stub):
// #import "CsoundObj.h"

// After (using the framework):
#import <CsoundObj/CsoundObj.h>
```

If autocomplete in Xcode does not find `<CsoundObj/CsoundObj.h>`, the
framework search paths are not set. Go to **Build Settings → Framework
Search Paths** and ensure the directory containing `CsoundObj.xcframework`
is listed (Xcode usually does this automatically when you add the
framework via File → Add Files).

---

## Step 5 — Verify the real API matches what we use

The stub declares this surface:

```objc
- (void)play:(NSString *)csdFilePath;
- (void)stop;
- (void)sendScore:(NSString *)score;
- (nullable float *)getInputChannelPtr:(NSString *)channelName;
- (nullable void *)getCsound;
```

The real `CsoundObj` has a *much* larger API but the methods above all
exist with these exact signatures in Csound iOS ≥ 6.13. If the framework
you downloaded names them differently (some forks rename
`getInputChannelPtr` → `getInputChannelPtr:channelType:`), update
`CsoundEngine.swift` accordingly — only a few lines change.

To check, ⌘-click `CsoundObj` in the bridging header (or any
`csound?.method(...)` call in `CsoundEngine.swift`) to jump to the real
header inside the framework.

---

## Step 6 — Build, run, listen

1. Plug in the iPhone, pick it as the destination.
2. ⌘R to build and run.
3. Touch the screen — you should now hear the synth.

In the Xcode console you should see Csound's own startup messages:
`Csound version 6.19 ...`, `audio_thread_loop ...`, and the per-instrument
compile logs. You should **not** see any `[CsoundObj STUB]` lines.

---

## Troubleshooting

**Still silent.** Check the console:

- `etherpad.csd not found in bundle` — open Xcode → EtherSurface target →
  **Build Phases → Copy Bundle Resources** and ensure
  `EtherSurface/Resources/etherpad.csd` is in the list.
- `Csound channels never became available` (from our retry loop in
  `CsoundEngine.start()`) — the framework is linked but `play()` failed.
  Look earlier in the console for `Csound: error:` lines. Usually a CSD
  syntax error or a missing opcode in the iOS Csound build.
- `AVAudioSession setActive failed` — another app is holding the audio
  session exclusively. Force-quit Spotify / GarageBand / any DAW and
  retry.

**Crash on launch with `dyld: Library not loaded`.** The framework isn't
embedded. Re-check Step 2: it must be **Embed & Sign**, not "Do Not
Embed".

**Sound mode 2 (Xanpalamin) is silent or makes only the "ping" sound.**
Known issue inherited from the Android version — see
[../docs/CSD.md](../docs/CSD.md). The waveshaping branch through
`gipalamin` is sensitive to the iOS Csound's `tablei` initialization
order. Workaround: switch to Ether Pad / Distorted Dreams and revisit
later.

**`.csd` errors about `chnset` inside score events.** If the Csound
version you've linked is older than 6.10, `sendScore("chnset 0.5, \"touch.0.x\"")`
won't work and the engine will print `unknown opcode`. The retry-loop
fallback in `CsoundEngine.writeChannel()` relies on it. Upgrade the
framework to 6.13+ or remove the fallback branch and accept that the very
first touch within the first ~50 ms of launch may be silent.

---

## Why this wasn't done in the initial port

The initial port was developed in a worktree without the ~30 MB
framework binary, since binary blobs don't belong in git history and
require manual download per developer. The stubs allowed iteration on
Swift code, touch handling, menus, and lifecycle without blocking on the
framework integration. That decision is now paying its bill — and this
doc is the cost.
