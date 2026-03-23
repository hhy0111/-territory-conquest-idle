param(
	[ValidateSet("Debug", "Release")]
	[string]$Variant = "Debug",
	[string]$PresetName = "",
	[string]$OutputPath = "",
	[string]$GodotPath = "",
	[switch]$BuildPlugin,
	[switch]$ForceTemplateInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_android_tooling.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$buildScript = Join-Path $PSScriptRoot "build_plugin.ps1"
$checkScript = Join-Path $PSScriptRoot "check_environment.ps1"
$installTemplateScript = Join-Path $PSScriptRoot "install_project_android_build_template.ps1"
$runtimeConfigPath = Join-Path $repoRoot "data\\ad_runtime.json"
$exportPresetPath = Join-Path $repoRoot "export_presets.cfg"
$projectConfigPath = Join-Path $repoRoot "project.godot"
$androidBuildRoot = Join-Path $repoRoot "android\\build"
$assetsRoot = Join-Path $androidBuildRoot "assets"
$gradleWrapper = Join-Path $androidBuildRoot "gradlew.bat"
$debugKeystoreDefault = Join-Path $env:APPDATA "Godot\\keystores\\debug.keystore"

function Get-PresetOptionValue {
	param(
		[string]$TargetPresetName,
		[string]$OptionName
	)

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
		if (-not $inOptions -or $currentPreset -ne $TargetPresetName) {
			continue
		}
		if ($line -match ('^{0}="(.*)"$' -f [regex]::Escape($OptionName))) {
			return $matches[1]
		}
	}

	return ""
}

function Get-ProjectSettingValue {
	param([string]$SettingName)

	if (-not (Test-Path $projectConfigPath)) {
		return ""
	}

	foreach ($line in Get-Content $projectConfigPath) {
		if ($line -match ('^{0}="(.*)"$' -f [regex]::Escape($SettingName))) {
			return $matches[1]
		}
	}

	return ""
}

function Get-ReleaseSigningValue {
	param(
		[string]$EnvName,
		[string]$PresetOptionName,
		[string]$TargetPresetName
	)

	$envValue = Get-EnvValue $EnvName
	if (-not [string]::IsNullOrWhiteSpace($envValue)) {
		return $envValue
	}
	return Get-PresetOptionValue -TargetPresetName $TargetPresetName -OptionName $PresetOptionName
}

function Set-GodotProjectNameResources {
	param(
		[string]$AndroidBuildRoot,
		[string]$ProjectName
	)

	if ([string]::IsNullOrWhiteSpace($ProjectName)) {
		return
	}

	$resourceRoot = Join-Path $AndroidBuildRoot "res"
	if (-not (Test-Path $resourceRoot)) {
		return
	}

	$escapedProjectName = [System.Security.SecurityElement]::Escape($ProjectName)
	$resourceFiles = Get-ChildItem -Path $resourceRoot -Recurse -Filter "godot_project_name_string.xml" -File -ErrorAction SilentlyContinue
	foreach ($resourceFile in $resourceFiles) {
		$content = Get-Content -Path $resourceFile.FullName -Raw
		$updatedContent = [regex]::Replace(
			$content,
			'(<string name="godot_project_name_string">)(.*?)(</string>)',
			('${1}' + $escapedProjectName + '${3}')
		)
		if ($updatedContent -ne $content) {
			Set-Content -Path $resourceFile.FullName -Value $updatedContent -Encoding utf8
		}
	}
}

function Get-ChildProcessIds {
	param([int]$ParentProcessId)

	$childIds = New-Object System.Collections.Generic.List[int]
	$children = @(Get-CimInstance Win32_Process -Filter ("ParentProcessId = {0}" -f $ParentProcessId) -ErrorAction SilentlyContinue)
	foreach ($child in $children) {
		$childId = [int]$child.ProcessId
		$childIds.Add($childId) | Out-Null
		foreach ($descendantId in @(Get-ChildProcessIds -ParentProcessId $childId)) {
			$childIds.Add([int]$descendantId) | Out-Null
		}
	}
	return @($childIds)
}

function Stop-ProcessTree {
	param([int]$RootProcessId)

	$processIds = @((Get-ChildProcessIds -ParentProcessId $RootProcessId) + $RootProcessId | Sort-Object -Descending -Unique)
	foreach ($processId in $processIds) {
		Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
	}
}

