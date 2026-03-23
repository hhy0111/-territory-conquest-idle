param(
	[string]$TemplateVersion = "4.3.stable",
	[string]$AndroidSourcePath = "",
	[switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$androidRoot = Join-Path $repoRoot "android"
$buildRoot = Join-Path $androidRoot "build"
$buildVersionPath = Join-Path $androidRoot ".build_version"
$gdIgnorePath = Join-Path $buildRoot ".gdignore"

if ([string]::IsNullOrWhiteSpace($AndroidSourcePath)) {
	$AndroidSourcePath = Join-Path $env:APPDATA ("Godot\\export_templates\\{0}\\android_source.zip" -f $TemplateVersion)
}

if (-not (Test-Path $AndroidSourcePath)) {
	throw "android_source.zip was not found: $AndroidSourcePath"
}

New-Item -ItemType Directory -Path $androidRoot -Force | Out-Null

if (Test-Path $buildRoot) {
	if (-not $Force) {
		throw "android/build already exists. Re-run with -Force to replace it."
	}
	Remove-Item -Recurse -Force $buildRoot
}

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
Expand-Archive -Path $AndroidSourcePath -DestinationPath $buildRoot -Force
[System.IO.File]::WriteAllText($buildVersionPath, $TemplateVersion + "`n", [System.Text.UTF8Encoding]::new($false))
if (-not (Test-Path $gdIgnorePath)) {
	[System.IO.File]::WriteAllText($gdIgnorePath, "", [System.Text.UTF8Encoding]::new($false))
}

Write-Host "Installed Android build template to: $buildRoot"
Write-Host "Recorded build version at: $buildVersionPath"
