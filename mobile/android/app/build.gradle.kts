import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Read Google service keys out of `android/local.properties` so they
// stay out of source control. Falls back to a harmless empty value
// when the file is missing or the key isn't set yet.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) {
        FileInputStream(file).use { load(it) }
    }
}
val googleOAuthAndroidClientId: String =
    localProperties.getProperty("googleOAuthAndroidClientId") ?: ""

android {
    namespace = "net.gympass.gympass"
    // compileSdk = 36, targetSdk = 35.
    //
    // - compileSdk = 36 because the androidx baseline that ships
    //   with our current plugin set (androidx.core 1.18, activity
    //   1.12, browser 1.9, navigationevent 1.0) refuses to link
    //   against anything below API 36.
    // - targetSdk = 35 because Google Play's 2025 policy requires
    //   "API 35 or higher" and we don't yet want to opt the runtime
    //   in to Android 16 behaviours we haven't audited.
    //
    // Bump targetSdk together with compileSdk only after walking
    // Android 16's "behaviour changes that affect targeting apps"
    // page.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "net.gympass.gympass"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Surface the Google Sign-In OAuth client id to the manifest so
        // the google_sign_in plugin can read it at runtime without the
        // value landing in git. AndroidManifest.xml uses the `${...}`
        // placeholder; the value comes from local.properties.
        manifestPlaceholders["googleOAuthAndroidClientId"] =
            googleOAuthAndroidClientId
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // R8 / ProGuard. `isMinifyEnabled` enables code-shrink +
            // obfuscation; `isShrinkResources` removes unused
            // res/*.png + strings. Both halve the APK on a Flutter
            // release build *and* make reverse-engineering require
            // more effort than a stack trace from a leaked log.
            // The `proguard-rules.pro` file holds the explicit
            // `-keep` rules that prevent shrink from gutting Dio,
            // Riverpod, json_serializable + the few reflective
            // libs we use.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
