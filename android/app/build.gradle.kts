import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

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

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Play Store'a yuklendikten sonra ASLA degistirilemez; magaza adresinde
        // de gorunur. Marka ve domainle (walletmark.com.tr) tutarli tutuluyor.
        applicationId = "com.walletmark.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_secure_storage en az API 23 istiyor; flutter.minSdkVersion
        // (Flutter 3.47.4 itibariyla 24) bunu zaten karsiliyor. Onceden 23'e
        // elle sabitlenmisti (API 23-24 arasi, Android 6.0, cihazlari da
        // kapsasin diye) ama Flutter'in kendi goc araci bu satiri HER
        // `flutter build`'de flutter.minSdkVersion'a geri ceviriyor — kalici
        // bir bakim yuku olmadan kazanilamayan bir mucadele. 2026'da Android
        // 6.0 payi ihmal edilebilir duzeyde; Flutter'in kendi onerdigi
        // tabani takip etmek tercih edildi.
        minSdk = flutter.minSdkVersion
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

kotlin {
    // AGP 9 / KGP 2.4: android { kotlinOptions {} } kaldirildi, yerine
    // Kotlin eklentisinin kendi ust seviye compilerOptions DSL'i geldi.
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}
