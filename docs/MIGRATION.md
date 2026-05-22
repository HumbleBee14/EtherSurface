# 2014 → 2026 migration notes

## Toolchain

| Layer       | Before (2014)                  | After (2026)                          |
| ----------- | ------------------------------ | ------------------------------------- |
| Build       | Eclipse ADT + Ant              | Gradle 8.7 + AGP 8.5 (Kotlin DSL)     |
| JDK         | 6 / 7                          | 17 or 21 (AGP 8.5 rejects 25)         |
| minSdk      | 11 (Android 3.0)               | 24 (Android 7.0)                      |
| targetSdk   | 19 (Android 4.4)               | 34 (Android 14)                       |
| Support lib | `android-support-v4.jar` blob  | None — built-ins suffice              |
| Audio       | OpenSL ES via old CsoundObj    | Oboe / AAudio via `csnd.CsoundOboe`   |

## Project layout

The Eclipse layout (`src/`, `res/`, `assets/`, `libs/` at repo root,
`AndroidManifest.xml` at root) was moved into the standard Gradle module
structure under `app/src/main/`. The `bin/`, `gen/`, `.classpath`,
`.project`, `project.properties`, `proguard-project.txt` files were
removed — they're either build outputs or Eclipse-only.

## Manifest

`package="..."` attribute moved to `namespace = "..."` in
`app/build.gradle.kts`. `android:exported` is now required on every
activity with an intent filter (Android 12+). Activity `android:name`
entries used to point at `com.zebproj.ethersurface.*` (typo for
`etherpad`) — this was probably the "won't run on Nexus 5" bug
mentioned in the original commit history. Fixed to use relative names
(`.MainActivity`).

## Resources

`values-v11/styles.xml` and `values-v14/styles.xml` were collapsed into
`values/styles.xml` because minSdk is 24. The unused `activity_main.xml`
/ `activity_about.xml` layouts were dropped (the code constructs views
programmatically). The `actionbar.xml` layout is the only one inflated.

## Code

- `MainActivity` was rewritten against `csnd.CsoundOboe` because the
  whole `CsoundObj` / `CsoundValueCacheable` API used by the original
  has been removed upstream. See [CSOUND.md](CSOUND.md) for the API map.
- `MultiTouchView` no longer relies on the deleted
  `updateValuesFromCsound()` hook. It pulls the current note count via
  a `NumberOfNotesProvider` callback on each `onDraw()`.
- `AboutActivity` unused helper method + imports removed.

## Restored Java sources

The three Java files were accidentally deleted in commit `aad34fd`
("new sounds. new scales"). They were recovered from commit `087ffc0`
and reinstated as the baseline of the modernization branch
(`45d2caf`).
