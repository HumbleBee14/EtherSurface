# Csound SWIG-generated bindings rely on reflection between Java and JNI.
# Keep the entire csnd.* surface so native calls can resolve at runtime.
-keep class csnd.** { *; }
-keepclassmembers class csnd.** { *; }
