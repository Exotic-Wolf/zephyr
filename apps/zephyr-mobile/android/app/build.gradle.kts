import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.zephyr.zephyr_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.zephyr.zephyr_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // Strip non-arm64 arches
            excludes += listOf("lib/x86_64/**", "lib/armeabi-v7a/**", "lib/x86/**", "lib/armeabi/**")
            // Strip unused Agora RTC extensions (saves ~45MB) — we only need core RTC for video calls
            excludes += listOf(
                "lib/*/libagora_clear_vision_extension.so",
                "lib/*/libagora_lip_sync_extension.so",
                "lib/*/libagora_spatial_audio_extension.so",
                "lib/*/libagora_ai_noise_suppression_extension.so",
                "lib/*/libagora_ai_noise_suppression_ll_extension.so",
                "lib/*/libagora_segmentation_extension.so",
                "lib/*/libagora_face_capture_extension.so",
                "lib/*/libagora_ai_echo_cancellation_extension.so",
                "lib/*/libagora_ai_echo_cancellation_ll_extension.so",
                "lib/*/libagora_audio_beauty_extension.so",
                "lib/*/libagora_content_inspect_extension.so",
                "lib/*/libagora_video_av1_encoder_extension.so",
                "lib/*/libagora_video_quality_analyzer_extension.so",
                "lib/*/libagora_face_detection_extension.so",
            )
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
