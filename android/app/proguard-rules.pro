# JNA (used internally by vosk-android) relies on reflection/JNI to find
# classes and fields by their exact original names (e.g. com.sun.jna.Pointer#peer).
# R8 renaming/removing them causes:
#   UnsatisfiedLinkError: Can't obtain peer field ID for class com.sun.jna.Pointer
# https://github.com/java-native-access/jna/issues/987
# https://github.com/java-native-access/jna/issues/1187
-dontwarn java.awt.*
-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* {
    public *;
}

# Vosk classes are called directly from Kotlin but also cross the JNI
# boundary (native code invokes back into Recognizer/Model), so keep them
# intact too.
-keep class org.vosk.** { *; }
-keepclassmembers class org.vosk.** { *; }
