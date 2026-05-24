package com.humblebee.etherpad.ui

import android.content.Context
import android.content.SharedPreferences

/**
 * User-selectable touch-surface visualizations. 1:1 port of the iOS
 * `VisualEffects` option set (see EtherSurface-iOS/Etherpad/Views/VisualEffects.swift).
 *
 * Stored as a bitmask in [SharedPreferences] so the choice survives app
 * restarts. Multiple effects can be active at once; passing the empty set
 * selects "None".
 */
enum class VisualEffect(val mask: Int, val label: String) {
    /** Concentric ring that expands outward from each new touch and fades. */
    Ripple(1 shl 0, "Ripple on touch"),

    /** Fading dots tracing each finger's recent path. */
    Trail(1 shl 1, "Finger trail"),

    /** Finger circle radius scales with Y position (low → small, high → large). */
    Intensity(1 shl 2, "Y-intensity ring"),

    /** Soft column highlight under each active finger's pitch column. */
    ColumnGlow(1 shl 3, "Pitch column glow");

    companion object {
        const val PREFS_NAME = "EtherpadPrefs"
        const val PREFS_KEY  = "EtherpadVisualEffects"

        /** All defined effects in the same order iOS lists them in About. */
        val all: List<VisualEffect> = entries.toList()
    }
}

/** Read the persisted set of active effects. Empty = "None". */
internal fun loadVisualEffects(ctx: Context): Set<VisualEffect> {
    val prefs = ctx.getSharedPreferences(VisualEffect.PREFS_NAME, Context.MODE_PRIVATE)
    val bits = prefs.getInt(VisualEffect.PREFS_KEY, 0)
    return VisualEffect.all.filter { (bits and it.mask) != 0 }.toSet()
}

/** Persist the set of active effects as a bitmask. */
internal fun saveVisualEffects(ctx: Context, effects: Set<VisualEffect>) {
    val bits = effects.fold(0) { acc, e -> acc or e.mask }
    ctx.getSharedPreferences(VisualEffect.PREFS_NAME, Context.MODE_PRIVATE)
        .edit()
        .putInt(VisualEffect.PREFS_KEY, bits)
        .apply()
}
