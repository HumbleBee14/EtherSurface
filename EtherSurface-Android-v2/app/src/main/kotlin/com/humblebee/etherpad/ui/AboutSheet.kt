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
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.humblebee.etherpad.R

@Composable
internal fun AboutSheet(
    initialEffects: Set<VisualEffect>,
    onDismiss: () -> Unit,
    onEffectsChanged: (Set<VisualEffect>) -> Unit,
) {
    val ctx = LocalContext.current
    var effects by remember { mutableStateOf(initialEffects) }
    var visualsEnabled by remember { mutableStateOf(initialEffects.isNotEmpty()) }

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
                .heightIn(max = 520.dp)
                .padding(16.dp),
        ) {
            Box {
                Column(
                    modifier = Modifier
                        .verticalScroll(rememberScrollState())
                        .padding(vertical = 20.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        "Etherpad",
                        color = textCol,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )

                    Text(
                        "A multi-touch synth for Android",
                        color = textCol,
                        fontSize = 13.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )

                    Spacer(Modifier.height(8.dp))

                    SectionHeaderWithToggle(
                        title = "Visualizations",
                        checked = visualsEnabled,
                        textColor = textCol,
                        onCheckedChange = { on ->
                            visualsEnabled = on
                            val next: Set<VisualEffect> = if (on) {
                                if (effects.isEmpty()) setOf(VisualEffect.Ripple) else effects
                            } else {
                                emptySet()
                            }
                            effects = next
                            saveVisualEffects(ctx, next)
                            onEffectsChanged(next)
                        },
                    )

                    if (visualsEnabled) {
                        VisualEffectGrid(
                            selected = effects,
                            textColor = textCol,
                            selectedBg = linkCol,
                            selectedFg = bg,
                            onToggle = { effect ->
                                val next = if (effect in effects) effects - effect else effects + effect
                                effects = next
                                saveVisualEffects(ctx, next)
                                onEffectsChanged(next)
                            },
                        )
                    }

                    Spacer(Modifier.height(12.dp))

                    val devText = buildAnnotatedString {
                        withStyle(SpanStyle(color = textCol)) { append("Developer: Dinesh (") }
                        withStyle(SpanStyle(color = linkCol)) { append("dineshy.com") }
                        withStyle(SpanStyle(color = textCol)) { append(")") }
                    }
                    Text(
                        text = devText,
                        fontSize = 14.sp,
                        modifier = Modifier
                            .padding(horizontal = 16.dp)
                            .clickable {
                                ctx.startActivity(
                                    Intent(Intent.ACTION_VIEW, Uri.parse("https://dineshy.com")),
                                )
                            },
                    )

                    Text(
                        "Credits: Inspired by the original EtherSurface by Paul Batchelor.",
                        color = subtle,
                        fontSize = 13.sp,
                        fontStyle = FontStyle.Italic,
                        modifier = Modifier.padding(horizontal = 16.dp),
                    )

                    Spacer(Modifier.height(8.dp))

                    Image(
                        painter = painterResource(id = R.drawable.logo_shadow),
                        contentDescription = null,
                        modifier = Modifier
                            .align(Alignment.CenterHorizontally)
                            .size(72.dp),
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

@Composable
private fun SectionHeaderWithToggle(
    title: String,
    checked: Boolean,
    textColor: Color,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Text(
            title,
            color = textColor,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = textColor,
            ),
        )
    }
}

@Composable
private fun VisualEffectGrid(
    selected: Set<VisualEffect>,
    textColor: Color,
    selectedBg: Color,
    selectedFg: Color,
    onToggle: (VisualEffect) -> Unit,
) {
    val rows = VisualEffect.all.chunked(2)
    Column(
        modifier = Modifier.padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                row.forEach { effect ->
                    Chip(
                        label = effect.label,
                        isOn = effect in selected,
                        textColor = textColor,
                        selectedBg = selectedBg,
                        selectedFg = selectedFg,
                        modifier = Modifier.weight(1f),
                    ) { onToggle(effect) }
                }
            }
        }
    }
}

@Composable
private fun Chip(
    label: String,
    isOn: Boolean,
    textColor: Color,
    selectedBg: Color,
    selectedFg: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    val bg = if (isOn) selectedBg else Color.White.copy(alpha = 0.06f)
    val fg = if (isOn) selectedFg else textColor
    Box(
        modifier = modifier
            .height(56.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(bg)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = fg,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center,
            maxLines = 2,
        )
    }
}
