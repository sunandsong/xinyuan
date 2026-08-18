import java.util.Properties
import java.io.FileInputStream

// 上传签名配置。key.properties 和 .jks 都在 .gitignore 里，不进仓库——
// 换电脑必须自己拷过去，否则打出来的还是 debug 签名的包，商店直接拒收。
// 文件不存在时不报错、退回 debug 签名，好让 CI 和本地 `flutter run --release` 照常跑。
val keystorePropsFile = rootProject.file("key.properties")
val keystoreProps = Properties().apply {
    if (keystorePropsFile.exists()) load(FileInputStream(keystorePropsFile))
}
val hasUploadKey = keystorePropsFile.exists()

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

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
                // 用 rootProject.file：storeFile 写的是相对 android/ 的路径，
                // 直接用 file() 会按 android/app/ 解析，找不到密钥库
                storeFile = rootProject.file(keystoreProps["storeFile"] as String)
                storePassword = keystoreProps["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 有 key.properties 就用正式上传签名；没有就退回 debug，
            // 这样缺文件时是「打出来不能上架」，而不是「构建直接失败」
            signingConfig = if (hasUploadKey) signingConfigs.getByName("upload")
                            else signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // ⚠️ 这里曾接过 xCrash 抓原生崩溃，2026-08-15 摘掉了，别再加回来：
    // 它的 libxcrash.so / libxcrash_dumper.so 是 4KB 页对齐（实测 align=0x1000），
    // 而 Google Play 要求 targetSdk>=35 的应用必须支持 16KB 内存页
    // （2025-11-01 起，已延期到 2026-05-31）——上架会被拦，16KB 页真机上也加载不了。
    // 根因是它停更在 NDK r28（r28 起才默认 16KB 对齐）之前。
    // 当时用 4KB 页的模拟器测试全过，是典型的模拟器骗人案例。
    // Android 侧现在只保留 Dart 层异常 + 「异常退出」计数；iOS 侧 KSCrash 维护活跃，照常用。
}
