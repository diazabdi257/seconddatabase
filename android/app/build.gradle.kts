plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android { // Pastikan blok ini dibuka dengan '{'
    namespace = "com.example.seconddatabase"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.seconddatabase"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = 33
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    lintOptions {
        isCheckReleaseBuilds = false
        isAbortOnError = false
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        getByName("debug") {
            // Konfigurasi untuk build debug (biasanya tidak banyak diubah)
            isDebuggable = true
        }
        getByName("release") {
            isMinifyEnabled = false // atau true jika Anda sudah siap dengan ProGuard
            isShrinkResources = false // atau true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"), // atau proguard-android.txt
                "proguard-rules.pro"
            )
            // Gunakan signingConfig release Anda di sini jika sudah dikonfigurasi
            // signingConfig = signingConfigs.getByName("release") 
            // Untuk sementara, Anda mungkin menggunakan debug jika belum setup release signing
            signingConfig = signingConfigs.getByName("debug") 
        }
        
    } // Ini menutup blok buildTypes
} // <-- PASTIKAN KURUNG KURAWAL PENUTUP UNTUK BLOK 'android' INI ADA SEBELUM 'dependencies'

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
    
} // Baris 74 (menurut error Anda) menutup blok dependencies

flutter {
    source = "../.."
}
