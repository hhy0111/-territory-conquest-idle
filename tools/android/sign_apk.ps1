param(
	[string]$ApkPath = "",
	[string]$OutputPath = "",
	[string]$KeystorePath = "",
	[string]$KeyAlias = "androiddebugkey",
	[string]$KeystorePassword = "android",
	[string]$KeyPassword = "android"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_android_tooling.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$sdkRoot = Set-ResolvedAndroidEnvironment
if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
	throw "ANDROID_SDK_ROOT was not found."
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
if (-not (Test-Path $ApkPath)) {
	throw "APK path was not found: $ApkPath"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	$apkDirectory = Split-Path -Parent $ApkPath
	$apkName = [System.IO.Path]::GetFileNameWithoutExtension($ApkPath)
	$OutputPath = Join-Path $apkDirectory ($apkName + "-signed.apk")
}

if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
	$KeystorePath = Join-Path $env:APPDATA "Godot\\keystores\\debug.keystore"
}
if (-not (Test-Path $KeystorePath)) {
	throw "Keystore was not found: $KeystorePath"
}

$buildToolsRoot = Join-Path $sdkRoot "build-tools"
$apksignerPath = Get-ChildItem -Path $buildToolsRoot -Filter "apksigner.bat" -Recurse -File -ErrorAction SilentlyContinue |
	Sort-Object FullName -Descending |
	Select-Object -First 1 -ExpandProperty FullName

if ([string]::IsNullOrWhiteSpace($apksignerPath)) {
	throw "apksigner.bat was not found under: $buildToolsRoot"
}

Copy-Item -Path $ApkPath -Destination $OutputPath -Force

& $apksignerPath sign `
	--ks $KeystorePath `
	--ks-key-alias $KeyAlias `
	--ks-pass ("pass:" + $KeystorePassword) `
	--key-pass ("pass:" + $KeyPassword) `
	$OutputPath

if ($LASTEXITCODE -ne 0) {
	throw "apksigner sign failed with exit code $LASTEXITCODE."
}

& $apksignerPath verify $OutputPath
if ($LASTEXITCODE -ne 0) {
	throw "apksigner verify failed with exit code $LASTEXITCODE."
}

Write-Host "Signed APK: $OutputPath"
