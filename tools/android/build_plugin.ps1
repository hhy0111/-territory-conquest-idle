param(
	[ValidateSet("All", "Debug", "Release")]
	[string]$Variant = "All"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_android_tooling.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$androidRoot = Join-Path $repoRoot "addons\\territory_conquest_ads\\android"
$checkScript = Join-Path $PSScriptRoot "check_environment.ps1"
$gradleWrapper = Join-Path $androidRoot "gradlew.bat"
$gradleCommand = Resolve-GradlePath -WrapperPath $gradleWrapper
$javaHome = Set-ResolvedJavaEnvironment -PreferredMajorVersion 17

if ([string]::IsNullOrWhiteSpace($gradleCommand)) {
	throw "Gradle was not found. Install Gradle or add gradlew.bat under addons/territory_conquest_ads/android."
}
if ([string]::IsNullOrWhiteSpace($javaHome)) {
	throw "JDK 17 was not found. Install Temurin 17 or set JAVA_HOME to a JDK 17 path."
}

$sdkRoot = Set-ResolvedAndroidEnvironment
& $checkScript -Variant $Variant -GradlePath $gradleCommand -RequireGradle -RequireJava -RequireAndroidSdk

$task = switch ($Variant) {
	"Debug" { ":plugin:copyDebugAarToAddon" }
	"Release" { ":plugin:copyReleaseAarToAddon" }
	default { ":plugin:copyAarsToAddon" }
}

Push-Location $androidRoot
try {
	& $gradleCommand $task
	if ($LASTEXITCODE -ne 0) {
		throw "Gradle task failed with exit code $LASTEXITCODE."
	}
} finally {
	Pop-Location
}
