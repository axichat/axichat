import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val ciStorePath = System.getenv()["CM_KEYSTORE_PATH"]
val ciStoreFile = ciStorePath?.let { file(it) }
val ciStorePassword = System.getenv()["CM_KEYSTORE_PASSWORD"]
val ciKeyAlias = System.getenv()["CM_KEY_ALIAS"]
val ciKeyPassword = System.getenv()["CM_KEY_PASSWORD"]
val hasCiReleaseSigning =
    System.getenv()["CI"].toBoolean() &&
        ciStoreFile?.exists() == true &&
        !ciStorePassword.isNullOrBlank() &&
        !ciKeyAlias.isNullOrBlank() &&
        !ciKeyPassword.isNullOrBlank()

val localStorePath = keystoreProperties.getProperty("storeFile")
val localStoreFile = localStorePath?.let { file(it) }
val localStorePassword = keystoreProperties.getProperty("storePassword")
val localKeyAlias = keystoreProperties.getProperty("keyAlias")
val localKeyPassword = keystoreProperties.getProperty("keyPassword")
val hasLocalReleaseSigning =
    localStoreFile?.exists() == true &&
        !localStorePassword.isNullOrBlank() &&
        !localKeyAlias.isNullOrBlank() &&
        !localKeyPassword.isNullOrBlank()

val hasReleaseSigningConfig = hasCiReleaseSigning || hasLocalReleaseSigning

android {
    namespace = "im.axi.axichat"
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
        applicationId = "im.axi.axichat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = Math.max(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasCiReleaseSigning) {
                storeFile = ciStoreFile
                storePassword = ciStorePassword
                keyAlias = ciKeyAlias
                keyPassword = ciKeyPassword
            } else if (hasLocalReleaseSigning) {
                storeFile = localStoreFile
                storePassword = localStorePassword
                keyAlias = localKeyAlias
                keyPassword = localKeyPassword
            }
        }
    }

    flavorDimensions += "default"

    productFlavors {
        create("development") {
            dimension = "default"
            resValue(
                type = "string",
                name = "app_name",
                value = "[DEV] Axichat"
            )
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }

        create("production") {
            dimension = "default"
            resValue(
                type = "string",
                name = "app_name",
                value = "Axichat"
            )
            applicationIdSuffix = ""
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.sharetarget:sharetarget:1.2.0")
    implementation("androidx.window:window:1.3.0")
    implementation("androidx.window:window-java:1.3.0")
    implementation("androidx.activity:activity-ktx:1.10.1")
}

flutter {
    source = "../.."
}
