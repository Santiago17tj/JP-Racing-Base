# Flutter & Dart
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Supabase / Ktor / OkHttp
-keep class io.github.jan.supabase.** { *; }
-keep class io.ktor.**              { *; }
-dontwarn io.ktor.**
-keep class okhttp3.**              { *; }
-dontwarn okhttp3.**
-keep class okio.**                 { *; }

# SQLite (sqflite)
-keep class com.tekartik.sqflite.** { *; }

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# JSON serialization — evitar que R8 elimine campos de modelos de datos
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class * implements java.io.Serializable { *; }

# PDF / Printing
-keep class com.example.printing.** { *; }
-dontwarn com.example.printing.**
