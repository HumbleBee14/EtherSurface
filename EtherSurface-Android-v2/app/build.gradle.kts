plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.humblebee.etherpad"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.humblebee.etherpad"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "2.0"

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17", "-fexceptions", "-frtti")
                // Oboe (and our engine) is C++ — link against the shared STL
                // so we share one copy of libc++ across all native libs.
                arguments += listOf("-DANDROID_STL=c++_shared")
            }
        }

        ndk {
            // Match the v1 ABIs. We skip x86 (32-bit) — emulators in 2026
            // are x86_64 and no shipping device is x86.
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    buildFeatures {
        compose = true
        prefab = true
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime)
    implementation(libs.androidx.activity.compose)

    val composeBom = platform(libs.compose.bom)
    implementation(composeBom)
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.ui.tooling.preview)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)

    debugImplementation(libs.compose.ui.tooling)

    // Oboe — modern low-latency audio. Used by the C++ render layer
    // (`src/main/cpp/`). Linked via `find_package(oboe REQUIRED CONFIG)`
    // in CMakeLists.txt thanks to `prefab = true` above.
    implementation(libs.oboe)
}
