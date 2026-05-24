package com.humblebee.etherpad

/**
 * Kotlin facade for the C++ native engine.
 *
 * All Csound + audio work happens on the C++ side. This Kotlin object is just
 * a typed JNI wrapper — every method is one external call.
 *
 * Lifecycle:
 *   1. load(csdText)  → creates Csound, compiles the .csd, calls csoundStart
 *   2. start()        → opens the Oboe AudioStream and begins rendering
 *   3. setControlChannel / inputMessage … (sparse UI events)
 *   4. stop()         → closes the Oboe stream. Csound itself is NOT destroyed
 *                       (see engine.cpp class doc for the reason).
 *
 * Notes on threading:
 *   - setControlChannel and inputMessage may be called from any thread; Csound's
 *     channel/event ring buffers are thread-safe.
 *   - The audio thread is owned by Oboe and never re-enters Kotlin.
 */
object EtherEngine {
    init { System.loadLibrary("ether_engine") }

    external fun nativeLoad(csdText: String): Boolean
    external fun nativeStart(): Boolean
    external fun nativeStop()
    external fun nativeSetControlChannel(name: String, value: Double)
    external fun nativeInputMessage(score: String)
    external fun nativeGetControlChannel(name: String): Double
}
