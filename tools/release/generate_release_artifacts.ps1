param(
	[ValidateSet("Draft", "Submission")]
	[string]$Mode = "Draft",
	[string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$checkReleaseDocsScript = Join-Path $repoRoot "tools\\release\\check_release_docs.ps1"

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
	$OutputDir = Join-Path $repoRoot ".exports\\release_artifacts"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

& $checkReleaseDocsScript -Mode $Mode

function Get-IniValue {
	param(
		[string]$Path,
		[string]$Section,
		[string]$Key
	)

	$currentSection = ""
	foreach ($line in Get-Content -Path $Path -Encoding UTF8) {
		$trimmed = $line.Trim()
		if ($trimmed -match '^\[(.+)\]$') {
			$currentSection = $matches[1]
			continue
		}
		if ($currentSection -ne $Section) {
			continue
		}
		if ($trimmed -match ('^{0}="?(.*?)"?$' -f [regex]::Escape($Key))) {
			return $matches[1]
		}
	}
	return ""
}

function Get-MarkdownSectionLines {
	param(
		[string]$Path,
		[string]$Heading
	)

	$lines = Get-Content -Path $Path -Encoding UTF8
	$result = New-Object System.Collections.Generic.List[string]
	$capturing = $false
	foreach ($line in $lines) {
		if ($line -eq $Heading) {
			$capturing = $true
			continue
		}
		if ($capturing -and $line -match '^## ') {
			break
		}
		if ($capturing) {
			$result.Add($line) | Out-Null
		}
	}
	return @($result)
}

function Get-FirstParagraph {
	param([string[]]$Lines)

	$parts = New-Object System.Collections.Generic.List[string]
	foreach ($line in $Lines) {
		$trimmed = $line.Trim()
		if ([string]::IsNullOrWhiteSpace($trimmed)) {
			if ($parts.Count -gt 0) {
				break
			}
			continue
		}
		if ($trimmed.StartsWith("- ") -or $trimmed -match '^\d+\. ') {
			continue
		}
		$parts.Add($trimmed) | Out-Null
	}
	return ($parts -join " ").Trim()
}

function Get-BulletItems {
	param([string[]]$Lines)

	$items = New-Object System.Collections.Generic.List[string]
	foreach ($line in $Lines) {
		$trimmed = $line.Trim()
		if ($trimmed.StartsWith("- ")) {
			$items.Add($trimmed.Substring(2).Trim()) | Out-Null
		}
	}
	return @($items)
}

function Get-OrderedItems {
	param([string[]]$Lines)

	$items = New-Object System.Collections.Generic.List[string]
	foreach ($line in $Lines) {
		$trimmed = $line.Trim()
		if ($trimmed -match '^\d+\.\s+(.*)$') {
			$items.Add($matches[1].Trim()) | Out-Null
		}
	}
	return @($items)
}

function Convert-MarkdownToHtml {
	param(
		[string]$MarkdownPath,
		[string]$Title
	)

	$lines = Get-Content -Path $MarkdownPath -Encoding UTF8
	$html = New-Object System.Collections.Generic.List[string]
	$inUl = $false
	$inOl = $false

	$closeLists = {
		param(
			[System.Collections.Generic.List[string]]$Html,
			[ref]$InUl,
			[ref]$InOl
		)

		if ($InUl.Value) {
			$Html.Add("</ul>") | Out-Null
			$InUl.Value = $false
		}
		if ($InOl.Value) {
			$Html.Add("</ol>") | Out-Null
			$InOl.Value = $false
		}
	}

	$html.Add("<!doctype html>") | Out-Null
	$html.Add("<html lang=`"en`">") | Out-Null
	$html.Add("<head>") | Out-Null
	$html.Add("  <meta charset=`"utf-8`">") | Out-Null
	$html.Add("  <meta name=`"viewport`" content=`"width=device-width, initial-scale=1`">") | Out-Null
	$html.Add(("  <title>{0}</title>" -f [System.Net.WebUtility]::HtmlEncode($Title))) | Out-Null
	$html.Add("  <style>body{font-family:Segoe UI,Arial,sans-serif;max-width:900px;margin:40px auto;padding:0 20px;line-height:1.6;color:#1f2937}h1,h2,h3{color:#111827}code{background:#f3f4f6;padding:2px 4px;border-radius:4px}ul,ol{padding-left:24px}</style>") | Out-Null
	$html.Add("</head>") | Out-Null
	$html.Add("<body>") | Out-Null

	foreach ($line in $lines) {
		$trimmed = $line.Trim()
		if ([string]::IsNullOrWhiteSpace($trimmed)) {
			& $closeLists $html ([ref]$inUl) ([ref]$inOl)
			continue
		}

		if ($trimmed -match '^(#+)\s+(.*)$') {
			& $closeLists $html ([ref]$inUl) ([ref]$inOl)
			$level = [Math]::Min($matches[1].Length, 3)
			$text = [System.Net.WebUtility]::HtmlEncode($matches[2])
			$html.Add(("<h{0}>{1}</h{0}>" -f $level, $text)) | Out-Null
			continue
		}

		if ($trimmed.StartsWith("- ")) {
			if (-not $inUl) {
				& $closeLists $html ([ref]$inUl) ([ref]$inOl)
				$html.Add("<ul>") | Out-Null
				$inUl = $true
			}
			$text = [System.Net.WebUtility]::HtmlEncode($trimmed.Substring(2).Trim())
			$html.Add(("<li>{0}</li>" -f $text)) | Out-Null
			continue
		}

		if ($trimmed -match '^\d+\.\s+(.*)$') {
			if (-not $inOl) {
				& $closeLists $html ([ref]$inUl) ([ref]$inOl)
				$html.Add("<ol>") | Out-Null
				$inOl = $true
			}
			$text = [System.Net.WebUtility]::HtmlEncode($matches[1].Trim())
			$html.Add(("<li>{0}</li>" -f $text)) | Out-Null
			continue
		}

		& $closeLists $html ([ref]$inUl) ([ref]$inOl)
		$text = [System.Net.WebUtility]::HtmlEncode($trimmed)
		$text = $text -replace '`([^`]+)`', '<code>$1</code>'
		$html.Add(("<p>{0}</p>" -f $text)) | Out-Null
	}

	& $closeLists $html ([ref]$inUl) ([ref]$inOl)
	$html.Add("</body>") | Out-Null
	$html.Add("</html>") | Out-Null
	return ($html -join [Environment]::NewLine)
}

function Get-ReleaseDocStatus {
	param([string]$Path)

	$content = Get-Content -Path $Path -Raw -Encoding UTF8
	$match = [regex]::Match($content, 'status:\s*`(?<status>[^`]+)`')
	if ($match.Success) {
		return $match.Groups["status"].Value
	}
	return "unknown"
}

$projectPath = Join-Path $repoRoot "project.godot"
$exportPresetPath = Join-Path $repoRoot "export_presets.cfg"
$adRuntimePath = Join-Path $repoRoot "data\\ad_runtime.json"
$storeDraftPath = Join-Path $repoRoot "release\\store_listing_draft.md"
$privacyDraftPath = Join-Path $repoRoot "release\\privacy_policy_draft.md"
$dataSafetyDraftPath = Join-Path $repoRoot "release\\data_safety_draft.md"

$appName = Get-IniValue -Path $projectPath -Section "application" -Key "config/name"
$mainScene = Get-IniValue -Path $projectPath -Section "application" -Key "run/main_scene"
$orientation = Get-IniValue -Path $projectPath -Section "display" -Key "window/handheld/orientation"
$releaseVersionCode = Get-IniValue -Path $exportPresetPath -Section "preset.1.options" -Key "version/code"
$releaseVersionName = Get-IniValue -Path $exportPresetPath -Section "preset.1.options" -Key "version/name"
$packageName = Get-IniValue -Path $exportPresetPath -Section "preset.1.options" -Key "package/unique_name"
$packageDisplayName = Get-IniValue -Path $exportPresetPath -Section "preset.1.options" -Key "package/name"
$minSdk = Get-IniValue -Path $exportPresetPath -Section "preset.1.options" -Key "gradle_build/min_sdk"
$targetSdk = Get-IniValue -Path $exportPresetPath -Section "preset.1.options" -Key "gradle_build/target_sdk"
$appCategory = Get-IniValue -Path $exportPresetPath -Section "preset.1.options" -Key "package/app_category"
$adRuntime = Get-Content -Path $adRuntimePath -Raw -Encoding UTF8 | ConvertFrom-Json

$shortDescription = Get-FirstParagraph (Get-MarkdownSectionLines -Path $storeDraftPath -Heading "## Short Description")
$fullDescription = (Get-MarkdownSectionLines -Path $storeDraftPath -Heading "## Full Description" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join [Environment]::NewLine
$keywords = Get-BulletItems (Get-MarkdownSectionLines -Path $storeDraftPath -Heading "## Keywords")
$screenshotPlan = Get-OrderedItems (Get-MarkdownSectionLines -Path $storeDraftPath -Heading "## Screenshot Plan")
$promoCopy = Get-BulletItems (Get-MarkdownSectionLines -Path $storeDraftPath -Heading "## Optional Promo Copy")

$docStatuses = [ordered]@{
	accounts_and_signing = Get-ReleaseDocStatus (Join-Path $repoRoot "release\\01_user_answers_accounts_and_signing.md")
	ads_privacy_and_policy = Get-ReleaseDocStatus (Join-Path $repoRoot "release\\02_user_answers_ads_privacy_and_policy.md")
	store_listing = Get-ReleaseDocStatus (Join-Path $repoRoot "release\\03_user_answers_store_listing.md")
	launch_ops_and_support = Get-ReleaseDocStatus (Join-Path $repoRoot "release\\04_user_answers_launch_ops_and_support.md")
}

$manifest = [ordered]@{
	generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
	mode = $Mode
	app = [ordered]@{
		name = $appName
		main_scene = $mainScene
		orientation = $orientation
		package_name = $packageName
		package_display_name = $packageDisplayName
		version_name = $releaseVersionName
		version_code = [int]$releaseVersionCode
		min_sdk = [int]$minSdk
		target_sdk = [int]$targetSdk
		app_category = $appCategory
	}
	ads = [ordered]@{
		android_app_id = [string]$adRuntime.platforms.android.app_id
		consent_enabled = [bool]$adRuntime.platforms.android.consent_enabled
		bridge_singleton = [string]$adRuntime.platforms.android.bridge_singleton
		slots = $adRuntime.slots
	}
	release_doc_status = $docStatuses
	source_docs = @(
		"release/README.md",
		"release/pre_release_status.md",
		"release/store_listing_draft.md",
		"release/privacy_policy_draft.md",
		"release/data_safety_draft.md"
	)
}

$storeListing = [ordered]@{
	app_name = $appName
	package_name = $packageName
	category = "Strategy"
	primary_language = "English"
	monetization = "Ads"
	target_orientation = "Portrait"
	short_description = $shortDescription
	full_description = $fullDescription
	keywords = $keywords
	screenshot_plan = $screenshotPlan
	optional_promo_copy = $promoCopy
}

$dataSafety = [ordered]@{
	generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
	mode = $Mode
	data_types = [ordered]@{
		app_activity = [ordered]@{
			collected = $true
			shared = $true
			purposes = @("advertising", "fraud_prevention_security")
		}
		device_or_other_identifiers = [ordered]@{
			collected = $true
			shared = $true
			purposes = @("advertising", "consent_compliance")
		}
		personal_info = [ordered]@{
			collected = $false
			shared = $false
		}
		financial_info = [ordered]@{
			collected = $false
			shared = $false
		}
		location = [ordered]@{
			collected = $false
			shared = $false
		}
	}
	notes = @(
		"Gameplay progress is stored locally on-device.",
		"No production analytics backend is wired in the current repository state.",
		"Advertising data handling depends on Android ad SDK and consent flow."
	)
}

$privacyHtml = Convert-MarkdownToHtml -MarkdownPath $privacyDraftPath -Title "$appName Privacy Policy Draft"
$storeHtml = Convert-MarkdownToHtml -MarkdownPath $storeDraftPath -Title "$appName Store Listing Draft"

$manifestPath = Join-Path $OutputDir "release_manifest.json"
$storeJsonPath = Join-Path $OutputDir "store_listing_draft.json"
$dataSafetyJsonPath = Join-Path $OutputDir "data_safety_draft.json"
$privacyHtmlPath = Join-Path $OutputDir "privacy_policy_draft.html"
$storeHtmlPath = Join-Path $OutputDir "store_listing_draft.html"
$readmePath = Join-Path $OutputDir "README.txt"

($manifest | ConvertTo-Json -Depth 20) | Set-Content -Path $manifestPath -Encoding UTF8
($storeListing | ConvertTo-Json -Depth 20) | Set-Content -Path $storeJsonPath -Encoding UTF8
($dataSafety | ConvertTo-Json -Depth 20) | Set-Content -Path $dataSafetyJsonPath -Encoding UTF8
$privacyHtml | Set-Content -Path $privacyHtmlPath -Encoding UTF8
$storeHtml | Set-Content -Path $storeHtmlPath -Encoding UTF8

@"
Release artifacts generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Mode: $Mode

Included files:
- release_manifest.json
- store_listing_draft.json
- data_safety_draft.json
- privacy_policy_draft.html
- store_listing_draft.html
"@ | Set-Content -Path $readmePath -Encoding UTF8

Write-Host "Generated release artifacts in: $OutputDir"
