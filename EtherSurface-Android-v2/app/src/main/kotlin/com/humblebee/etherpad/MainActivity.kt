package com.humblebee.etherpad

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateMap
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp

private const val TAG = "EtherUI"

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Kick off the audio engine. We load the .csd from res/raw and hand it
        // to the C++ engine, which compiles + starts Csound and opens Oboe.
        val csdText = resources.openRawResource(R.raw.etherpad).bufferedReader()
            .use { it.readText() }
        val loaded = EtherEngine.nativeLoad(csdText)
        val started = if (loaded) EtherEngine.nativeStart() else false
        Log.i(TAG, "engine load=$loaded start=$started")

        setContent {
            EtherSurfaceApp()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        EtherEngine.nativeStop()
    }
}

private val BgColor      = Color(0xFF3B444B) // slate background from the 2014 original
private val GridColor    = Color(0xFF5072A7) // light blue grid lines
private val CircleColor  = Color(0x80E9D66B) // translucent yellow finger circles
private val TopBarColor  = Color(0xFF545454) // dark gray top bar
private val TopBarText   = Color(0xFFFFFFFF)

@Composable
private fun EtherSurfaceApp() {
    rememberDensityCapture()
    MaterialTheme(colorScheme = darkColorScheme(background = BgColor)) {
        Surface(modifier = Modifier.fillMaxSize(), color = BgColor) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .windowInsetsPadding(WindowInsets.systemBars),
            ) {
                TopMenuBar()
                TouchSurface(modifier = Modifier.fillMaxSize())
            }
        }
    }
}

// ─── Touch surface ────────────────────────────────────────────────────────

/**
 * Multi-touch surface. Each active pointer is tracked as a `TouchSlot`. On
 * touch-down we allocate a slot (0..9), send a note-on score event, and start
 * writing the touch's (x, y) to per-slot Csound channels at every move. On
 * touch-up we send a note-off and free the slot.
 *
 * Csound's instr 1 reads `touch.<n>.x` / `touch.<n>.y` channels at audio rate,
 * so we just push the latest UI value into them — no event scheduling needed
 * for tracking finger motion.
 */
@Composable
private fun TouchSurface(modifier: Modifier = Modifier) {
    // Pointer id (from Compose) → slot index (0..9, what Csound expects).
    val slots = remember { mutableMapOf<Long, Int>() }
    // Visible finger positions, indexed by slot. Compose-observable so the
    // Canvas redraws when they change.
    val live = remember { SnapshotStateMap<Int, Offset>() }
    val viewSize = remember { mutableStateOf(Size.Zero) }

    Canvas(
        modifier = modifier
            .background(BgColor)
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        val w = size.width.toFloat()
                        val h = size.height.toFloat()
                        viewSize.value = Size(w, h)

                        for (change in event.changes) {
                            val id = change.id.value
                            // Decide what kind of transition this is for THIS
                            // pointer (Compose dispatches one PointerEvent per
                            // frame with all active pointers; we have to inspect
                            // each change individually).
                            val wasDown = id in slots
                            val isDown = change.pressed
                            val x = (change.position.x / w).coerceIn(0f, 1f)
                            val y = 1f - (change.position.y / h).coerceIn(0f, 1f)

                            if (!wasDown && isDown) {
                                // touch-down
                                val slot = (0 until 10).firstOrNull { s ->
                                    slots.values.none { it == s }
                                }
                                if (slot != null) {
                                    slots[id] = slot
                                    EtherEngine.nativeSetControlChannel(
                                        "touch.$slot.x", x.toDouble())
                                    EtherEngine.nativeSetControlChannel(
                                        "touch.$slot.y", y.toDouble())
                                    EtherEngine.nativeInputMessage(
                                        "i1.$slot 0 -2 $slot")
                                    live[slot] = change.position
                                    Log.d(TAG, "down slot=$slot x=$x y=$y")
                                }
                            } else if (wasDown && isDown) {
                                // touch-move
                                val slot = slots[id]!!
                                EtherEngine.nativeSetControlChannel(
                                    "touch.$slot.x", x.toDouble())
                                EtherEngine.nativeSetControlChannel(
                                    "touch.$slot.y", y.toDouble())
                                live[slot] = change.position
                            } else if (wasDown && !isDown) {
                                // touch-up
                                val slot = slots.remove(id)!!
                                EtherEngine.nativeInputMessage("i-1.$slot 0 0 $slot")
                                live.remove(slot)
                                Log.d(TAG, "up slot=$slot")
                            }
                            change.consume()
                        }
                    }
                }
            }
    ) {
        // Vertical grid lines dividing the surface into `gridCount` pitch
        // columns. The actual note count is published by the .csd into the
        // `size` channel; we read it here for the visual.
        val gridCount = NumberOfNotes.value
        if (gridCount > 1) {
            val step = size.width / gridCount.toFloat()
            for (i in 1 until gridCount) {
                drawLine(
                    color = GridColor,
                    start = Offset(i * step, 0f),
                    end = Offset(i * step, size.height),
                    strokeWidth = 6f,
                )
            }
        }
        // Translucent finger discs
        live.values.forEach { p ->
            drawCircle(
                color = CircleColor,
                radius = 60f * density,
                center = p,
            )
        }
    }
}

