# .csd notes (etherpad.csd)

## $INF macro

The `<CsScore>` block uses `i888 0 $INF` (and similar) on four always-on
instruments: 888 (delay loop), 999 (reverb), Mixer (final `outs` call),
3 (auto-vibrato). The original 2014 source never defined `$INF`. With
the current Csound preprocessor, the unresolved macro expands to an
empty string, so each line becomes `i888 0` — interpreted as a
default-duration event. After ~4 seconds the score ends, all
background instruments deallocate, and the Mixer stops calling `outs`.
Result: no audio output, even though `CsoundOboe::Start` reports
success and the Oboe stream is healthy.

Fix: `#define INF # 360000 #` at the top of the score (≈100 hours).

If we ever rework the score, prefer `z` (Csound's built-in "very long
time" constant) over a magic number.

## Channels the Java side writes/reads

| Channel name      | Direction | Set by                       | Read by         |
| ----------------- | --------- | ---------------------------- | --------------- |
| `touch.<0..9>.x`  | input     | `MainActivity` touch handler | instr 1 (synth) |
| `touch.<0..9>.y`  | input     | `MainActivity` touch handler | instr 1 (synth) |
| `size`            | output    | instr 100 via `chnset`       | `MultiTouchView.numberOfNotesProvider` |

Score-event instruments triggered by menu actions: 100 (size), 101 (key),
102 (octave), 103 (scale type), 104 (sound). Instr 1 is the per-touch
note instrument; instr -1 turns one off.

## Opcodes used

Standard Csound opcodes only (`oscili`, `delay`, `butlp`, `reverbsc`,
`cpsmidinn`, `chnget`, `chnset`, `tablei`, `ftgen`, `scale`, `port`,
`sprintf`, `clip`, `outs`). No plugin opcodes — so we don't need to
bundle any of the `libsignalflowgraph.so`, `libstk.so`, etc. plugins
that gogins/csound-android ships.

## Known minor issue

Light digital clicks/glitches on finger press. Not the same as the
2014 "built-in echo can't be turned off" complaint — that one is by
design (instr 888 + 999 are the global delay and reverb). The clicks
are likely from instr 1's amplitude envelope having no fade-in: the
note instance starts at full amp on touch-down, then fades on
touch-up. Adding a short `linseg` attack on the envelope would smooth
this. See instr 1 in `app/src/main/res/raw/etherpad.csd`.
