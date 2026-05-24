package com.humblebee.etherpad.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.humblebee.etherpad.R

/**
 * Centred About dialog. Uses a plain [Dialog] (not a bottom sheet) so the
 * card is centred over the playing surface and the whole content area is
 * vertically scrollable — important in landscape where the device is
 * short.
 *
 * Dismissed by tapping the close button, the scrim, or the back press.
 */
@Composable
internal fun AboutSheet(
    initialEffects: Set<VisualEffect>,
    onDismiss: () -> Unit,
    onEffectsChanged: (Set<VisualEffect>) -> Unit,
) {
    val ctx = LocalContext.current
    var effects by remember { mutableStateOf(initialEffects) }

    val bg       = Color(0xFF3B444B)
    val textCol  = Color(0xFF5072A7)
    val linkCol  = Color(0xFFE9D66B)
    val subtle   = Color.White.copy(alpha = 0.55f)

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Surface(
            shape = RoundedCornerShape(20.dp),
            color = bg,
            modifier = Modifier
                .widthIn(min = 360.dp, max = 520.dp)
                .heightIn(max = 460.dp)
                .padding(16.dp),
        ) {
            Box {
                Column(
                    modifier = Modifier
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 24.dp, vertical = 20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        "Etherpad",
                        color = textCol,
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                    )

                    Text(
                        "A multi-touch synth for Android",
                        color = textCol,
                        fontSize = 13.sp,
                    )

                    Spacer(Modifier.height(8.dp))

                    Text(
                        "Visualizations",
                        color = textCol,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                    )

                    VisualEffectGrid(
                        selected = effects,
                        onToggle = { effect ->
                            val next = when {
                                effect == null -> emptySet()
                                effect in effects -> effects - effect
                                else -> effects + effect
                            }
                            effects = next
                            saveVisualEffects(ctx, next)
                            onEffectsChanged(next)
                        },
                        textColor = textCol,
                    )

                    Spacer(Modifier.height(10.dp))

                    Text(
                        "Android app by Dinesh",
                        color = textCol,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                    )

                    val linkText = buildAnnotatedString {
                        withStyle(SpanStyle(color = linkCol)) { append("dineshy.com") }
                    }
                    Text(
                        text = linkText,
                        fontSize = 13.sp,
                        modifier = Modifier.clickable {
                            ctx.startActivity(
                                Intent(Intent.ACTION_VIEW, Uri.parse("https://dineshy.com")),
                            )
                        },
                    )

                    Text(
                        "Inspired by the original EtherSurface by Paul Batchelor.",
                        color = subtle,
                        fontSize = 11.sp,
                        fontStyle = FontStyle.Italic,
                    )

                    Image(
                        painter = painterResource(id = R.drawable.logo_shadow),
                        contentDescription = null,
                        modifier = Modifier.size(72.dp),
                    )
                }

                IconButton(
                    onClick = onDismiss,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .padding(4.dp),
                ) {
                    Icon(Icons.Filled.Close, contentDescription = "Close", tint = textCol)
                }
            }
        }
    }
}

/**
 * 3-column chip grid: "None" + 4 effect chips. "None" clears every effect;
 * each effect chip toggles its membership. The on/off state is shown by a
 * leading ☑ or ☐ glyph.
 */
@Composable
private fun VisualEffectGrid(
    selected: Set<VisualEffect>,
    onToggle: (VisualEffect?) -> Unit,
    textColor: Color,
) {
    val items: List<Pair<String, VisualEffect?>> =
        listOf("None" to null) + VisualEffect.all.map { it.label to it }

    val chunks = items.chunked(3)

    Column(
        verticalArrangement = Arrangement.spacedBy(6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        chunks.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                row.forEach { (label, effect) ->
                    val isOn = if (effect == null) selected.isEmpty() else effect in selected
                    Chip(label = label, isOn = isOn, textColor = textColor) { onToggle(effect) }
                }
            }
        }
    }
}

@Composable
private fun Chip(label: String, isOn: Boolean, textColor: Color, onClick: () -> Unit) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(Color.White.copy(alpha = 0.06f))
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
    ) {
        Text(if (isOn) "☑ " else "☐ ", color = textColor, fontSize = 16.sp)
        Text(label, color = textColor, fontSize = 12.sp)
    }
}
