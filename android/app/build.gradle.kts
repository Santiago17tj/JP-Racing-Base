import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Leer keystore de producción desde key.properties ──────────────────────
val keystoreProperties = Properties()
val keystorePropertiesFile = file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.mecanix.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Solo se define la firma de producción si existe key.properties; sin él
    // el build de release usa la firma de depuración en vez de fallar.
    val hayKeystore = keystorePropertiesFile.exists()

    signingConfigs {
        create("release") {
            if (hayKeystore) {
                storeFile     = file(keystoreProperties["storeFile"]     as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias      = keystoreProperties["keyAlias"]      as String
                keyPassword   = keystoreProperties["keyPassword"]   as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.mecanix.app"
        minSdk    = flutter.minSdkVersion
        targetSdk = 34
        versionCode = 36
        versionName = "1.4.3"
    }

    buildTypes {
        release {
            signingConfig = if (hayKeystore) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("AVISO: falta android/key.properties; el APK de release se firmará con la clave de depuración.")
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
