plugins {
    id("com.android.library")
}

android {
    namespace = "com.thedemianff.lastzone.firebasebridge"
    compileSdk = 36

    defaultConfig {
        minSdk = 26
        manifestPlaceholders["godotPluginName"] = "AuroraFirebase"
        manifestPlaceholders["godotPluginPackageName"] =
            "com.thedemianff.lastzone.firebasebridge"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("org.godotengine:godot:4.5.1.stable")
    implementation(platform("com.google.firebase:firebase-bom:35.2.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-appcheck-playintegrity")
    implementation("com.google.firebase:firebase-functions")
    implementation("androidx.credentials:credentials:1.5.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.5.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
}
