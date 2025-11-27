# Keep jspecify annotations
-dontwarn org.jspecify.annotations.**
-keep class org.jspecify.annotations.** { *; }

# Keep JSoup
-keep class org.jsoup.** { *; }
-dontwarn org.jsoup.**

# Keep extension classes
-keep class eu.kanade.tachiyomi.** { *; }
-keep class tachiyomi.** { *; }

# Keep Aniyomi/Tachiyomi sources
-keep class eu.kanade.tachiyomi.animesource.** { *; }
-keep class eu.kanade.tachiyomi.source.** { *; }
