package com.humblebee.etherpad

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.humblebee.etherpad.engine.Synth
import com.humblebee.etherpad.ui.EtherSurfaceApp

/**
 * Single-activity entry point. Constructs the [Synth] (which loads the .csd
 * and opens the Oboe stream via JNI), then hands it to the Compose UI tree
 * for the rest of the app's lifetime.
 *
 * The activity owns the audio engine's lifecycle for now — onDestroy stops
 * the Oboe stream. Csound itself is intentionally never destroyed; see
 * `engine.cpp` for the threading-safety reason.
 */
class MainActivity : ComponentActivity() {

    private lateinit var synth: Synth

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        WindowCompat.getInsetsController(window, window.decorView).apply {
            systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            hide(WindowInsetsCompat.Type.systemBars())
        }
        synth = Synth(resources)
        setContent { EtherSurfaceApp(synth) }
    }

    override fun onDestroy() {
        super.onDestroy()
        synth.stop()
    }
}
