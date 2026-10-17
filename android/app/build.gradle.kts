import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}


// This private file stays outside the checkout. Preserve the original certificate
// so existing installations can update without uninstalling or losing local data.
val signingPropertiesFile = file(
    System.getenv("KRV_SIGNING_PROPERTIES")
        ?: "${System.getProperty("user.home")}/.krv-signing/signing.properties"
)
val releaseSigning = Properties()
if (signingPropertiesFile.isFile) {
    signingPropertiesFile.inputStream().use { releaseSigning.load(it) }
    for (key in listOf("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        require(!releaseSigning.getProperty(key).isNullOrBlank()) {
            "Missing signing property: $key"
        }
    }
}
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") }) {
        check(signingPropertiesFile.isFile) {
            "Release signing is required. Set KRV_SIGNING_PROPERTIES; see docs/ANDROID_RELEASE.md."
        }
    }
}

android {
    signingConfigs {
        if (signingPropertiesFile.isFile) {
            create("krvRelease") {
                storeFile = file(releaseSigning.getProperty("storeFile"))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }
    namespace = "krv.app"
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
        // Optional compatibility build updates the pre-rename application in place.
        // The standard release keeps the published RuStore identity.
        applicationId = "krv.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (signingPropertiesFile.isFile) {
                signingConfig = signingConfigs.getByName("krvRelease")
            }
        }
    }
}

flutter {
    source = "../.."
}
