import groovy.json.JsonSlurper
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

android {
    namespace = "im.axi.axichat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

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
            if (System.getenv()["CI"].toBoolean()) { // CI=true is exported by Codemagic
                storeFile = System.getenv()["CM_KEYSTORE_PATH"]?.let { file(it) }
                storePassword = System.getenv()["CM_KEYSTORE_PASSWORD"]
                keyAlias = System.getenv()["CM_KEY_ALIAS"]
                keyPassword = System.getenv()["CM_KEY_PASSWORD"]
            } else {
                keyAlias = keystoreProperties["keyAlias"] as? String
                keyPassword = keystoreProperties["keyPassword"] as? String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as? String
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
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.window:window:1.3.0")
    implementation("androidx.window:window-java:1.3.0")
    implementation("androidx.activity:activity-ktx:1.10.1")
}

flutter {
    source = "../.."
}

fun Project.androidDevDependencyPluginNames(): Set<String> {
    val dependenciesFile = rootProject.projectDir.parentFile.resolve(".flutter-plugins-dependencies")
    if (!dependenciesFile.exists()) {
        return emptySet()
    }

    val root = JsonSlurper().parse(dependenciesFile) as? Map<*, *> ?: return emptySet()
    val plugins = root["plugins"] as? Map<*, *> ?: return emptySet()
    val androidPlugins = plugins["android"] as? List<*> ?: return emptySet()

    return androidPlugins.mapNotNull { entry ->
        val plugin = entry as? Map<*, *> ?: return@mapNotNull null
        val isDevDependency = plugin["dev_dependency"] as? Boolean ?: false
        if (!isDevDependency) {
            return@mapNotNull null
        }
        plugin["name"] as? String
    }.toSet()
}

fun Project.stripDevOnlyPluginRegistrationsFromGeneratedRegistrant() {
    val devDependencyPluginNames = androidDevDependencyPluginNames()
    if (devDependencyPluginNames.isEmpty()) {
        return
    }

    val registrantFile = projectDir.resolve("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
    if (!registrantFile.exists()) {
        return
    }

    val originalContents = registrantFile.readText()
    val registrationBlockPattern = Regex(
        """(?ms)^    try \{\R      flutterEngine\.getPlugins\(\)\.add\(new .+\);\R    \} catch \(Exception e\) \{\R      Log\.e\(TAG, "Error registering plugin ([^,]+), .+", e\);\R    \}\R"""
    )
    val removedPluginNames = mutableSetOf<String>()

    val sanitizedContents = originalContents.replace(registrationBlockPattern) { match ->
        val pluginName = match.groupValues[1]
        if (pluginName in devDependencyPluginNames) {
            removedPluginNames += pluginName
            ""
        } else {
            match.value
        }
    }

    if (sanitizedContents == originalContents) {
        return
    }

    registrantFile.writeText(sanitizedContents)
    logger.lifecycle(
        "Removed dev-only plugins from GeneratedPluginRegistrant.java for release build: ${removedPluginNames.sorted().joinToString()}"
    )
}

tasks.configureEach {
    if (name.contains("Release") && name.endsWith("JavaWithJavac")) {
        doFirst {
            project.stripDevOnlyPluginRegistrationsFromGeneratedRegistrant()
        }
    }
}
