plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}


android {
    namespace = "com.example.quick_commerce_seller"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must match a client in android/app/google-services.json — the
        // google-services plugin fails the build on a mismatch, and Firebase
        // hands out no push token for an unregistered package.
        applicationId = "com.versapack.seller"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // The Maps key lives in gradle.properties (or -Pmaps-api-key=... on the
        // command line) and is substituted into AndroidManifest.xml. Keeping it
        // out of the manifest means there is exactly one place to change it and
        // nothing to accidentally leave behind in a diff.
        manifestPlaceholders["MAPS_API_KEY"] =
            (project.findProperty("maps-api-key")
                ?: project.findProperty("MAPS_API_KEY")
                ?: "").toString()
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // The firebase_messaging plugin keeps firebase-messaging on its own
    // classpath only, so RemoteMessage and FlutterFirebaseMessagingService do
    // not resolve in app code without declaring it here.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
