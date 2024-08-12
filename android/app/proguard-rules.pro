# Add project-specific ProGuard rules here.
# By default, the flags in this file are appended to flags specified
# in /etc/proguard/proguard-android.txt
# You can edit this file to enable ProGuard to remove unused code and resources.

# For more details, see http://developer.android.com/guide/developing/tools/proguard.html

# Flutter's ProGuard rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.** { *; }
