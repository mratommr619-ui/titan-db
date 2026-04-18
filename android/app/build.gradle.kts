plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mratom.easysrt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // Kotlin DSL မှာ string အနေနဲ့ တိုက်ရိုက်ပေးတာက ပိုအဆင်ပြေပါတယ်
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.mratom.easysrt"

        // Android 5 (API 21) အထိ အလုပ်လုပ်အောင် တိုက်ရိုက် နံပါတ်ပေးလိုက်ပါ
        minSdk = flutter.minSdkVersion 
        targetSdk = 35

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ဒီနေရာမှာ '=' လေး ထည့်ပေးဖို့ လိုအပ်ပါတယ် (Kotlin Syntax ဖြစ်လို့ပါ)
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            
            // App ကို ကျစ်ကျစ်လျစ်လျစ်ဖြစ်အောင် ဒီ line လေးတွေ ထည့်ပေးထားပါတယ်
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
