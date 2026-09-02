import java.io.FileInputStream
import java.util.Properties

// Yukleme anahtari bilgileri depoya GIRMEZ; android/key.properties dosyasindan
// okunur ve o dosya .gitignore'da. Dosya yoksa (temiz klon, CI) surum derlemesi
// hata vermek yerine debug anahtariyla imzalanir — boylece anahtari olmayan biri
// de projeyi derleyebilir, sadece magazaya yukleyemez.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasUploadKey = keystorePropertiesFile.exists()
if (hasUploadKey) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.walletmark.app"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Play Store'a yuklendikten sonra ASLA degistirilemez; magaza adresinde
        // de gorunur. Marka ve domainle (walletmark.com.tr) tutarli tutuluyor.
        applicationId = "com.walletmark.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage en az API 23 istiyor. Oturum token'larini
        // Keystore destekli sifreli depoda tutabilmek icin Android 5.x (API 21-22)
        // destegi birakildi; API 23 (Android 6.0, 2015) ve ustu desteklenir.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Play App Signing kullaniliyor: buradaki anahtar YUKLEME anahtari,
            // magazadaki gercek imzalama anahtari Google'da duruyor.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
