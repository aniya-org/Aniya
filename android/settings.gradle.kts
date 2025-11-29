pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    plugins {
        id("com.codingfeline.buildkonfig") version "0.17.1"
        id("org.jetbrains.dokka") version "2.1.0"
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.21" apply false
}

include(":app")

// Apply init script for install_plugin workaround
apply(from = "init.gradle")

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        mavenLocal()
        maven("https://jitpack.io")
        maven("https://storage.googleapis.com/download.flutter.io")
        // Artifacts consumed by the CloudStream submodule (NiceHttp, NewPipeExtractor, etc.)
        maven("https://jitpack.io/Blatzar/NiceHttp")
        maven("https://jitpack.io/teamnewpipe/NewPipeExtractor")
    }

    val cloudstreamCatalog = file("../ref/DartotsuExtensionBridge/deps/cloudstream/gradle/libs.versions.toml")
    if (cloudstreamCatalog.exists()) {
        versionCatalogs {
            create("libs") {
                from(files(cloudstreamCatalog))
            }
        }
    }
}

val cloudstreamModuleDir = file("../ref/DartotsuExtensionBridge/deps/cloudstream/library")
if (cloudstreamModuleDir.exists()) {
    include(":cloudstream-library")
    project(":cloudstream-library").projectDir = cloudstreamModuleDir
}
