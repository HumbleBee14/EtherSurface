package com.humblebee.etherpad.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.humblebee.etherpad.engine.Synth
import com.humblebee.etherpad.synth.Presets

/**
 * Top action bar. Each parameter button (Octave / Scale / Key / Size / Sound)
 * is wrapped in its own [Box] so a [ChoiceDropdown] can anchor directly
 * beneath the button.
 */
@Composable
internal fun TopMenuBar(synth: Synth, touchState: TouchState, onAboutClick: () -> Unit) {
    var sizeIdx   by remember { mutableIntStateOf(Presets.DefaultSizeIdx) }
    var keyIdx    by remember { mutableIntStateOf(Presets.DefaultKeyIdx) }
    var octaveIdx by remember { mutableIntStateOf(Presets.DefaultOctaveIdx) }
    var soundIdx  by remember { mutableIntStateOf(Presets.DefaultSoundIdx) }
    var scaleIdx  by remember { mutableIntStateOf(Presets.DefaultScaleIdx) }

    var openMenu by remember { mutableStateOf<String?>(null) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(40.dp)
            .background(EtherColors.TopBar)
            .padding(horizontal = 20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        DropdownButton(
            label = "Octave",
            expanded = openMenu == "octave",
            options = Presets.OctaveLabels,
            selected = octaveIdx,
            defaultIdx = Presets.DefaultOctaveIdx,
            onOpen = { openMenu = "octave" },
            onDismiss = { openMenu = null },
            onPick = { idx ->
                octaveIdx = idx
                synth.setOctave(Presets.OctaveValues[idx])
                openMenu = null
            },
        )
        Spacer(Modifier.padding(start = 20.dp))
        DropdownButton(
            label = "Scale",
            expanded = openMenu == "scale",
            options = Presets.ScaleLabels,
            selected = scaleIdx,
            defaultIdx = Presets.DefaultScaleIdx,
            onOpen = { openMenu = "scale" },
            onDismiss = { openMenu = null },
            onPick = { idx ->
                scaleIdx = idx
                synth.setScale(Presets.ScaleSteps[idx])
                openMenu = null
            },
        )
        Spacer(Modifier.padding(start = 20.dp))
        DropdownButton(
            label = "Key",
            expanded = openMenu == "key",
            options = Presets.KeyLabels,
            selected = keyIdx,
            defaultIdx = Presets.DefaultKeyIdx,
            onOpen = { openMenu = "key" },
            onDismiss = { openMenu = null },
            onPick = { idx ->
                keyIdx = idx
                synth.setKey(idx)
                openMenu = null
            },
        )
        Spacer(Modifier.padding(start = 20.dp))
        DropdownButton(
            label = "Size",
            expanded = openMenu == "size",
            options = Presets.SizeLabels,
            selected = sizeIdx,
            defaultIdx = Presets.DefaultSizeIdx,
            onOpen = { openMenu = "size" },
            onDismiss = { openMenu = null },
            onPick = { idx ->
                sizeIdx = idx
                val n = idx + 4
                touchState.numberOfNotes.intValue = n
                synth.setSize(n)
                openMenu = null
            },
        )
        Spacer(Modifier.padding(start = 20.dp))
        DropdownButton(
            label = "Sound",
            expanded = openMenu == "sound",
            options = Presets.SoundLabels,
            selected = soundIdx,
            defaultIdx = Presets.DefaultSoundIdx,
            onOpen = { openMenu = "sound" },
            onDismiss = { openMenu = null },
            onPick = { idx ->
                soundIdx = idx
                synth.setSound(idx)
                openMenu = null
            },
        )
        Spacer(Modifier.padding(start = 20.dp))
        MenuButton("About", onClick = onAboutClick)
    }
}

/**
 * A menu-bar entry that owns its own dropdown. The [ChoiceDropdown] is
 * placed inside the same [Box] as the button so it anchors directly under
 * the label, just like the original 2014 dropdowns.
 */
@Composable
private fun DropdownButton(
    label: String,
    expanded: Boolean,
    options: Array<String>,
    selected: Int,
    defaultIdx: Int,
    onOpen: () -> Unit,
    onDismiss: () -> Unit,
    onPick: (Int) -> Unit,
) {
    Box {
        MenuButton(label, onClick = onOpen)
        ChoiceDropdown(
            expanded = expanded,
            options = options,
            selected = selected,
            defaultIdx = defaultIdx,
            onDismiss = onDismiss,
            onPick = onPick,
        )
    }
}

/** Single top-bar entry. Plain text button on the dark grey background. */
@Composable
private fun MenuButton(label: String, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(4.dp))
            .background(Color.Transparent),
        contentAlignment = Alignment.Center,
    ) {
        TextButton(onClick = onClick) {
            Text(
                text = label,
                color = EtherColors.TopBarText,
                style = MaterialTheme.typography.titleMedium,
            )
        }
    }
}
