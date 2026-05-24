# ── Csound JNI bridge ────────────────────────────────────────────────────────
# Keep the entire Csound wrapper and any class that declares native methods,
# so the JNI symbol lookup (csoundCreate, etc.) never breaks at runtime.
-keep class com.humblebee.etherpad.CsoundAndroid { *; }
-keep class com.humblebee.etherpad.** { native <methods>; }

# ── App entry points ─────────────────────────────────────────────────────────
-keep class com.humblebee.etherpad.MainActivity { *; }

# ── Kotlin & coroutines ──────────────────────────────────────────────────────
-keepattributes *Annotation*, InnerClasses, Signature, EnclosingMethod
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }
-keep class kotlinx.coroutines.** { *; }

# ── Jetpack Compose ──────────────────────────────────────────────────────────
# Compose runtime uses reflection for stability inference; keep its internals.
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# ── AndroidX / Material ──────────────────────────────────────────────────────
-keep class androidx.lifecycle.** { *; }
-dontwarn androidx.lifecycle.**

# ── Oboe (native audio, no Java surface to keep) ────────────────────────────
-dontwarn com.google.oboe.**

# ── Serialization / Parcelable ───────────────────────────────────────────────
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# ── R8 / shrinking misc ──────────────────────────────────────────────────────
# Preserve line numbers in stack traces for easier crash debugging.
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile
