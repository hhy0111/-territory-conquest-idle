param(
	[string]$GodotPath = "",
	[int]$DefaultBatchCount = 50,
	[int]$MetaBatchCount = 50,
	[int]$MaxSteps = 256,
	[string]$OutputPath = "",
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

$scenePath = "res://tests/run_simulation_report.tscn"
$arguments = @("--headless", "--path", $repoRoot)
if ($Verbose) {
	$arguments += "--verbose"
}
$arguments += $scenePath

$env:SIM_DEFAULT_BATCH_COUNT = [string]$DefaultBatchCount
$env:SIM_META_BATCH_COUNT = [string]$MetaBatchCount
$env:SIM_MAX_STEPS = [string]$MaxSteps

Write-Host "Godot: $GodotPath"
Write-Host "Scene: $scenePath"
Write-Host "Config: default=$DefaultBatchCount meta=$MetaBatchCount max_steps=$MaxSteps"

$outputLines = & $GodotPath @arguments 2>&1 | ForEach-Object { $_.ToString() }
$exitCode = $LASTEXITCODE
foreach ($line in $outputLines) {
	Write-Host $line
}
if ($exitCode -ne 0) {
	throw "Godot simulation report scene failed with exit code $exitCode."
}

$reportLine = $outputLines | Where-Object { $_ -like "SIM_REPORT_JSON=*" } | Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($reportLine)) {
	throw "Simulation report JSON marker was not found in Godot output."
}

$reportJson = $reportLine.Substring("SIM_REPORT_JSON=".Length)
$report = $reportJson | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
	$reportDirectory = Join-Path $repoRoot ".reports\\godot"
	New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
	$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
	$OutputPath = Join-Path $reportDirectory "simulation-report-$timestamp.json"
} else {
	$outputDirectory = Split-Path -Parent $OutputPath
	if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
		New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
	}
}

Set-Content -Path $OutputPath -Value $reportJson -Encoding UTF8

function Get-CountEntries {
	param([object]$Counts)

	if ($null -eq $Counts) {
		return @()
	}

	$entries = @()
	foreach ($property in $Counts.PSObject.Properties) {
		$entries += [pscustomobject]@{
			Name = [string]$property.Name
			Count = [int]$property.Value
		}
	}
	return $entries | Sort-Object Count, Name -Descending
}

function Format-TopCounts {
	param(
		[object]$Counts,
		[int]$Limit = 5
	)

	$entries = @(Get-CountEntries $Counts | Select-Object -First $Limit)
	if ($entries.Count -eq 0) {
		return "none"
	}
	return ($entries | ForEach-Object { "{0} ({1})" -f $_.Name, $_.Count }) -join ", "
}

function Write-BatchSummary {
	param(
		[string]$Label,
		[object]$Batch
	)

	$aggregate = $Batch.aggregate
	Write-Host ("[{0}] wins={1}/{2} avg_captures={3:N2} max_captures={4} avg_bosses={5:N2}" -f `
		$Label,
		[int]$aggregate.victories,
		[int]$aggregate.ended_runs,
		[double]$aggregate.average_captures,
		[int]$aggregate.max_captures,
		[double]$aggregate.average_bosses_defeated
	)
	Write-Host ("[{0}] top events: {1}" -f $Label, (Format-TopCounts $aggregate.event_counts 5))
	Write-Host ("[{0}] top event choices: {1}" -f $Label, (Format-TopCounts $aggregate.event_choice_counts 5))
	Write-Host ("[{0}] top relics: {1}" -f $Label, (Format-TopCounts $aggregate.relic_pick_counts 5))
	Write-Host ("[{0}] top run upgrades: {1}" -f $Label, (Format-TopCounts $aggregate.run_upgrade_pick_counts 5))
}

Write-BatchSummary "default" $report.batches.default
Write-BatchSummary "meta" $report.batches.meta
Write-Host "Saved report: $OutputPath"
