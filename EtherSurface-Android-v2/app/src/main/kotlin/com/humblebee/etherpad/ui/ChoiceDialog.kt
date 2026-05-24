package com.humblebee.etherpad.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp

/**
 * Compact dropdown picker shown directly under the tapped menu button 
 */
@Composable
internal fun ChoiceDropdown(
    expanded: Boolean,
    options: Array<String>,
    selected: Int,
    defaultIdx: Int,
    onDismiss: () -> Unit,
    onPick: (Int) -> Unit,
) {
    DropdownMenu(
        expanded = expanded,
        onDismissRequest = onDismiss,
        // Drop a few dp below the menu bar so the dropdown doesn't crowd
        // the button it's anchored to.
        offset = DpOffset(x = 0.dp, y = 8.dp),
        shape = RoundedCornerShape(10.dp),
        // Lift the surface a few shades above the slate background so it
        // reads as a floating menu instead of a black hole.
        containerColor = Color(0xFF4A555E),
        // Cap the menu height so longer lists (Scale, Sound) stay scrollable
        // and never run flush against the bottom of the screen.
        modifier = Modifier
            .widthIn(min = 140.dp)
            .heightIn(max = 320.dp),
    ) {
        options.forEachIndexed { idx, label ->
            DropdownMenuItem(
                text = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Glyph(
                            text = when {
                                idx == selected -> "✓"
                                idx == defaultIdx -> "•"
                                else -> ""
                            },
                        )
                        Spacer(Modifier.width(8.dp))
                        Text(label, style = MaterialTheme.typography.bodyMedium)
                    }
                },
                onClick = { onPick(idx) },
                contentPadding = androidx.compose.foundation.layout.PaddingValues(
                    horizontal = 12.dp, vertical = 4.dp,
                ),
            )
        }
    }
}

@Composable
private fun Glyph(text: String) {
    Box(modifier = Modifier.size(width = 16.dp, height = 20.dp), contentAlignment = Alignment.Center) {
        if (text.isNotEmpty()) {
            Text(text, style = MaterialTheme.typography.bodyMedium)
        }
    }
}
