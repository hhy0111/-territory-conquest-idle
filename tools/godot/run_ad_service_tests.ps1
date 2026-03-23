param(
	[string]$GodotPath = "",
	[string]$ScriptPath = "res://tests/ad_service_runner.gd",
	[switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "..\\android\\resolve_android_tooling.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path

if ([string]::IsNullOrWhiteSpace($GodotPath)) {
	$GodotPath = Resolve-GodotPath
}
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
	throw "Godot executable was not found. Pass -GodotPath or add Godot to PATH."
}

$arguments = @("--headless", "--path", $repoRoot)
if ($Verbose) {
	$arguments += "--verbose"
}
$arguments += @("-s", $ScriptPath)

Write-Host "Godot: $GodotPath"
Write-Host "Script: $ScriptPath"

& $GodotPath @arguments
if ($LASTEXITCODE -ne 0) {
	throw "Godot ad-service test runner failed with exit code $LASTEXITCODE."
}

