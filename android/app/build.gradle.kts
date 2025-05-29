import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "kz.kcep.mip"
	compileSdk = 35 // нужно для mobile_scanner

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
        minSdk = 21
        targetSdk = 33 // <= под Android 10
        versionCode = 1
        versionName = "1.0"
		multiDexEnabled = true
    }
	
	buildTypes {
        getByName("release") {
            isMinifyEnabled = false
			isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
	
	lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
	
	dependencies {
		implementation("androidx.multidex:multidex:2.0.1")
	}
}

flutter {
    source = "../.."
}