// Size-channel value, observable from the Canvas. Updated by setSize() below
// (push from UI thread — much cheaper than polling Csound from the audio
// thread, and the value only changes when the user picks a new size).
private val NumberOfNotes = androidx.compose.runtime.mutableStateOf(8)

// Density is needed to scale the finger circles. Captured at app start.
private var density: Float = 2.5f

// ─── Top menu bar + selection state ───────────────────────────────────────

/**
 * Single source of truth for the .csd parameters. Each menu mutates the
 * matching index and sends the corresponding Csound score event. Defaults
 * match the values the .csd's instr 100/101/102/103/104 set at startup.
 */
private object SelState {
    var sizeIdx   = androidx.compose.runtime.mutableStateOf(4)  // value 8 → index 8-4 = 4
    var keyIdx    = androidx.compose.runtime.mutableStateOf(0)  // C
    var octaveIdx = androidx.compose.runtime.mutableStateOf(2)  // label "0" → value 4
    var soundIdx  = androidx.compose.runtime.mutableStateOf(0)  // Ether Pad
    var scaleIdx  = androidx.compose.runtime.mutableStateOf(0)  // Default
}

private val SIZE_LABELS   = arrayOf("4","5","6","7","8","9","10","11","12","13","14")
private val KEY_LABELS    = arrayOf("C","C#","D","D#","E","F","F#","G","G#","A","A#","B")
private val OCTAVE_LABELS = arrayOf("2","1","0","-1","-2")
private val OCTAVE_VALUES = intArrayOf(6, 5, 4, 3, 2) // engine values
private val SOUND_LABELS  = arrayOf("Ether Pad","Distorted Dreams","Xanpalamin")
// The legacy 2014 .csd only defines 3 sounds. The current CSD source confirms
// gisound == 0,1,2. Adding more would require new instr-1 branches.
private val SCALE_LABELS  = arrayOf("Default","Major","Minor","Pentatonic","Flamenco",
                                    "Blues","Chromatic","Whole-Tone","Octatonic","Bohlen-Pierce")
private val SCALE_STEPS   = arrayOf(
    intArrayOf( 0, 2, 4, 7, 9,11,12,14,16,19,21,24,26,28), // Default
    intArrayOf( 0, 2, 4, 5, 7, 9,11,12,14,16,17,19,21,23), // Major
    intArrayOf( 0, 2, 3, 5, 7, 8,11,12,14,15,17,19,20,23), // Minor
    intArrayOf( 0, 2, 4, 7, 9,12,14,16,19,21,24,26,28,30), // Pentatonic
    intArrayOf( 0, 1, 4, 5, 7, 8,11,12,13,16,17,19,21,22), // Flamenco
    intArrayOf( 0, 3, 5, 6, 7,10,12,15,17,18,19,22,24,27), // Blues
    intArrayOf( 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13), // Chromatic
    intArrayOf( 0, 2, 4, 6, 8,10,12,14,16,18,20,22,24,26), // Whole-Tone
    intArrayOf( 0, 1, 3, 4, 6, 7, 9,10,12,13,15,16,18,19), // Octatonic
    intArrayOf(-1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), // Bohlen-Pierce sentinel
)

