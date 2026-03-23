param(
	[ValidateSet("Draft", "Submission")]
	[string]$Mode = "Draft"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path

$requiredFiles = @(
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

$failed = $false

function Fail-Check {
	param([string]$Message)
	Write-Error $Message
	$script:failed = $true
}

function Warn-Check {
	param([string]$Message)
	Write-Warning $Message
}

function Test-BlankAnswerCell {
	param([string]$Content)

	$lines = $Content -split "`r?`n"
	foreach ($line in $lines) {
		$trimmed = $line.Trim()
		if (-not ($trimmed.StartsWith("|") -and $trimmed.EndsWith("|"))) {
			continue
		}
		if ($trimmed.StartsWith("| ---")) {
			continue
		}

		$cells = @($trimmed.Split("|") | ForEach-Object { $_.Trim() })
		if ($cells.Count -lt 4) {
			continue
		}

		$answerCell = $cells[2]
		if ([string]::IsNullOrWhiteSpace($answerCell)) {
			return $true
		}
	}

	return $false
}

foreach ($relativePath in $requiredFiles) {
	$fullPath = Join-Path $repoRoot $relativePath
	if (-not (Test-Path $fullPath)) {
		Fail-Check "Missing release document: $relativePath"
		continue
	}
	Write-Host "[OK] $relativePath"
}

$inputDocs = @(
	"release\\01_user_answers_accounts_and_signing.md",
	"release\\02_user_answers_ads_privacy_and_policy.md",
	"release\\03_user_answers_store_listing.md",
	"release\\04_user_answers_launch_ops_and_support.md"
)

foreach ($relativePath in $inputDocs) {
	$fullPath = Join-Path $repoRoot $relativePath
	if (-not (Test-Path $fullPath)) {
		continue
	}

	$content = Get-Content -Path $fullPath -Raw -Encoding UTF8
	$statusMatch = [regex]::Match($content, 'status:\s*`(?<status>[^`]+)`')
	if (-not $statusMatch.Success) {
		Fail-Check "Missing status marker in $relativePath"
		continue
	}

	$status = $statusMatch.Groups["status"].Value
	switch ($Mode) {
		"Draft" {
			if ($status -eq "pending") {
				Fail-Check "Draft release doc still marked pending: $relativePath"
			}
		}
		"Submission" {
			if ($status -ne "confirmed") {
				Fail-Check "Submission mode requires confirmed status: $relativePath"
			}
		}
	}

	if (Test-BlankAnswerCell -Content $content) {
		Fail-Check "Blank answer cell found in $relativePath"
	}

	if ($Mode -eq "Submission") {
		$submissionMarkers = @(
			"Assumed:",
			"Draft",
			"not_prepared",
			"in_progress",
			"REPLACE_WITH_REAL_",
			"to be hosted",
			"actual hosting url",
			"actual support email"
		)
		foreach ($marker in $submissionMarkers) {
			if ($content.Contains($marker)) {
				Fail-Check "Submission doc still contains draft marker '$marker': $relativePath"
			}
		}
	}
}

$privacyPolicyPath = Join-Path $repoRoot "release\\privacy_policy_draft.md"
if (Test-Path $privacyPolicyPath) {
	$privacyContent = Get-Content -Path $privacyPolicyPath -Raw -Encoding UTF8
	if ($Mode -eq "Submission" -and $privacyContent.Contains("REPLACE_WITH_REAL_")) {
		Fail-Check "Privacy policy draft still contains unreplaced contact placeholders."
	} elseif ($privacyContent.Contains("REPLACE_WITH_REAL_")) {
		Warn-Check "Privacy policy draft still has contact placeholders."
	}
}

if ($failed) {
	exit 1
}

Write-Host "Release document check passed in $Mode mode."