function Invoke-GodotExportPack {
	param(
		[string]$GodotExecutable,
		[string]$ProjectRoot,
		[string]$TargetPresetName,
		[string]$TargetZipPath,
		[int]$StableSeconds = 8,
		[int]$MaxWaitSeconds = 240
	)

	if (Test-Path $TargetZipPath) {
		Remove-Item -Path $TargetZipPath -Force
	}

	$stdoutLogPath = "$TargetZipPath.stdout.log"
	$stderrLogPath = "$TargetZipPath.stderr.log"
	if (Test-Path $stdoutLogPath) {
		Remove-Item -Path $stdoutLogPath -Force
	}
	if (Test-Path $stderrLogPath) {
		Remove-Item -Path $stderrLogPath -Force
	}

	function Get-ExportPackLogSummary {
		$lines = New-Object System.Collections.Generic.List[string]
		if (Test-Path $stdoutLogPath) {
			foreach ($line in @(Get-Content -Path $stdoutLogPath -Tail 20)) {
				$lines.Add([string]$line) | Out-Null
			}
		}
		if (Test-Path $stderrLogPath) {
			foreach ($line in @(Get-Content -Path $stderrLogPath -Tail 20)) {
				$lines.Add([string]$line) | Out-Null
			}
		}
		if ($lines.Count -eq 0) {
			return ""
		}
		return "`nGodot export-pack logs:`n$($lines -join "`n")"
	}

	$arguments = "--headless --path `"$ProjectRoot`" --export-pack `"$TargetPresetName`" `"$TargetZipPath`""
	$process = Start-Process `
		-FilePath $GodotExecutable `
		-ArgumentList $arguments `
		-WorkingDirectory $ProjectRoot `
		-PassThru `
		-RedirectStandardOutput $stdoutLogPath `
		-RedirectStandardError $stderrLogPath
	$deadline = (Get-Date).AddSeconds($MaxWaitSeconds)
	$lastObservedSize = -1L
	$stableSince = $null

	try {
		while ((Get-Date) -lt $deadline) {
			Start-Sleep -Seconds 2
			$process.Refresh()

			if (Test-Path $TargetZipPath) {
				$currentSize = (Get-Item -LiteralPath $TargetZipPath).Length
				if ($currentSize -gt 0 -and $currentSize -eq $lastObservedSize) {
					if ($stableSince -eq $null) {
						$stableSince = Get-Date
					}
				} else {
					$stableSince = $null
					$lastObservedSize = $currentSize
				}
			}

			if ($process.HasExited) {
				if (-not (Test-Path $TargetZipPath)) {
					throw "Godot export-pack exited without creating: $TargetZipPath$(Get-ExportPackLogSummary)"
				}
				if ($null -ne $process.ExitCode -and $process.ExitCode -ne 0) {
					throw "Godot export-pack failed with exit code $($process.ExitCode).$(Get-ExportPackLogSummary)"
				}
				return
			}

			if ($stableSince -ne $null -and ((Get-Date) - $stableSince).TotalSeconds -ge $StableSeconds) {
				Write-Warning "Godot export-pack produced a stable zip but left a lingering process tree; stopping it and continuing."
				Stop-ProcessTree -RootProcessId $process.Id
				if (-not (Test-Path $TargetZipPath)) {
					throw "Godot export-pack process tree was stopped before the zip could be confirmed.$(Get-ExportPackLogSummary)"
				}
				return
			}
		}
	} finally {
		if (-not $process.HasExited) {
			Stop-ProcessTree -RootProcessId $process.Id
		}
	}

	if (Test-Path $TargetZipPath) {
		throw "Godot export-pack timed out after $MaxWaitSeconds seconds, even though a zip was produced: $TargetZipPath$(Get-ExportPackLogSummary)"
	}
	throw "Godot export-pack timed out after $MaxWaitSeconds seconds without producing: $TargetZipPath$(Get-ExportPackLogSummary)"
}

if (-not (Test-Path $runtimeConfigPath)) {
	throw "Missing runtime config: $runtimeConfigPath"
}
if (-not (Test-Path $exportPresetPath)) {
	throw "Missing export preset file: $exportPresetPath"
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

if ([string]::IsNullOrWhiteSpace($PresetName)) {
	$PresetName = if ($Variant -eq "Release") { "Android Release" } else { "Android Debug" }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	$fileName = if ($Variant -eq "Release") { "territory-conquest-idle-release-fallback.apk" } else { "territory-conquest-idle-debug-fallback.apk" }
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

& $checkScript -Variant $Variant -GodotPath $GodotPath -RequireGodot -RequireJava -RequireAndroidSdk -RequireAar -RequireReleaseSigning:($Variant -eq "Release")

if ($ForceTemplateInstall -or -not (Test-Path (Join-Path $androidBuildRoot "build.gradle"))) {
	& $installTemplateScript -Force:$true
}

$exportPackageName = Get-PresetOptionValue -TargetPresetName $PresetName -OptionName "package/unique_name"
if ([string]::IsNullOrWhiteSpace($exportPackageName)) {
	$runtimeConfig = Get-Content $runtimeConfigPath -Raw | ConvertFrom-Json
	$exportPackageName = [string]$runtimeConfig.platforms.android.package_name
}
if ([string]::IsNullOrWhiteSpace($exportPackageName)) {
	$exportPackageName = "com.hhy0111.territoryconquestidle"
}

$exportVersionCode = Get-PresetOptionValue -TargetPresetName $PresetName -OptionName "version/code"
if ([string]::IsNullOrWhiteSpace($exportVersionCode)) {
	$exportVersionCode = "1"
}
$exportVersionName = Get-PresetOptionValue -TargetPresetName $PresetName -OptionName "version/name"
if ([string]::IsNullOrWhiteSpace($exportVersionName)) {
	$exportVersionName = "0.1.0"
}
$exportMinSdk = Get-PresetOptionValue -TargetPresetName $PresetName -OptionName "gradle_build/min_sdk"
if ([string]::IsNullOrWhiteSpace($exportMinSdk)) {
	$exportMinSdk = "24"
}
$exportTargetSdk = Get-PresetOptionValue -TargetPresetName $PresetName -OptionName "gradle_build/target_sdk"
if ([string]::IsNullOrWhiteSpace($exportTargetSdk)) {
	$exportTargetSdk = "34"
}
$exportAppName = Get-PresetOptionValue -TargetPresetName $PresetName -OptionName "package/name"
if ([string]::IsNullOrWhiteSpace($exportAppName)) {
	$exportAppName = Get-ProjectSettingValue -SettingName "config/name"
}
if ([string]::IsNullOrWhiteSpace($exportAppName)) {
	$exportAppName = "Territory Conquest Idle"
}

$exportZipName = [System.IO.Path]::GetFileNameWithoutExtension($OutputPath) + ".zip"
$exportZipPath = Join-Path $outputDirectory $exportZipName

Write-Host "Fallback preset: $PresetName"
Write-Host "Fallback package: $exportPackageName"
Write-Host "Fallback app name: $exportAppName"
Write-Host "Fallback output: $OutputPath"

Invoke-GodotExportPack `
	-GodotExecutable $GodotPath `
	-ProjectRoot $repoRoot `
	-TargetPresetName $PresetName `
	-TargetZipPath $exportZipPath

$assetsBackupPath = Join-Path $androidBuildRoot "assets_previous"
if (Test-Path $assetsBackupPath) {
	Remove-Item -Recurse -Force $assetsBackupPath
}
if (Test-Path $assetsRoot) {
	Rename-Item -Path $assetsRoot -NewName (Split-Path $assetsBackupPath -Leaf)
}
New-Item -ItemType Directory -Path $assetsRoot -Force | Out-Null
Expand-Archive -Path $exportZipPath -DestinationPath $assetsRoot -Force
Set-GodotProjectNameResources -AndroidBuildRoot $androidBuildRoot -ProjectName $exportAppName

$gradleTask = if ($Variant -eq "Release") { "assembleRelease" } else { "assembleDebug" }
$outputApkName = if ($Variant -eq "Release") { "android_release.apk" } else { "android_debug.apk" }
$outputApkSourcePath = Join-Path $androidBuildRoot ("build\\outputs\\apk\\{0}\\{1}" -f $Variant.ToLower(), $outputApkName)

$gradleArgs = @(
	$gradleTask,
	"-Pexport_package_name=$exportPackageName",
	"-Pexport_version_code=$exportVersionCode",
	"-Pexport_version_name=$exportVersionName",
	"-Pexport_version_min_sdk=$exportMinSdk",
	"-Pexport_version_target_sdk=$exportTargetSdk",
	"-Pperform_signing=true",
	"-Pperform_zipalign=true"
)

if ($Variant -eq "Release") {
	$releaseKeystoreFile = Get-ReleaseSigningValue -EnvName "GODOT_ANDROID_KEYSTORE_RELEASE_PATH" -PresetOptionName "keystore/release" -TargetPresetName $PresetName
	$releaseKeystoreUser = Get-ReleaseSigningValue -EnvName "GODOT_ANDROID_KEYSTORE_RELEASE_USER" -PresetOptionName "keystore/release_user" -TargetPresetName $PresetName
	$releaseKeystorePassword = Get-ReleaseSigningValue -EnvName "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD" -PresetOptionName "keystore/release_password" -TargetPresetName $PresetName
	if ([string]::IsNullOrWhiteSpace($releaseKeystoreFile) -or [string]::IsNullOrWhiteSpace($releaseKeystoreUser) -or [string]::IsNullOrWhiteSpace($releaseKeystorePassword)) {
		throw "Release signing values are missing. Set release keystore env vars or preset values before using the fallback release export."
	}
	$gradleArgs += @(
		"-Prelease_keystore_file=$releaseKeystoreFile",
		"-Prelease_keystore_alias=$releaseKeystoreUser",
		"-Prelease_keystore_password=$releaseKeystorePassword"
	)
} else {
	if (-not (Test-Path $debugKeystoreDefault)) {
		throw "Debug keystore was not found: $debugKeystoreDefault"
	}
	$gradleArgs += @(
		"-Pdebug_keystore_file=$debugKeystoreDefault",
		"-Pdebug_keystore_alias=androiddebugkey",
		"-Pdebug_keystore_password=android"
	)
}

Push-Location $androidBuildRoot
try {
	& $gradleWrapper @gradleArgs
	if ($LASTEXITCODE -ne 0) {
		throw "Gradle fallback build failed with exit code $LASTEXITCODE."
	}
} finally {
	Pop-Location
}

if (-not (Test-Path $outputApkSourcePath)) {
	throw "Expected Gradle APK output was not found: $outputApkSourcePath"
}

Copy-Item -Path $outputApkSourcePath -Destination $OutputPath -Force
Write-Host "Fallback APK exported to: $OutputPath"
