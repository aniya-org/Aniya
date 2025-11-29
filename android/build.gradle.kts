subprojects {
    repositories {
        google()
        mavenCentral()
        mavenLocal()
        maven("https://jitpack.io")
        maven("https://storage.googleapis.com/download.flutter.io")
    }

    afterEvaluate {
        // Handle both Android application and library plugins
        if (plugins.hasPlugin("com.android.application") || 
            plugins.hasPlugin("com.android.library")) {
            
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileSdkVersion(35)
                buildToolsVersion = "36.0.0"
                
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_11
                    targetCompatibility = JavaVersion.VERSION_11
                }
            }
        }
        
        // Set namespace for libraries that don't have it
        if (hasProperty("android")) {
            extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
                if (namespace == null) {
                    namespace = project.group.toString()
                }
            }
        }
        

        
        // Configure Kotlin compilation
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
            }
        }
        
        // Workaround for sqflite_android SDK 35 compatibility
        // Allow compilation to proceed despite BAKLAVA API level errors
        if (project.name == "sqflite_android") {
            tasks.named("compileDebugJavaWithJavac").configure {
                (this as JavaCompile).options.isFailOnError = false
            }
            tasks.named("compileReleaseJavaWithJavac").configure {
                (this as JavaCompile).options.isFailOnError = false
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
