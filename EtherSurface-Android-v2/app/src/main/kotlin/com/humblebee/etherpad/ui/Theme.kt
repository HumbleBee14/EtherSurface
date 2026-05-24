package com.humblebee.etherpad.ui

import androidx.compose.ui.graphics.Color

/**
 * EtherSurface palette. The slate background, blue grid lines and yellow
 * finger circles all originate from the 2014 Android port and are preserved
 * here so the look matches the original instrument across platforms.
 */
internal object EtherColors {
    /** Dark slate background of the touch surface. */
    val Background      = Color(0xFF3B444B)
    /** Light blue vertical grid lines that divide the surface into note columns. */
    val Grid            = Color(0xFF5072A7)
    /** Translucent yellow disc drawn under each active finger. */
    val FingerCircle    = Color(0x80E9D66B)
    /** Dark grey background of the top action bar. */
    val TopBar          = Color(0xFF545454)
    /** Top action bar label colour. */
    val TopBarText      = Color(0xFFFFFFFF)
}
