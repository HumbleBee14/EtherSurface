package com.humblebee.etherpad.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateMap
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import com.humblebee.etherpad.engine.Synth
import com.humblebee.etherpad.synth.Presets


private const val RIPPLE_DURATION_S    = 0.8f
private const val RIPPLE_MAX_RADIUS_DP = 220f
private const val TRAIL_DURATION_S     = 1.2f

internal data class Ripple(val origin: Offset, val startNs: Long)
internal data class TrailPoint(val pos: Offset, val startNs: Long)

/**
 * State holder for the touch surface. Holds the visible per-slot finger
 * positions, the live note count, and the ephemeral animation buffers
 * (ripples, trails) shared with the renderer.
 */
internal class TouchState {
    /** Visible finger positions, indexed by slot. Compose-observable so the
     *  Canvas redraws when they change. */
    val live: SnapshotStateMap<Int, Offset> = SnapshotStateMap()
    /** Number of pitch columns currently drawn (updated by Size menu). */
    val numberOfNotes = mutableIntStateOf(Presets.SizeLabels[Presets.DefaultSizeIdx].toInt())
    /** Ripples currently animating; populated on touch-down when the Ripple
     *  effect is on. Pruned each frame in the animation loop. */
    val ripples = mutableStateListOf<Ripple>()
    /** Per-slot fading trail dots; populated on touch-down/move when the
     *  Trail effect is on. Pruned each frame. */
    val trails: SnapshotStateMap<Int, MutableList<TrailPoint>> = SnapshotStateMap()
}

/**
 * The instrument's main playing surface. Renders the slate background, the
 * pitch column glow (if enabled), the vertical pitch grid, finger trails,
 * ripples, and a translucent yellow disc under each active finger.
 *
 * Forwards every touch transition to the [Synth] so the engine spawns /
 * updates / ends notes.
 *
 * Multi-touch model: each Compose pointer id is mapped to a slot index in
 * [0, Presets.MAX_TOUCHES). Csound's instr 1 reads `touch.<slot>.x|y`
 * channels at audio rate, so per-frame UI updates push the latest value via
 * the [Synth] facade — no per-frame event scheduling needed.
 */
