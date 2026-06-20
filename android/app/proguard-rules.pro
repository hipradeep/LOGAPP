# Flutter local notifications rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Gson specific rules to support serialization/deserialization within flutter_local_notifications
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Prevent R8 from leaving Data object members always null
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Flutter notification listener rules
-keep class im.zoe.labs.flutter_notification_listener.** { *; }

# Keep Flutter core classes (essential for all plugins)
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
