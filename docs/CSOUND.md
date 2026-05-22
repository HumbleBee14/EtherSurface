# Csound integration notes

## Source

Native libs and Java bindings are vendored from
[gogins/csound-android](https://github.com/gogins/csound-android) release
`v48beta2` (Nov 2024, Csound 6.19.0). There is no Maven/AAR distribution —
they ship a full app APK and we extract artifacts from it.

To refresh against a newer release:

```sh
CSOUND_RELEASE_TAG=vXX ./scripts/fetch-csound.sh
```

The script downloads `CsoundApplication-release.apk` and extracts
`libcsoundandroid.so` + `libc++_shared.so` + `libsndfile.so` + `liboboe.so`
into `app/src/main/jniLibs/<abi>/`. If `d2j-dex2jar.sh` is on PATH it also
regenerates `app/libs/csnd.jar` from the APK's `classes.dex`.

## Native dependency chain

`libcsoundandroid.so` has NEEDED entries for `libsndfile.so` (audio file I/O)
and `liboboe.so` (low-latency audio backend). All four `.so` files must be
present per ABI or the dynamic linker fails at `System.loadLibrary` with
`dlopen failed: library "libsndfile.so" not found`.

Load order in `MainActivity` static block matters: `c++_shared` → `sndfile`
→ `oboe` → `csoundandroid`. Reverse order causes the same dlopen failure.

The remaining transitive deps (`libc`, `libm`, `libdl`, `liblog`,
`libOpenSLES`, `libaaudio`, `libandroid`) are Android system libraries
always available on device.

## Java API mapping (CsoundObj is gone)

The 2014 code used `com.csounds.CsoundObj` + `CsoundValueCacheable`. Both
were removed upstream. Current API surface lives in package `csnd`:

| Old (2014)                              | New (v48beta2)                          |
| --------------------------------------- | --------------------------------------- |
| `new CsoundObj()`                       | `new CsoundOboe()`                      |
| `csoundObj.startCsound(file)`           | `CompileCsdText(str)` + `Start()` + `Play()` |
| `csoundObj.stopCsound()`                | `Stop()` + `Cleanup()`                  |
| `csoundObj.sendScore(line)`             | `InputMessage(line)`                    |
| `csoundObj.addValueCacheable(this)` +   | `CsoundCallbackWrapper` subclass +      |
| `CsoundValueCacheable` interface        | `SetMessageCallback()`                  |
| `csoundObj.getInputChannelPtr(...)`     | `SetControlChannel(name, value)` for    |
| + `CsoundMYFLTArray.SetValue()` loop    | UI-rate (~60 Hz) updates                |
| `csnd6.CsoundMYFLTArray`                | `csnd.CsoundMYFLTArray`                 |
| `csnd6.controlChannelType`              | `csnd.controlChannelType`               |

`CsoundOboe` exposes both PascalCase (`Start`, `Play`, `Stop`) and lowercase
(`start`, `play`, `stop`) variants — they're SWIG-generated. Match the
PascalCase forms; the reference `CsoundAppActivity` calls those.

Channel pointers (the old way to write at audio rate) are still available
via `csound.getCsound()` + `CsoundMYFLTArray.SetPtr(...)`. Not used here
because touch events arrive at ≤120 Hz and `SetControlChannel` is plenty.

## Audio backend selection

`CsoundOboe` automatically picks AAudio on API 27+ and falls back to
OpenSL ES otherwise. To force one:

```java
csound.setOboeApi(0); // 0 = AAudio, 1 = OpenSL ES
```

On the test device (Android 14) AAudio is selected and the log shows
`Frames per burst: 89`, which is the device's native buffer.

## CSD options

`-o dac` routes audio to Oboe (it's just the Csound default audio output
device alias). `-b512 -B2048` sets the software / hardware buffer sizes
in samples — these were tuned for 2014 phones and are conservative on
modern hardware. Reducing them would lower latency but risks underruns;
leave as-is unless we see audio glitches.