@Composable
private fun TopMenuBar() {
    var openMenu by remember { mutableStateOf<String?>(null) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(40.dp)
            .background(TopBarColor)
            .padding(horizontal = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        MenuButton("Octave") { openMenu = "octave" }
        Spacer(Modifier.padding(start = 20.dp))
        MenuButton("Scale") { openMenu = "scale" }
        Spacer(Modifier.padding(start = 20.dp))
        MenuButton("Key") { openMenu = "key" }
        Spacer(Modifier.padding(start = 20.dp))
        MenuButton("Size") { openMenu = "size" }
        Spacer(Modifier.padding(start = 20.dp))
        MenuButton("Sound") { openMenu = "sound" }
    }

    when (openMenu) {
        "octave" -> ChoiceDialog("Octave", OCTAVE_LABELS, SelState.octaveIdx.value,
            onDismiss = { openMenu = null }) { idx ->
            SelState.octaveIdx.value = idx
            EtherEngine.nativeInputMessage("i102 0 0.5 ${OCTAVE_VALUES[idx]}")
            openMenu = null
        }
        "scale" -> ChoiceDialog("Scale", SCALE_LABELS, SelState.scaleIdx.value,
            onDismiss = { openMenu = null }) { idx ->
            SelState.scaleIdx.value = idx
            val s = SCALE_STEPS[idx]
            val msg = if (s[0] == -1) "i103 0 0.5 -1"
                      else "i103 0 0.5 " + s.joinToString(" ")
            EtherEngine.nativeInputMessage(msg)
            openMenu = null
        }
        "key" -> ChoiceDialog("Key", KEY_LABELS, SelState.keyIdx.value,
            onDismiss = { openMenu = null }) { idx ->
            SelState.keyIdx.value = idx
            EtherEngine.nativeInputMessage("i101 0 0.5 $idx")
            openMenu = null
        }
        "size" -> ChoiceDialog("Size", SIZE_LABELS, SelState.sizeIdx.value,
            onDismiss = { openMenu = null }) { idx ->
            SelState.sizeIdx.value = idx
            val n = idx + 4
            NumberOfNotes.value = n
            EtherEngine.nativeInputMessage("i100 0 0.5 $n")
            openMenu = null
        }
        "sound" -> ChoiceDialog("Sound", SOUND_LABELS, SelState.soundIdx.value,
            onDismiss = { openMenu = null }) { idx ->
            SelState.soundIdx.value = idx
            EtherEngine.nativeInputMessage("i104 0 0.5 $idx")
            openMenu = null
        }
    }
}

@Composable
private fun MenuButton(label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(Color.Transparent),
        contentAlignment = Alignment.Center,
    ) {
        TextButton(onClick = onClick) {
            Text(label, color = TopBarText, style = MaterialTheme.typography.titleMedium)
        }
    }
}

/**
 * Material 3 single-choice dialog. Shows the current selection with a filled
 * radio button; tapping a different row immediately commits and dismisses.
 * This mirrors how iOS's UIMenu shows a checkmark next to the active row.
 */
@Composable
private fun ChoiceDialog(
    title: String,
    options: Array<String>,
    selected: Int,
    onDismiss: () -> Unit,
    onPick: (Int) -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column {
                options.forEachIndexed { idx, label ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                    ) {
                        RadioButton(selected = idx == selected, onClick = { onPick(idx) })
                        Text(
                            text = label,
                            modifier = Modifier
                                .padding(start = 8.dp)
                                .fillMaxWidth(),
                        )
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Close") } },
    )
}

// Density helper — read once at composition time so the Canvas can scale dp
// values into pixels. Doing it inside the Canvas would need a DrawScope
// extension; capturing at start is simpler for this single use.
@Composable
private fun rememberDensityCapture() {
    val d = androidx.compose.ui.platform.LocalDensity.current.density
    LaunchedEffect(d) { density = d }
}
