# iPad Split-Screen Dual-Synth Implementation

## Summary

Implemented a complete split-screen dual-synth feature for iPad that enables musicians to play two independent Csound synthesizers side-by-side with full independent controls (Scale, Key, Octave, Size, Sound). The feature is **iPad-only** and is **disabled by default**. iPhone users see no changes.

## Architecture

### New Files Created

1. **SplitModeController.swift**
   - Singleton-pattern UserDefaults manager for split mode on/off state
   - Posts `SplitModeController.didChangeNotification` when toggled
   - Default: `false` (split mode OFF on first launch)
   - Only returns true on iPad; always false on iPhone

2. **SynthPanelViewController.swift**
   - Reusable view controller for one synth: CsoundEngine + TouchSurfaceView + toolbar
   - Owns five toolbar buttons (Scale, Key, Octave, Size, Sound) with dropdown menus
   - Maintains independent parameter state (selected scale, key, octave, size, sound)
   - Conforms to `TouchSurfaceDelegate` and routes touch events to its own engine
   - Configures audio session cleanup (will be called twice on split mode, once on single mode)
   - Used once in `SceneDelegate` (iPhone or iPad split-mode OFF) and twice in `SplitSynthViewController` (split-mode ON)

3. **SplitSynthViewController.swift**
   - iPad-only root container for split layout
   - Manages two `SynthPanelViewController` instances (left/right) with 50/50 horizontal split
   - Adds a vertical divider line between the two panels
   - Configures AVAudioSession once for both engines
   - Listens to `SplitModeController.didChangeNotification` and dynamically transitions:
     - Split mode ON → two panels side-by-side
     - Split mode OFF → single panel full-screen
   - Uses child view controller containment pattern

### Modified Files

1. **SceneDelegate.swift**
   - Routing decision: iPad → `SplitSynthViewController()`, iPhone → `EtherpadViewController()`
   - Audio session is now configured in `SplitSynthViewController` for iPad
   - No change to iPhone entry point

2. **EtherpadViewController.swift**
   - Added guard to only configure audio session if running on iPhone
   - All other functionality unchanged (iPhone still uses this VC as root)

3. **AboutViewController.swift**
   - Added iPad-only "Split Mode" section (visible only on iPad)
   - Split Mode section includes:
     - Header label: "Split Mode"
     - UISwitch toggle
     - Status label ("Enabled" / "Disabled")
   - Toggle writes to `SplitModeController.isEnabled`
   - Section positioned after Visualizations, before Performance tip

### Layout (iPad Split Mode)

```
┌─────────────────────────────────────────────────────┐
│ [Scale|Key|Oct\Size|Sound]  │  [Scale|Key|Oct\Size|Sound] │
│                              │                       │
│  Left Surface (50%)          │  Right Surface (50%)  │
│  Independent engine          │  Independent engine   │
│  Full height                 │  Full height          │
│                              │                       │
│  Visual effects (ripples/trails) render on both surfaces
└─────────────────────────────────────────────────────┘
```

## Behavior

### iPhone
- Unchanged: single synth, full-screen, no split option visible
- Routes to `EtherpadViewController`

### iPad (Split Mode OFF, default)
- Identical to iPhone: single synth, full-screen
- Routes to `SplitSynthViewController` with single-mode layout
- About sheet shows "Split Mode" toggle (off by default)

### iPad (Split Mode ON, after user enables toggle)
- Two synths side-by-side in 50/50 horizontal split
- Each panel has independent toolbar + playing surface
- Each panel has its own Csound engine (two separate `CsoundEngine` instances)
- Touch input in left half → left engine, touch input in right half → right engine
- All five parameters (Scale, Key, Octave, Size, Sound) are independent per synth
- Visual effects (ripples, trails, column glow, intensity) are shared globally
- Info icon not yet implemented (future: could add a centered info button between toolbars)
- User can toggle split mode OFF from About sheet to collapse back to single-synth
- Both engines share one AVAudioSession, mix to stereo output

## Audio Session

- Configured once in `SplitSynthViewController.configureAudioSession()` for iPad
- Configured in `EtherpadViewController.configureAudioSession()` for iPhone (only if `userInterfaceIdiom == .phone`)
- Both use identical config: `.playback` category + `.mixWithOthers` + 5ms buffer duration + active session

## Visual Effects (Shared)

- All four effects (Ripple, Trail, Intensity, Column Glow) are globally shared
- Both `TouchSurfaceView` instances read from single `VisualEffects.current` UserDefaults key
- Both panels refresh when effects change (via `.visualEffectsChanged` notification)
- No per-panel effect settings (as per user requirement)

## Testing Checklist

### iPhone Simulator/Device
- [ ] Launch app on iPhone
- [ ] Confirm single synth, full-screen
- [ ] About sheet does NOT show "Split Mode" toggle
- [ ] All controls work independently
- [ ] Audio plays correctly

### iPad Simulator/Device (Landscape)
- [ ] Launch app on iPad
- [ ] Confirm single synth full-screen by default
- [ ] Open About sheet
- [ ] "Split Mode" toggle is visible and OFF
- [ ] Toggle Split Mode ON
- [ ] App transitions to two-panel layout
- [ ] Left panel: touch left surface, controls control left synth
- [ ] Right panel: touch right surface, controls control right synth
- [ ] Visual effects (ripples/trails) render on both surfaces simultaneously
- [ ] Divider line visible between panels
- [ ] Toggle Split Mode OFF from About
- [ ] App transitions back to single-panel full-screen layout
- [ ] Toggle back ON and OFF multiple times without crashing

### Audio Quality
- [ ] Both engines play simultaneously without dropouts
- [ ] Audio mixes cleanly to stereo output
- [ ] No audio glitches on transitions between split/single mode

## Future Enhancements

1. **Info icon (ⓘ)** — could add a centered button at top between the two toolbars
2. **Glassmorphism styling** — apply UIVisualEffectView blur to toolbar areas (user requested but not yet implemented)
3. **Per-panel visual effects** — if users want independent effect settings per synth
4. **Landscape lock on iPad** — currently allows sensor-based rotation; could lock to landscape only
5. **Save/load presets per panel** — remember selected parameters when toggling split mode

## Known Limitations

- Voice slots are still 0–9 per engine; no voice partitioning needed
- Both engines load the same `etherpad.csd` (no per-engine CSD variants)
- Audio session is a system singleton; both engines share same audio category/options
- Switching between split/single mode may cause brief audio interruption (fade-out/fade-in desirable)

## Files Modified Summary

| File | Changes |
|---|---|
| `SceneDelegate.swift` | Route iPad → `SplitSynthViewController`, iPhone → `EtherpadViewController` |
| `EtherpadViewController.swift` | Audio session config only on iPhone |
| `AboutViewController.swift` | Added iPad-only Split Mode toggle section |
| `SplitModeController.swift` | NEW — manages split mode state |
| `SynthPanelViewController.swift` | NEW — reusable synth panel (engine + surface + toolbar) |
| `SplitSynthViewController.swift` | NEW — iPad split layout container |

## Commit

Ready to commit all three new files + three modified files as a single feature commit.
