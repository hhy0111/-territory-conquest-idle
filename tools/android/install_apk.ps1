param(
	[string]$ApkPath = "",
	[string]$DeviceSerial = ""
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

if ([string]::IsNullOrWhiteSpace($ApkPath)) {
	$candidates = @(
		(Join-Path $repoRoot ".exports\\android\\territory-conquest-idle-release.apk"),
		(Join-Path $repoRoot ".exports\\android\\territory-conquest-idle-release-fallback.apk"),
		(Join-Path $repoRoot ".exports\\android\\territory-conquest-idle-debug.apk"),
		(Join-Path $repoRoot ".exports\\android\\territory-conquest-idle-debug-fallback.apk")
	) | Where-Object { Test-Path $_ } |
		ForEach-Object { Get-Item $_ } |
		Sort-Object LastWriteTimeUtc -Descending

	if ($candidates.Count -gt 0) {
		$ApkPath = $candidates[0].FullName
	}
}

if ([string]::IsNullOrWhiteSpace($ApkPath) -or -not (Test-Path $ApkPath)) {
	throw "APK path was not found. Pass -ApkPath or export an APK under .exports\\android first."
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

Write-Host "Installing APK: $ApkPath"
Write-Host "Target device: $DeviceSerial"

& $adbPath -s $DeviceSerial install -r $ApkPath
if ($LASTEXITCODE -ne 0) {
	throw "adb install failed with exit code $LASTEXITCODE."
}
