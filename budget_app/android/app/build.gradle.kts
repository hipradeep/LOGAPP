plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "in.logapp.budget"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "in.logapp.budget"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

gradle.projectsEvaluated {
    tasks.matching { it.name.contains("GlobalSynthetics") }.configureEach {
        doFirst {
            val buildDir = rootProject.layout.buildDirectory.get().asFile
            buildDir.listFiles()?.forEach { subDir ->
                if (subDir.isDirectory) {
                    val compileJar = File(subDir, "intermediates/compile_library_classes_jar/debug/bundleLibCompileToJarDebug/classes.jar")
                    val runtimeJar = File(subDir, "intermediates/runtime_library_classes_jar/debug/bundleLibRuntimeToJarDebug/classes.jar")
                    if (compileJar.exists() && !runtimeJar.exists()) {
                        runtimeJar.parentFile.mkdirs()
                        compileJar.copyTo(runtimeJar, overwrite = true)
                    }
                }
            }
        }
    }
}

