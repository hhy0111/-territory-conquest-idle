param(
	[ValidateSet("Debug", "Release")]
	[string]$Variant = "Release",
	[string]$ApkPath = "",
	[string]$DeviceSerial = "",
	[string]$PackageName = "com.hhy0111.territoryconquestidle",
	[string]$LaunchActivity = "com.godot.game.GodotApp",
	[int]$WarmupSessionCount = 1,
	[int]$ResumeAfterSeconds = 0,
	[int]$ResumeLaunchWaitSeconds = 20,
	[int]$LaunchWaitSeconds = 15,
	[int]$LogTailLines = 200,
	[string]$OutputLogPath = "",
	[switch]$SkipInstall,
	[switch]$AllowSignatureReplace = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_android_tooling.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$sdkRoot = Set-ResolvedAndroidEnvironment
$adbPath = Resolve-AdbPath

if ([string]::IsNullOrWhiteSpace($adbPath)) {
	throw "adb.exe was not found. Install Android platform-tools or set ANDROID_SDK_ROOT."
}

function Resolve-VariantApkPath {
	param(
		[string]$RepoRoot,
		[string]$RequestedVariant
	)

	$candidatePaths = if ($RequestedVariant -eq "Release") {
		@(
			(Join-Path $RepoRoot ".exports\\android\\territory-conquest-idle-release.apk"),
			(Join-Path $RepoRoot ".exports\\android\\territory-conquest-idle-release-fallback.apk")
		)
	} else {
		@(
			(Join-Path $RepoRoot ".exports\\android\\territory-conquest-idle-debug.apk"),
			(Join-Path $RepoRoot ".exports\\android\\territory-conquest-idle-debug-fallback.apk")
		)
	}

	$candidates = @($candidatePaths |
		Where-Object { Test-Path $_ } |
		ForEach-Object { Get-Item $_ } |
		Sort-Object LastWriteTimeUtc -Descending)

	if ($candidates.Count -gt 0) {
		return $candidates[0].FullName
	}

	return ""
}

if ([string]::IsNullOrWhiteSpace($ApkPath)) {
	$ApkPath = Resolve-VariantApkPath -RepoRoot $repoRoot -RequestedVariant $Variant
}

if (-not $SkipInstall -and ([string]::IsNullOrWhiteSpace($ApkPath) -or -not (Test-Path $ApkPath))) {
	throw "APK path was not found for $Variant. Pass -ApkPath or export the APK first."
}

if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
	$DeviceSerial = & $adbPath devices |
		Where-Object { $_ -match '^(emulator-\d+|[A-Za-z0-9._:-]+)\s+device$' } |
		ForEach-Object { ($_ -split '\s+')[0] } |
		Select-Object -First 1
}

if ([string]::IsNullOrWhiteSpace($DeviceSerial)) {
	throw "No connected adb device was found."
}

if ([string]::IsNullOrWhiteSpace($OutputLogPath)) {
	$logDirectory = Join-Path $repoRoot ".exports\\android\\logs"
	if (-not (Test-Path $logDirectory)) {
		New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
	}
	$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
	$OutputLogPath = Join-Path $logDirectory ("android-smoke-{0}-{1}.log" -f $Variant.ToLower(), $timestamp)
}

function Install-ApkForSmoke {
	param(
		[string]$AdbPath,
		[string]$Serial,
		[string]$PackageId,
		[string]$TargetApkPath,
		[bool]$CanReplaceSignature
	)

	$installResult = Invoke-AdbCommand -AdbPath $AdbPath -Arguments @("-s", $Serial, "install", "-r", $TargetApkPath)
	$installExitCode = $installResult.ExitCode
	$installResult.Lines | ForEach-Object { Write-Host $_ }

	if ($installExitCode -eq 0) {
		return
	}

	$combinedInstallOutput = ($installResult.Lines | Out-String)
	if ($CanReplaceSignature -and $combinedInstallOutput.Contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE")) {
		Write-Warning "Existing package signature is incompatible; uninstalling $PackageId and retrying install."
		$uninstallResult = Invoke-AdbCommand -AdbPath $AdbPath -Arguments @("-s", $Serial, "uninstall", $PackageId)
		$uninstallResult.Lines | ForEach-Object { Write-Host $_ }
		if ($uninstallResult.ExitCode -ne 0) {
			throw "adb uninstall failed with exit code $($uninstallResult.ExitCode)."
		}

		$retryResult = Invoke-AdbCommand -AdbPath $AdbPath -Arguments @("-s", $Serial, "install", $TargetApkPath)
		$retryExitCode = $retryResult.ExitCode
		$retryResult.Lines | ForEach-Object { Write-Host $_ }
		if ($retryExitCode -ne 0) {
			throw "adb install retry failed with exit code $retryExitCode."
		}
		return
	}

	throw "adb install failed with exit code $installExitCode."
}

function Invoke-AdbCommand {
	param(
		[string]$AdbPath,
		[string[]]$Arguments
	)

	$tempOutput = [System.IO.Path]::GetTempFileName()
	$tempError = [System.IO.Path]::GetTempFileName()
	try {
		$process = Start-Process -FilePath $AdbPath `
			-ArgumentList $Arguments `
			-NoNewWindow `
			-Wait `
			-PassThru `
			-RedirectStandardOutput $tempOutput `
			-RedirectStandardError $tempError

		$lines = @()
		if (Test-Path $tempOutput) {
			$lines += @(Get-Content -Path $tempOutput)
		}
		if (Test-Path $tempError) {
			$lines += @(Get-Content -Path $tempError)
		}

		return [PSCustomObject]@{
			ExitCode = $process.ExitCode
			Lines = $lines
		}
	} finally {
		if (Test-Path $tempOutput) {
			Remove-Item -Path $tempOutput -Force -ErrorAction SilentlyContinue
		}
		if (Test-Path $tempError) {
			Remove-Item -Path $tempError -Force -ErrorAction SilentlyContinue
		}
	}
}

function Start-AppComponent {
	param(
		[string]$AdbPath,
		[string]$Serial,
		[string]$ComponentName
	)

	$launchResult = Invoke-AdbCommand -AdbPath $AdbPath -Arguments @("-s", $Serial, "shell", "am", "start", "-W", "-n", $ComponentName)
	$launchResult.Lines | ForEach-Object { Write-Host $_ }
	if ($launchResult.ExitCode -ne 0) {
		throw "adb am start failed with exit code $($launchResult.ExitCode)."
	}

	$launchFailure = $launchResult.Lines | Select-String -Pattern @(
		"Error type",
		"Exception occurred",
		"does not exist"
	)
	if ($launchFailure) {
		throw "Android smoke launch failed for component $ComponentName."
	}
}

if (-not $SkipInstall) {
	Write-Host "Installing APK: $ApkPath"
	Install-ApkForSmoke -AdbPath $adbPath -Serial $DeviceSerial -PackageId $PackageName -TargetApkPath $ApkPath -CanReplaceSignature:$AllowSignatureReplace
}

Write-Host "Clearing logcat for $DeviceSerial"
& $adbPath -s $DeviceSerial logcat -c

$launchComponent = "$PackageName/$LaunchActivity"

if ($WarmupSessionCount -lt 1) {
	$WarmupSessionCount = 1
}

for ($sessionIndex = 1; $sessionIndex -le $WarmupSessionCount; $sessionIndex += 1) {
	if ($sessionIndex -gt 1) {
		Write-Host "Force-stopping package before warmup session $sessionIndex"
		$forceStopResult = Invoke-AdbCommand -AdbPath $adbPath -Arguments @("-s", $DeviceSerial, "shell", "am", "force-stop", $PackageName)
		if ($forceStopResult.ExitCode -ne 0) {
			throw "adb force-stop failed with exit code $($forceStopResult.ExitCode)."
		}
	}

	Write-Host "Launching package: $PackageName (session $sessionIndex/$WarmupSessionCount)"
	Start-AppComponent -AdbPath $adbPath -Serial $DeviceSerial -ComponentName $launchComponent
	Start-Sleep -Seconds $LaunchWaitSeconds
}

if ($ResumeAfterSeconds -gt 0) {
	Write-Host "Sending app to HOME before resume wait"
	$homeResult = Invoke-AdbCommand -AdbPath $adbPath -Arguments @("-s", $DeviceSerial, "shell", "input", "keyevent", "KEYCODE_HOME")
	if ($homeResult.ExitCode -ne 0) {
		throw "adb HOME keyevent failed with exit code $($homeResult.ExitCode)."
	}

	Write-Host "Waiting $ResumeAfterSeconds seconds before resume"
	Start-Sleep -Seconds $ResumeAfterSeconds

	Write-Host "Resuming package after background wait"
	Start-AppComponent -AdbPath $adbPath -Serial $DeviceSerial -ComponentName $launchComponent
	Start-Sleep -Seconds $ResumeLaunchWaitSeconds
}

$processIdText = (& $adbPath -s $DeviceSerial shell pidof $PackageName 2>$null | Out-String).Trim()
$logOutput = & $adbPath -s $DeviceSerial logcat -d -t $LogTailLines
$logOutput | Set-Content -Path $OutputLogPath -Encoding utf8

$interestingPatterns = @(
	"Godot",
	"TerritoryConquestAds",
	"Ads",
	[regex]::Escape($PackageName)
)
$highlightedLines = $logOutput | Select-String -Pattern $interestingPatterns

$fatalPatterns = @(
	"Couldn't load project data",
	"Failed to parse runtime config",
	"FATAL EXCEPTION",
	"Project export for preset"
)
$fatalHits = $logOutput | Select-String -Pattern $fatalPatterns

Write-Host "Smoke device: $DeviceSerial"
Write-Host "Smoke package: $PackageName"
Write-Host "Smoke logs: $OutputLogPath"
if (-not [string]::IsNullOrWhiteSpace($processIdText)) {
	Write-Host "Smoke process PID: $processIdText"
} else {
	Write-Warning "Smoke process PID was not found after launch."
}

if ($highlightedLines) {
	Write-Host "Interesting log lines:"
	$highlightedLines | Select-Object -First 40 | ForEach-Object { Write-Host $_.Line }
}

if ($fatalHits) {
	Write-Warning "Fatal log markers detected during smoke run."
	$fatalHits | Select-Object -First 20 | ForEach-Object { Write-Warning $_.Line }
	throw "Android smoke run found fatal markers."
}

if ([string]::IsNullOrWhiteSpace($processIdText)) {
	throw "Android smoke run finished without a running process for $PackageName."
}

Write-Host "Android smoke run passed."
