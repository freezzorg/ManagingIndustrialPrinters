import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "kz.kcep.mip"
	compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }
	
	signingConfigs {
		create("release") {
			val storeFilePath = keystoreProperties["storeFile"] as? String
				?: throw GradleException("Missing 'storeFile' in key.properties")

			val storePassword = keystoreProperties["storePassword"] as? String
				?: throw GradleException("Missing 'storePassword' in key.properties")

			val keyAlias = keystoreProperties["keyAlias"] as? String
				?: throw GradleException("Missing 'keyAlias' in key.properties")

			val keyPassword = keystoreProperties["keyPassword"] as? String
				?: throw GradleException("Missing 'keyPassword' in key.properties")

			storeFile = file(storeFilePath)
			println("Keystore file absolute path: ${file(storeFilePath).absolutePath}")
			this.storePassword = storePassword
			this.keyAlias = keyAlias
			this.keyPassword = keyPassword
		}
	}

    defaultConfig {
        applicationId = "kz.kcep.mip"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
		multiDexEnabled = true

        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86"))
        }

    }
	
	buildTypes {
        getByName("release") {
            isMinifyEnabled = false
			isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
            matchingFallbacks.add("release")
        }
    }
	
	lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    dependenciesInfo {
        includeInApk = true
        includeInBundle = true
    }
	
	dependencies {
		implementation("androidx.multidex:multidex:2.0.1")
        implementation("androidx.core:core-ktx:1.12.0")
	}
}

flutter {
    source = "../.."
}
