# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase / FCM (push notifications rely on reflection-based (de)serialization)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Gson / JSON models used by plugins that rely on reflection
-keepattributes Signature
-keepattributes *Annotation*
-keep class * implements java.io.Serializable { *; }

# Play Core (deferred components / split installs).
# The Flutter embedding references these classes for deferred-component and
# Play-Store-split support, but this app ships no deferred components and does
# not depend on play:core, so R8 sees them as missing. Suppress the warnings
# instead of pulling in the library.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.android.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
