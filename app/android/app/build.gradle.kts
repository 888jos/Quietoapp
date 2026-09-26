import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Charge les infos de la clé de signature (chemin du .jks + mots de passe).
// D'abord HORS du dépôt : ~/.config/quieto/key.properties (audit du
// 02/09/2026 — les mots de passe ne vivent plus dans l'arborescence du
// projet) ; à défaut, l'ancien emplacement android/key.properties (ignoré
// par git).
val keystoreProperties = Properties()
val keystorePropertiesFile = listOf(
    File(System.getProperty("user.home"), ".config/quieto/key.properties"),
    rootProject.file("key.properties"),
).firstOrNull { it.exists() }
if (keystorePropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.quieto.quieto"
    compileSdk = flutter.compileSdkVersion
    // Version installée sur ce Mac (celle par défaut de Flutter est absente
    // → « failed to strip debug symbols » au build release).
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requis par flutter_local_notifications (API java.time sur vieux Android)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.quieto.quieto"
        // Android 8.0 minimum : exigé par le plugin `health` (Apple Santé /
        // Health Connect). Couvre ~99 % des appareils actifs.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Utilise la clé de release (Cofonde) pour signer les builds publiés.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Requis par isCoreLibraryDesugaringEnabled (flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
