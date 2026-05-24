package com.humblebee.etherpad.synth

/**
 * Static data describing the user-facing options for each parameter (size,
 * key, octave, sound, scale) along with the engine values the labels map to.
 *
 * Everything here is pure data — no Compose, no JNI. The UI consumes
 * `*Labels` arrays for display, the [Synth] class consumes the value arrays
 * when formatting score messages.
 */
internal object Presets {

    /** Number of simultaneous touches the engine supports. Matches the .csd's
     *  `touch.<0..9>.x|y` channel definitions. */
    const val MAX_TOUCHES = 10

    /** Note divisions across the surface — engine value = index + 4 (range 4..14). */
    val SizeLabels = arrayOf("4","5","6","7","8","9","10","11","12","13","14")
    /** Default size 8 → index = 8 - 4 = 4. */
    const val DefaultSizeIdx = 4

    /** Twelve chromatic roots, index = engine value (0..11). */
    val KeyLabels = arrayOf("C","C#","D","D#","E","F","F#","G","G#","A","A#","B")
    const val DefaultKeyIdx = 0

    /** Octave display labels (high → low). */
    val OctaveLabels = arrayOf("2","1","0","-1","-2")
    /** Engine octave values matching the labels in the same order. */
    val OctaveValues = intArrayOf(6, 5, 4, 3, 2)
    /** Default octave "0" → engine value 4 → index 2. */
    const val DefaultOctaveIdx = 2

    /** Sound mode names. Indices 0..2 are the original 2014 modes; 3 and 4
     *  are the extra branches ported from the iOS .csd. */
    val SoundLabels = arrayOf(
        "Ether Pad", "Distorted Dreams", "Xanpalamin", "Give It a Tri", "Digital Monk",
    )
    const val DefaultSoundIdx = 0

    /** Scale names shown in the picker. Order is important — it matches the
     *  index used to look up step tables in [ScaleSteps]. */
    val ScaleLabels = arrayOf(
        "Default", "Major", "Minor", "Pentatonic", "Flamenco",
        "Blues", "Chromatic", "Whole-Tone", "Octatonic", "Bohlen-Pierce",
    )
    const val DefaultScaleIdx = 0

    /**
     * 14-step interval tables for each scale, indexed by [ScaleLabels] order.
     *
     * The Bohlen-Pierce entry is a sentinel: a leading `-1` tells the engine
     * to switch to the Bohlen-Pierce code path inside instr 1 rather than
     * loading a step table.
     */
    val ScaleSteps = arrayOf(
        intArrayOf( 0, 2, 4, 7, 9,11,12,14,16,19,21,24,26,28),  // Default
        intArrayOf( 0, 2, 4, 5, 7, 9,11,12,14,16,17,19,21,23),  // Major
        intArrayOf( 0, 2, 3, 5, 7, 8,11,12,14,15,17,19,20,23),  // Minor
        intArrayOf( 0, 2, 4, 7, 9,12,14,16,19,21,24,26,28,30),  // Pentatonic
        intArrayOf( 0, 1, 4, 5, 7, 8,11,12,13,16,17,19,21,22),  // Flamenco
        intArrayOf( 0, 3, 5, 6, 7,10,12,15,17,18,19,22,24,27),  // Blues
        intArrayOf( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13),  // Chromatic
        intArrayOf( 0, 2, 4, 6, 8,10,12,14,16,18,20,22,24,26),  // Whole-Tone
        intArrayOf( 0, 1, 3, 4, 6, 7, 9,10,12,13,15,16,18,19),  // Octatonic
        intArrayOf(-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),  // Bohlen-Pierce (sentinel)
    )
}
