# Build, install, debug

## Prerequisites

- JDK 17 or 21 (AGP 8.5 does not yet support JDK 25; if `java -version`
  prints 25, set `JAVA_HOME` to a 17/21 install for Gradle invocations).
- Android SDK with Platform 34 and Build-Tools 34.0.0 (Gradle will
  auto-install these on first run if SDK manager licenses are accepted).
- `local.properties` with `sdk.dir=/path/to/Android/sdk`, or
  `ANDROID_HOME` env var.

NDK is not required — we ship prebuilt `.so` files. See
[CSOUND.md](CSOUND.md).

## Build

```sh
./gradlew assembleDebug
```

Output: per-ABI split APKs under `app/build/outputs/apk/debug/`,
roughly 27 MB (armeabi-v7a) to 37 MB (arm64-v8a) each. The build does
not produce a universal APK — splits are enabled in
`app/build.gradle.kts` because the Csound runtime adds ~20 MB per
ABI and shipping all three to every device is wasteful.

## Install + run on a connected device

```sh
adb install -r app/build/outputs/apk/debug/app-arm64-v8a-debug.apk
adb shell am start -n com.zebproj.etherpad/.MainActivity
```

(Pick `app-armeabi-v7a-debug.apk` for older 32-bit ARM devices or
`app-x86_64-debug.apk` for emulators.)

## Debug Csound at runtime

`MainActivity` installs a `CsoundCallbackWrapper` that pipes Csound's
stdout/stderr to logcat under tag `EtherPad`. To stream it:

```sh
~/Library/Android/sdk/platform-tools/adb logcat -c
~/Library/Android/sdk/platform-tools/adb logcat -s EtherPad AndroidRuntime
```

Useful things to look for:

- `CompileCsdText failed: <n>` — `.csd` syntax/opcode error.
- `Start failed: <n>` — Csound engine refused to start (rare).
- `dlopen failed: library "...so" not found` — a transitive native dep
  is missing from jniLibs.
- `Score finished` followed by `resetting Csound instance` — score ran
  to completion (i.e. background instruments ended). Almost always
  means a missing duration macro like the historical `$INF` bug.

`SetMessageLevel(7)` enables notes-amps + out-of-range + warnings.
Lower to `0` to silence per-frame chatter when not debugging.

## Targeting Google Play

The bundled Csound `.so` files are not 16-KB-page-aligned. Google Play
requires this for apps that target Android 15+ submitted on or after
2025-11-01. To ship to Play we'd need to either:

1. Wait for a gogins/csound-android release built with NDK r27+ and
   `-Wl,-z,max-page-size=16384`, or
2. Build Csound from source ourselves.

For sideloaded / personal use this warning is cosmetic — every Android
device shipping today still uses 4 KB pages.