@Composable
internal fun TouchSurface(
    synth: Synth,
    state: TouchState,
    effects: Set<VisualEffect>,
    modifier: Modifier = Modifier,
) {
    val slots = remember { mutableMapOf<Long, Int>() }
    val density = LocalDensity.current.density

    // A clock that ticks every animation frame when ripple/trail effects
    // are active. Reading this from inside the Canvas's draw lambda forces
    // a redraw, which in turn prunes expired ripples/trail points.
    var frameClockNs by remember { mutableLongStateOf(0L) }
    val needsAnimation = VisualEffect.Ripple in effects || VisualEffect.Trail in effects
    LaunchedEffect(needsAnimation) {
        while (needsAnimation) {
            withFrameNanos { now ->
                frameClockNs = now
                pruneExpired(state, now)
            }
        }
    }

    Canvas(
        modifier = modifier
            .background(EtherColors.Background)
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        val w = size.width.toFloat()
                        val h = size.height.toFloat()

                        for (change in event.changes) {
                            val id = change.id.value
                            val wasDown = id in slots
                            val isDown = change.pressed
                            val x = (change.position.x / w).coerceIn(0f, 1f).toDouble()
                            val y = (1f - change.position.y / h).coerceIn(0f, 1f).toDouble()
                            val now = System.nanoTime()

                            if (!wasDown && isDown) {
                                // touch-down: allocate the lowest free slot
                                val slot = (0 until Presets.MAX_TOUCHES).firstOrNull { s ->
                                    slots.values.none { it == s }
                                }
                                if (slot != null) {
                                    slots[id] = slot
                                    synth.touchDown(slot, x, y)
                                    state.live[slot] = change.position
                                    if (VisualEffect.Ripple in effects) {
                                        state.ripples.add(Ripple(change.position, now))
                                    }
                                    if (VisualEffect.Trail in effects) {
                                        state.trails[slot] = mutableListOf(TrailPoint(change.position, now))
                                    }
                                }
                            } else if (wasDown && isDown) {
                                // touch-move: same slot, new position
                                val slot = slots[id]!!
                                synth.touchMove(slot, x, y)
                                state.live[slot] = change.position
                                if (VisualEffect.Trail in effects) {
                                    val list = state.trails.getOrPut(slot) { mutableListOf() }
                                    list.add(TrailPoint(change.position, now))
                                }
                            } else if (wasDown && !isDown) {
                                // touch-up: free the slot. Keep its trail
                                // alive so it fades out gracefully.
                                val slot = slots.remove(id)!!
                                synth.touchUp(slot)
                                state.live.remove(slot)
                            }
                            change.consume()
                        }
                    }
                }
            },
    ) {
        // Force a recomposition tick when any animation is running so this
        // draw block re-runs every frame.
        val tickRef = frameClockNs

        // ── Column glow ────────────────────────────────────────────────
        // Soft highlight under the pitch column each active finger occupies.
        // Drawn behind the grid lines so the lines remain crisp on top.
        val cols = state.numberOfNotes.intValue
        if (VisualEffect.ColumnGlow in effects && cols > 0) {
            val colW = size.width / cols.toFloat()
            state.live.values.forEach { p ->
                val idx = (p.x / colW).toInt().coerceIn(0, cols - 1)
                drawRect(
                    color = EtherColors.FingerCircle.copy(alpha = 0.10f),
                    topLeft = Offset(idx * colW, 0f),
                    size = Size(colW, size.height),
                )
            }
        }

        // ── Pitch grid lines ───────────────────────────────────────────
        if (cols > 1) {
            val step = size.width / cols.toFloat()
            for (i in 1 until cols) {
                drawLine(
                    color = EtherColors.Grid,
                    start = Offset(i * step, 0f),
                    end = Offset(i * step, size.height),
                    strokeWidth = 6f,
                )
            }
        }

        // ── Trails ─────────────────────────────────────────────────────
        // Fading yellow dots traced behind each finger's recent path.
        if (VisualEffect.Trail in effects) {
            val nowNs = System.nanoTime()
            state.trails.values.forEach { points ->
                points.forEach { tp ->
                    val ageS = (nowNs - tp.startNs) / 1_000_000_000f
                    val alpha = (1f - ageS / TRAIL_DURATION_S).coerceIn(0f, 1f) * 0.35f
                    if (alpha > 0f) {
                        drawCircle(
                            color = EtherColors.FingerCircle.copy(alpha = alpha),
                            radius = 18f * density,
                            center = tp.pos,
                        )
                    }
                }
            }
        }

        // ── Ripples ────────────────────────────────────────────────────
        // Expanding ring centred on each touch-down event.
        if (VisualEffect.Ripple in effects) {
            val nowNs = System.nanoTime()
            state.ripples.forEach { r ->
                val ageS = (nowNs - r.startNs) / 1_000_000_000f
                val progress = (ageS / RIPPLE_DURATION_S).coerceIn(0f, 1f)
                val radius = RIPPLE_MAX_RADIUS_DP * density * progress
                val alpha = (1f - progress) * 0.6f
                if (alpha > 0f) {
                    drawCircle(
                        color = EtherColors.FingerCircle.copy(alpha = alpha),
                        radius = radius,
                        center = r.origin,
                        style = Stroke(width = 2f * density),
                    )
                }
            }
        }

        // ── Touch circles ──────────────────────────────────────────────
        // Translucent yellow disc under each active finger.  Radius scales
        // with Y position when the Intensity effect is on (low → smaller,
        // high → larger).
        state.live.forEach { (_, p) ->
            val scale = if (VisualEffect.Intensity in effects) {
                val yNorm = (1f - p.y / size.height).coerceIn(0f, 1f)
                0.5f + yNorm * 0.7f
            } else {
                1f
            }
            drawCircle(
                color = EtherColors.FingerCircle,
                radius = 60f * density * scale,
                center = p,
            )
        }
    }
}

private fun pruneExpired(state: TouchState, nowNs: Long) {
    state.ripples.removeAll {
        (nowNs - it.startNs) / 1_000_000_000f > RIPPLE_DURATION_S
    }
    // Trim trail points whose age exceeds the trail duration.
    val deadSlots = mutableListOf<Int>()
    state.trails.forEach { (slot, points) ->
        points.removeAll { (nowNs - it.startNs) / 1_000_000_000f > TRAIL_DURATION_S }
        if (points.isEmpty()) deadSlots.add(slot)
    }
    deadSlots.forEach { state.trails.remove(it) }
}
