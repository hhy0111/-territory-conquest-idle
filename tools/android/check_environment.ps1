param(
	[ValidateSet("All", "Debug", "Release")]
	[string]$Variant = "Release",
	[string]$GodotPath = "",
	[string]$GradlePath = "",
	[switch]$RequireGodot,
	[switch]$RequireGradle,
	[switch]$RequireJava,
	[switch]$RequireAndroidSdk,
	[switch]$RequireAdb,
	[switch]$RequireEmulator,
	[switch]$RequireAar,
	[switch]$RequireReleaseSigning
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_android_tooling.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$exportPresetPath = Join-Path $repoRoot "export_presets.cfg"
$runtimeConfigPath = Join-Path $repoRoot "data\\ad_runtime.json"
$pluginRoot = Join-Path $repoRoot "addons\\territory_conquest_ads"
$androidRoot = Join-Path $pluginRoot "android"
$effectiveVariant = if ($Variant -eq "Debug") { "Debug" } else { "Release" }
$aarPath = if ($effectiveVariant -eq "Release") {
	Join-Path $pluginRoot "bin\\release\\territory-conquest-ads-release.aar"
} else {
	Join-Path $pluginRoot "bin\\debug\\territory-conquest-ads-debug.aar"
}

$results = New-Object System.Collections.Generic.List[object]
$hasErrors = $false

function Add-Result {
	param(
		[string]$Name,
		[bool]$Ok,
		[string]$Detail,
		[bool]$Required = $false
	)

	$results.Add([PSCustomObject]@{
		Name = $Name
		Ok = $Ok
		Detail = $Detail
		Required = $Required
	}) | Out-Null

	if ($Required -and -not $Ok) {
		$script:hasErrors = $true
	}
}

function Get-PresetOptionValue {
	param(
		[string]$PresetName,
		[string]$OptionName
	)

	if (-not (Test-Path $exportPresetPath)) {
		return ""
	}

	$currentPreset = ""
	$inOptions = $false
	foreach ($line in Get-Content $exportPresetPath) {
		if ($line -match '^\[preset\.(\d+)\]$') {
			$currentPreset = ""
			$inOptions = $false
			continue
		}
		if ($line -match '^\[preset\.(\d+)\.options\]$') {
			$inOptions = $true
			continue
		}
		if ($line -match '^name="(.+)"$') {
			$currentPreset = $matches[1]
			continue
		}
		if (-not $inOptions -or $currentPreset -ne $PresetName) {
			continue
		}
		if ($line -match ('^{0}="(.*)"$' -f [regex]::Escape($OptionName))) {
			return $matches[1]
		}
	}

	return ""
}

$resolvedGodotPath = $GodotPath
if ([string]::IsNullOrWhiteSpace($resolvedGodotPath)) {
	$resolvedGodotPath = Resolve-GodotPath
}

$resolvedGradlePath = $GradlePath
if ([string]::IsNullOrWhiteSpace($resolvedGradlePath)) {
	$wrapperPath = Join-Path $androidRoot "gradlew.bat"
	$resolvedGradlePath = Resolve-GradlePath -WrapperPath $wrapperPath
}

$resolvedJavaHome = Resolve-JavaHome -PreferredMajorVersion 17
$resolvedJavaPath = if (-not [string]::IsNullOrWhiteSpace($resolvedJavaHome)) {
	Join-Path $resolvedJavaHome "bin\\java.exe"
} else {
	Resolve-CommandPath @("java")
}
$androidSdkRoot = Set-ResolvedAndroidEnvironment
$resolvedAdbPath = Resolve-AdbPath
$resolvedEmulatorPath = Resolve-EmulatorPath

$releasePresetName = "Android Release"
$debugPresetName = "Android Debug"
$selectedPresetName = if ($effectiveVariant -eq "Release") { $releasePresetName } else { $debugPresetName }
$keystorePathEnv = if ($effectiveVariant -eq "Release") { "GODOT_ANDROID_KEYSTORE_RELEASE_PATH" } else { "GODOT_ANDROID_KEYSTORE_DEBUG_PATH" }
$keystoreUserEnv = if ($effectiveVariant -eq "Release") { "GODOT_ANDROID_KEYSTORE_RELEASE_USER" } else { "GODOT_ANDROID_KEYSTORE_DEBUG_USER" }
$keystorePasswordEnv = if ($effectiveVariant -eq "Release") { "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" } else { "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD" }

Add-Result "Runtime Config" (Test-Path $runtimeConfigPath) $runtimeConfigPath $true
Add-Result "Export Presets" (Test-Path $exportPresetPath) $exportPresetPath $true
Add-Result "Android Plugin Source" (Test-Path $androidRoot) $androidRoot $true
$godotDetail = if (-not [string]::IsNullOrWhiteSpace($resolvedGodotPath)) { $resolvedGodotPath } else { "Not found in PATH." }
$gradleDetail = if (-not [string]::IsNullOrWhiteSpace($resolvedGradlePath)) { $resolvedGradlePath } else { "No gradle or gradlew.bat found." }
Add-Result "Godot" (-not [string]::IsNullOrWhiteSpace($resolvedGodotPath)) $godotDetail $RequireGodot
Add-Result "Gradle" (-not [string]::IsNullOrWhiteSpace($resolvedGradlePath)) $gradleDetail $RequireGradle

$javaDetail = if (-not [string]::IsNullOrWhiteSpace($resolvedJavaHome)) {
	"JAVA_HOME=$resolvedJavaHome"
} elseif (-not [string]::IsNullOrWhiteSpace($resolvedJavaPath)) {
	$resolvedJavaPath
} else {
	"JDK 17 was not found."
}
Add-Result "Java (JDK 17)" (-not [string]::IsNullOrWhiteSpace($resolvedJavaHome)) $javaDetail $RequireJava

$androidSdkOk = -not [string]::IsNullOrWhiteSpace($androidSdkRoot)
$androidSdkDetail = if ($androidSdkOk) { $androidSdkRoot } else { "ANDROID_SDK_ROOT or ANDROID_HOME is not set." }
Add-Result "Android SDK" $androidSdkOk $androidSdkDetail $RequireAndroidSdk
Add-Result "ADB" (-not [string]::IsNullOrWhiteSpace($resolvedAdbPath)) $(if (-not [string]::IsNullOrWhiteSpace($resolvedAdbPath)) { $resolvedAdbPath } else { "adb was not found." }) $RequireAdb
Add-Result "Emulator" (-not [string]::IsNullOrWhiteSpace($resolvedEmulatorPath)) $(if (-not [string]::IsNullOrWhiteSpace($resolvedEmulatorPath)) { $resolvedEmulatorPath } else { "emulator.exe was not found." }) $RequireEmulator

$aarOk = Test-Path $aarPath
$aarDetail = if ($aarOk) { $aarPath } else { "Missing: $aarPath" }
Add-Result "Plugin AAR ($effectiveVariant)" $aarOk $aarDetail $RequireAar

if ($RequireReleaseSigning) {
	$keystorePathValue = Get-EnvValue $keystorePathEnv
	$keystoreUserValue = Get-EnvValue $keystoreUserEnv
	$keystorePasswordValue = Get-EnvValue $keystorePasswordEnv

	$presetKeystorePath = Get-PresetOptionValue $selectedPresetName ("keystore/" + ($effectiveVariant.ToLower()))
	$presetKeystoreUser = Get-PresetOptionValue $selectedPresetName ("keystore/" + ($effectiveVariant.ToLower()) + "_user")
	$presetKeystorePassword = Get-PresetOptionValue $selectedPresetName ("keystore/" + ($effectiveVariant.ToLower()) + "_password")

	$signingPathOk = (-not [string]::IsNullOrWhiteSpace($keystorePathValue)) -or (-not [string]::IsNullOrWhiteSpace($presetKeystorePath))
	$signingUserOk = (-not [string]::IsNullOrWhiteSpace($keystoreUserValue)) -or (-not [string]::IsNullOrWhiteSpace($presetKeystoreUser))
	$signingPasswordOk = (-not [string]::IsNullOrWhiteSpace($keystorePasswordValue)) -or (-not [string]::IsNullOrWhiteSpace($presetKeystorePassword))

	Add-Result "Release Keystore Path" $signingPathOk "Env: $keystorePathEnv or preset '$selectedPresetName' -> keystore/$($effectiveVariant.ToLower())" $true
	Add-Result "Release Keystore User" $signingUserOk "Env: $keystoreUserEnv or preset '$selectedPresetName' -> keystore/$($effectiveVariant.ToLower())_user" $true
	Add-Result "Release Keystore Password" $signingPasswordOk "Env: $keystorePasswordEnv or preset '$selectedPresetName' -> keystore/$($effectiveVariant.ToLower())_password" $true
}

foreach ($result in $results) {
	$status = if ($result.Ok) { "[OK]" } else { "[MISSING]" }
	$requiredSuffix = if ($result.Required) { " required" } else { "" }
	Write-Host ("{0} {1}{2}: {3}" -f $status, $result.Name, $requiredSuffix, $result.Detail)
}

if ($hasErrors) {
	exit 1
}
