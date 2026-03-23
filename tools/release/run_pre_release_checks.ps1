param(
	[string]$GodotPath = "",
	[ValidateSet("Debug", "Release")]
	[string]$Variant = "Release",
	[int]$DefaultBatchCount = 50,
	[int]$MetaBatchCount = 50,
	[int]$MaxSteps = 256,
	[string]$ApkPath = "",
	[string]$DeviceSerial = "",
	[int]$WarmupSessionCount = 2,
	[int]$ResumeAfterSeconds = 185,
	[switch]$DocsOnly,
	[switch]$SkipGodotChecks,
	[switch]$IncludeAndroidPreflight,
	[switch]$ExportReleaseApk,
	[switch]$RunAndroidSmoke,
	[switch]$UseGradleFallback,
	[switch]$Verbose
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$checkReleaseDocsScript = Join-Path $repoRoot "tools\\release\\check_release_docs.ps1"
$runTestsScript = Join-Path $repoRoot "tools\\godot\\run_tests.ps1"
$runAdServiceTestsScript = Join-Path $repoRoot "tools\\godot\\run_ad_service_tests.ps1"
$runUiSmokeScript = Join-Path $repoRoot "tools\\godot\\run_ui_smoke.ps1"
$runSimulationReportScript = Join-Path $repoRoot "tools\\godot\\run_simulation_report.ps1"
$androidCheckScript = Join-Path $repoRoot "tools\\android\\check_environment.ps1"
$androidExportScript = Join-Path $repoRoot "tools\\android\\export_android.ps1"
$androidSmokeScript = Join-Path $repoRoot "tools\\android\\run_android_smoke.ps1"

function Invoke-Step {
	param(
		[string]$Name,
		[scriptblock]$Action
	)

	Write-Host ""
	Write-Host ("== {0} ==" -f $Name)
	& $Action
}

Invoke-Step "Release document checks" {
	& $checkReleaseDocsScript -Mode Draft
}

if (-not $DocsOnly) {
	if (-not $SkipGodotChecks) {
		Invoke-Step "Core Godot tests" {
			$args = @{
				ScenePath = "res://tests/test_harness.tscn"
			}
			if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
				$args.GodotPath = $GodotPath
			}
			if ($Verbose) {
				$args.Verbose = $true
			}
			& $runTestsScript @args
		}

		Invoke-Step "AdService tests" {
			$args = @{}
			if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
				$args.GodotPath = $GodotPath
			}
			if ($Verbose) {
				$args.Verbose = $true
			}
			& $runAdServiceTestsScript @args
		}

		Invoke-Step "UI smoke" {
			$args = @{}
			if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
				$args.GodotPath = $GodotPath
			}
			if ($Verbose) {
				$args.Verbose = $true
			}
			& $runUiSmokeScript @args
		}

		Invoke-Step "Simulation report" {
			$args = @{
				DefaultBatchCount = $DefaultBatchCount
				MetaBatchCount = $MetaBatchCount
				MaxSteps = $MaxSteps
			}
			if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
				$args.GodotPath = $GodotPath
			}
			if ($Verbose) {
				$args.Verbose = $true
			}
			& $runSimulationReportScript @args
		}
	} else {
		Write-Host ""
		Write-Host "== Godot checks skipped =="
	}
}

if ($IncludeAndroidPreflight -or $ExportReleaseApk -or $RunAndroidSmoke) {
	Invoke-Step "Android preflight" {
		$args = @{
			Variant = $Variant
			RequireJava = $true
			RequireAndroidSdk = $true
		}
		if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
			$args.GodotPath = $GodotPath
		}
		if ($ExportReleaseApk) {
			$args.RequireGodot = $true
			$args.RequireAar = $true
			if ($Variant -eq "Release") {
				$args.RequireReleaseSigning = $true
			}
		}
		if ($RunAndroidSmoke) {
			$args.RequireAdb = $true
		}
		& $androidCheckScript @args
	}
}

if ($ExportReleaseApk) {
	Invoke-Step "Android export" {
		$args = @{
			Variant = $Variant
			BuildPlugin = $true
			FallbackOnFailure = $true
		}
		if ($UseGradleFallback) {
			$args.UseGradleFallback = $true
		}
		if (-not [string]::IsNullOrWhiteSpace($GodotPath)) {
			$args.GodotPath = $GodotPath
		}
		& $androidExportScript @args
	}
}

if ($RunAndroidSmoke) {
	Invoke-Step "Android smoke" {
		$args = @{
			Variant = $Variant
			WarmupSessionCount = $WarmupSessionCount
			ResumeAfterSeconds = $ResumeAfterSeconds
		}
		if (-not [string]::IsNullOrWhiteSpace($ApkPath)) {
			$args.ApkPath = $ApkPath
		}
		if (-not [string]::IsNullOrWhiteSpace($DeviceSerial)) {
			$args.DeviceSerial = $DeviceSerial
		}
		& $androidSmokeScript @args
	}
}

Write-Host ""
Write-Host "Pre-release verification completed."
