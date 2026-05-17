import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "net.gympass.gympass"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
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
