param(
	[ValidateSet("Debug", "Release")]
	[string]$Variant = "Release",
	[string]$PresetName = "",
	[string]$OutputPath = "",
	[string]$GodotPath = "",
	[switch]$BuildPlugin,
	[switch]$UseGradleFallback,
	[switch]$FallbackOnFailure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_android_tooling.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$buildScript = Join-Path $PSScriptRoot "build_plugin.ps1"
$checkScript = Join-Path $PSScriptRoot "check_environment.ps1"
$fallbackScript = Join-Path $PSScriptRoot "export_android_gradle_fallback.ps1"
$runtimeConfigPath = Join-Path $repoRoot "data\\ad_runtime.json"
$exportPresetPath = Join-Path $repoRoot "export_presets.cfg"

function Invoke-FallbackExport {
	$fallbackArgs = @{
		Variant = $Variant
		BuildPlugin = $BuildPlugin
	}
	if (-not [string]::IsNullOrWhiteSpace($PresetName)) {
		$fallbackArgs.PresetName = $PresetName
	}
	if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
		$fallbackArgs.OutputPath = $OutputPath
	}
	if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
		$fallbackArgs.GodotPath = $GodotPath
	}

	& $fallbackScript @fallbackArgs
}

if (-not (Test-Path $runtimeConfigPath)) {
	throw "Missing runtime config: $runtimeConfigPath"
}
if (-not (Test-Path $exportPresetPath)) {
	throw "Missing export preset file: $exportPresetPath"
}
if (-not (Test-Path $fallbackScript)) {
	throw "Missing fallback export script: $fallbackScript"
}

if ($UseGradleFallback) {
	Invoke-FallbackExport
	return
}

$aarRelativePath = if ($Variant -eq "Release") {
	"addons\\territory_conquest_ads\\bin\\release\\territory-conquest-ads-release.aar"
} else {
	"addons\\territory_conquest_ads\\bin\\debug\\territory-conquest-ads-debug.aar"
}
$aarPath = Join-Path $repoRoot $aarRelativePath

if (-not (Test-Path $aarPath)) {
	if ($BuildPlugin) {
		& $buildScript -Variant $Variant
	} else {
		throw "Missing Android plugin AAR: $aarPath. Re-run with -BuildPlugin after installing Gradle or building the AAR manually."
	}
}

if (-not (Test-Path $aarPath)) {
	throw "Android plugin AAR is still missing after build step: $aarPath"
}

$runtimeConfig = Get-Content $runtimeConfigPath -Raw | ConvertFrom-Json
$packageName = [string]$runtimeConfig.platforms.android.package_name
if ([string]::IsNullOrWhiteSpace($packageName)) {
	$packageName = "com.hhy0111.territoryconquestidle"
}

if ([string]::IsNullOrWhiteSpace($PresetName)) {
	$PresetName = if ($Variant -eq "Release") { "Android Release" } else { "Android Debug" }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	$fileName = if ($Variant -eq "Release") { "territory-conquest-idle-release.apk" } else { "territory-conquest-idle-debug.apk" }
	$OutputPath = Join-Path $repoRoot (Join-Path ".exports\\android" $fileName)
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path $outputDirectory)) {
	New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
	$GodotPath = Resolve-GodotPath
}

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
	throw "Godot executable was not found. Pass -GodotPath or add Godot to PATH."
}

$sdkRoot = Set-ResolvedAndroidEnvironment
$javaHome = Set-ResolvedJavaEnvironment -PreferredMajorVersion 17
if ([string]::IsNullOrWhiteSpace($javaHome)) {
	throw "JDK 17 was not found. Install Temurin 17 or set JAVA_HOME to a JDK 17 path."
}
& $checkScript -Variant $Variant -GodotPath $GodotPath -RequireGodot -RequireJava -RequireAndroidSdk -RequireReleaseSigning:($Variant -eq "Release")

$exportFlag = if ($Variant -eq "Release") { "--export-release" } else { "--export-debug" }

Write-Host "Package: $packageName"
Write-Host "Preset: $PresetName"
Write-Host "Output: $OutputPath"

& $checkScript -Variant $Variant -GodotPath $GodotPath -RequireGodot -RequireJava -RequireAndroidSdk -RequireAar -RequireReleaseSigning:($Variant -eq "Release")

Push-Location $repoRoot
$officialExportError = ""
try {
	& $GodotPath --headless --path $repoRoot $exportFlag $PresetName $OutputPath
	if ($LASTEXITCODE -ne 0) {
		throw "Godot export failed with exit code $LASTEXITCODE."
	}
} catch {
	$officialExportError = $_.Exception.Message
} finally {
	Pop-Location
}

if (-not [string]::IsNullOrWhiteSpace($officialExportError)) {
	if ($FallbackOnFailure) {
		Write-Warning "Official Godot Android export failed; retrying with the Gradle fallback export path."
		Invoke-FallbackExport
		return
	}

	throw $officialExportError
}
