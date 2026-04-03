# ──────────────────────────────────────────────────────────────────
# ProGuard / R8 Rules — Rayon Sports (AFRICLUB)
# Production release build rules for Google Play compliance.
# ──────────────────────────────────────────────────────────────────

# ── Flutter engine ──
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.embedding.**

# ── Kotlin metadata (required for reflection-based libs) ──
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**

# ── TensorFlow Lite (BioPay face recognition) ──
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.**

# ── NFC Host Card Emulation Service ──
-keep class rw.gikundiro.app.BiopayNfcHostApduService { *; }
-keep class rw.gikundiro.app.MainActivity { *; }

# ── Supabase / GoTrue / PostgREST ──
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# ── Google ML Kit (face detection) ──
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ── OkHttp / Retrofit (network layer) ──
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }
-dontwarn okhttp3.**
-dontwarn retrofit2.**
-dontwarn okio.**

# ── Hive (local persistence) ──
-keep class com.crazecoder.openfile.** { *; }
-dontwarn com.crazecoder.openfile.**

# ── Firebase App Check ──
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── General Android rules ──
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# ── Prevent stripping of native methods ──
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── Preserve Parcelable implementations ──
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# ── Preserve Serializable implementations ──
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ── Enum preservation ──
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── Remove debug logs in release ──
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
