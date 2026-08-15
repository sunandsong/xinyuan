plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.xinyuan.xinyuan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.xinyuan.xinyuan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // 原生崩溃/ANR 采集：Dart 层的 crash_reporter 抓不到进程级崩溃（SIGSEGV、OOM 被杀），
    // 只能靠这类装信号处理器的 native 库把现场写盘，下次启动再捞出来上报。
    // ⚠️ xCrash 官方只声明支持到 API 30、且 2025-06 后没再更新，本项目 targetSdk 更高——
    // 目前实测可用，将来 Android 大版本升级后要重新验证，失效了就把这块摘掉（Dart 层照常工作）。
    implementation("com.iqiyi.xcrash:xcrash-android-lib:3.0.0")
}
