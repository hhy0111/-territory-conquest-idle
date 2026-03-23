param(
	[ValidateSet("Draft", "Submission")]
	[string]$Mode = "Draft",
	[string]$OutputDir = "",
	[switch]$IncludeApk,
	[switch]$Zip
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$generateArtifactsScript = Join-Path $repoRoot "tools\\release\\generate_release_artifacts.ps1"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
	$OutputDir = Join-Path $repoRoot ".exports\\release_bundle"
}

$generatedDir = Join-Path $OutputDir "generated"
$docsDir = Join-Path $OutputDir "docs"
$androidDir = Join-Path $OutputDir "android"

Remove-Item -Path $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $OutputDir, $generatedDir, $docsDir | Out-Null

& $generateArtifactsScript -Mode $Mode -OutputDir $generatedDir

$docFiles = @(
	"release\\README.md",
	"release\\pre_release_status.md",
	"release\\01_user_answers_accounts_and_signing.md",
	"release\\02_user_answers_ads_privacy_and_policy.md",
	"release\\03_user_answers_store_listing.md",
	"release\\04_user_answers_launch_ops_and_support.md",
	"release\\store_listing_draft.md",
	"release\\privacy_policy_draft.md",
	"release\\data_safety_draft.md"
)

foreach ($relativePath in $docFiles) {
	$sourcePath = Join-Path $repoRoot $relativePath
	if (Test-Path $sourcePath) {
		Copy-Item -Path $sourcePath -Destination $docsDir -Force
	}
}

if ($IncludeApk) {
	New-Item -ItemType Directory -Force -Path $androidDir | Out-Null
	$apkCandidates = @(
		Join-Path $repoRoot ".exports\\android\\territory-conquest-idle-release.apk",
		Join-Path $repoRoot ".exports\\android\\territory-conquest-idle-release-fallback.apk",
		Join-Path $repoRoot ".exports\\android\\territory-conquest-idle-debug.apk",
		Join-Path $repoRoot ".exports\\android\\territory-conquest-idle-debug-fallback.apk"
	) | Where-Object { Test-Path $_ }

	foreach ($apkPath in $apkCandidates) {
		Copy-Item -Path $apkPath -Destination $androidDir -Force
	}
}

$bundleReadmePath = Join-Path $OutputDir "README.txt"
@"
Release bundle generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Mode: $Mode

Contents:
- docs/
- generated/
$(if ($IncludeApk) { "- android/" } else { "" })

Primary entrypoints:
- docs\pre_release_status.md
- generated\release_manifest.json
- generated\store_listing_draft.json
- generated\privacy_policy_draft.html
"@ | Set-Content -Path $bundleReadmePath -Encoding UTF8

if ($Zip) {
	$zipPath = "$OutputDir.zip"
	Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
	Compress-Archive -Path (Join-Path $OutputDir "*") -DestinationPath $zipPath
	Write-Host "Prepared zipped release bundle: $zipPath"
	return
}

Write-Host "Prepared release bundle: $OutputDir"

