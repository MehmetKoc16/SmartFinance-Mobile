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
        // minSdk 23'e (Android 6.0) geri dondurme denendi (14.09.2026): Flutter'in
        // kendi "eski minSdk" temizleyicisini atlatmak (degiskene atayarak) kolaydi,
        // ama local_auth_android, flutter_plugin_android_lifecycle ve
        // shared_preferences_android ZATEN kendi AndroidManifest'lerinde minSdk 24
        // talep ediyor — bunlar bagimsiz eklentiler degil, neredeyse her Flutter
        // uygulamasinin temelinde olan paketler. Her birini yillar eski bir surume
        // sabitlemek gerekiyordu, bu da AGP 9/Kotlin 2.4 toolchain'iyle uyumsuzluk
        // riski tasiyordu ve zincir daha da derine inebilirdi (baska paketler de
        // cikabilirdi). Play Console'un "1.009 cihaz" uyarisina ragmen 24'te
        // kalmak, bu genis capli ve kirilgan bagimlilik sabitleme ugrasindan
        // daha guvenli bulundu.
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
