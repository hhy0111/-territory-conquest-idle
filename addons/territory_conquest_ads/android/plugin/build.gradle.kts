plugins {
	id("com.android.library")
}

val godotPluginApiVersion = providers.gradleProperty("godotPluginApiVersion").get()
val googleMobileAdsVersion = providers.gradleProperty("googleMobileAdsVersion").get()
val umpVersion = providers.gradleProperty("umpVersion").get()
val androidCompileSdk = providers.gradleProperty("androidCompileSdk").get().toInt()
val androidMinSdk = providers.gradleProperty("androidMinSdk").get().toInt()

android {
	namespace = "com.hhy0111.territoryconquestidle.ads"
	compileSdk = androidCompileSdk

	defaultConfig {
		minSdk = androidMinSdk
		consumerProguardFiles("consumer-rules.pro")
	}

	buildTypes {
		getByName("release") {
			isMinifyEnabled = false
		}
	}

	compileOptions {
		sourceCompatibility = JavaVersion.VERSION_17
		targetCompatibility = JavaVersion.VERSION_17
	}
}

dependencies {
	compileOnly("org.godotengine:godot:$godotPluginApiVersion")
	implementation("com.google.android.gms:play-services-ads:$googleMobileAdsVersion")
	implementation("com.google.android.ump:user-messaging-platform:$umpVersion")
}

val addonRootDir = layout.projectDirectory.dir("../..")

tasks.register<Copy>("copyDebugAarToAddon") {
	dependsOn("assembleDebug")
	from(layout.buildDirectory.file("outputs/aar/plugin-debug.aar"))
	into(addonRootDir.dir("bin/debug"))
	rename { "territory-conquest-ads-debug.aar" }
}

tasks.register<Copy>("copyReleaseAarToAddon") {
	dependsOn("assembleRelease")
	from(layout.buildDirectory.file("outputs/aar/plugin-release.aar"))
	into(addonRootDir.dir("bin/release"))
	rename { "territory-conquest-ads-release.aar" }
}

tasks.register("copyAarsToAddon") {
	dependsOn("copyDebugAarToAddon", "copyReleaseAarToAddon")
}
