plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
        import java.io.FileInputStream

// ---- key.properties laden (für Release-Signing) ----
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun prop(name: String): String =
    (keystoreProperties[name] as String?)?.trim()
        ?: throw GradleException("Signing-Fehler: '$name' fehlt in key.properties")
// ----------------------------------------------------

android {
    // NEU: Dein endgültiger Namespace (muss zur applicationId passen)
    namespace = "com.onikharutyunyan.converttopdf"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // NEU: Play Store-konformer Paketname
        applicationId = "com.onikharutyunyan.converttopdf"
        // AdMob benötigt minSdk 21
        minSdk = maxOf(21, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val storeFilePath = prop("storeFile")
                val f = file(storeFilePath)
                if (!f.exists()) {
                    throw GradleException("Signing-Fehler: Keystore-Datei nicht gefunden: $storeFilePath")
                }
                storeFile = f
                storePassword = prop("storePassword")
                keyAlias = prop("keyAlias")
                keyPassword = prop("keyPassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            if (signingConfigs.findByName("release") == null) {
                throw GradleException(
                    "Signing-Fehler: signingConfigs.release fehlt. " +
                            "Ist android/key.properties vorhanden und korrekt?"
                )
            }
            signingConfig = signingConfigs.getByName("release")

            // Optional: Release-Optimierungen
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
