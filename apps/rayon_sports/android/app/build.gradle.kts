import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val isolatedNonReleaseApplicationIdSuffix = providers
    .gradleProperty("africlubDebugApplicationIdSuffix")
    .orNull
    ?.trim()
    ?.takeIf { it.isNotEmpty() }
val hasGoogleServicesConfig = file("google-services.json").exists()
if (hasGoogleServicesConfig && isolatedNonReleaseApplicationIdSuffix == null) {
    apply(plugin = "com.google.gms.google-services")
}

val requestedTaskNames = gradle.startParameter.taskNames.map { it.lowercase() }
val isReleaseBuildRequested = requestedTaskNames.any { taskName ->
    taskName.contains("release")
}

// Aggregate tasks such as assemble can include release without naming it.
if (isolatedNonReleaseApplicationIdSuffix != null) {
    require(Regex("\\.[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)*").matches(isolatedNonReleaseApplicationIdSuffix)) {
        "africlubDebugApplicationIdSuffix must be a nonempty dotted package suffix."
    }
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.project == project && it.name.contains("release", ignoreCase = true) }) {
            error("africlubDebugApplicationIdSuffix is allowed only for isolated debug/profile device validation.")
        }
    }
}

val keystoreProperties = Properties()
val keystorePropertiesFiles = listOf(rootProject.file("keystore.properties"))
for (propertiesFile in keystorePropertiesFiles) {
    if (propertiesFile.exists()) {
        propertiesFile.inputStream().use(keystoreProperties::load)
        break
    }
}

fun signingValue(propertyName: String, envName: String): String? {
    val envValue = System.getenv(envName)?.trim()
    if (!envValue.isNullOrEmpty()) {
        return envValue
    }
    val fileValue = keystoreProperties.getProperty(propertyName)?.trim()
    if (!fileValue.isNullOrEmpty()) {
        return fileValue
    }
    return null
}

val releaseStoreFile = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val hasReleaseSigning = !releaseStoreFile.isNullOrEmpty() &&
    !releaseStorePassword.isNullOrEmpty() &&
    !releaseKeyAlias.isNullOrEmpty() &&
    !releaseKeyPassword.isNullOrEmpty()

if (isReleaseBuildRequested && !hasGoogleServicesConfig) {
    error("Release builds require android/app/google-services.json for Firebase-backed production features.")
}

if (isReleaseBuildRequested && isolatedNonReleaseApplicationIdSuffix != null) {
    error("africlubDebugApplicationIdSuffix is allowed only for isolated debug/profile device validation.")
}

if (isReleaseBuildRequested && !hasReleaseSigning) {
    error(
        "Release signing credentials are required. Provide keystore.properties or the ANDROID_KEYSTORE_* environment variables."
    )
}

android {
    // Compile one shared protected recovery host; each engine owns its dispatcher.
    sourceSets.getByName("main").java.srcDir(
        "../../../../packages/features/feat_membership/native/android/src/main/kotlin",
    )

    namespace = "rw.gikundiro.app"
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
        applicationId = "rw.gikundiro.app"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            if (isolatedNonReleaseApplicationIdSuffix != null) {
                applicationIdSuffix = isolatedNonReleaseApplicationIdSuffix
                versionNameSuffix = "-isolated-qa"
            }
        }
        getByName("profile") {
            if (isolatedNonReleaseApplicationIdSuffix != null) {
                applicationIdSuffix = isolatedNonReleaseApplicationIdSuffix
                versionNameSuffix = "-isolated-qa"
            }
        }
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            // R8 code shrinking & obfuscation
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Disable debug info in release
            ndk {
                debugSymbolLevel = "FULL"
            }
        }
    }

    // Ensure 16KB page alignment for Android 15+ (API 35+)
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-pay:16.5.0")
}

flutter {
    source = "../.."
}
