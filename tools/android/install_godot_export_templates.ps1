param(
	[string]$ReleaseTag = "4.3-stable",
	[string]$TemplateVersion = "4.3.stable",
	[string]$DownloadUrl = "",
	[switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($DownloadUrl)) {
	$DownloadUrl = "https://github.com/godotengine/godot/releases/download/{0}/Godot_v{0}_export_templates.tpz" -f $ReleaseTag
}

$templatesRoot = Join-Path $env:APPDATA "Godot\\export_templates"
$targetDir = Join-Path $templatesRoot $TemplateVersion
$androidSourcePath = Join-Path $targetDir "android_source.zip"
$tempRoot = Join-Path $env:TEMP "godot-export-templates-$ReleaseTag"
$archivePath = Join-Path $tempRoot ("Godot_v{0}_export_templates.tpz" -f $ReleaseTag)
$archiveZipPath = Join-Path $tempRoot ("Godot_v{0}_export_templates.zip" -f $ReleaseTag)
$extractDir = Join-Path $tempRoot "extract"

if ((Test-Path $androidSourcePath) -and -not $Force) {
	Write-Host "Templates already installed: $targetDir"
	return
}

New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
New-Item -ItemType Directory -Path $templatesRoot -Force | Out-Null

if (-not (Test-Path $archivePath) -or $Force) {
	Write-Host "Downloading: $DownloadUrl"
	$curlPath = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source
	if (-not [string]::IsNullOrWhiteSpace($curlPath)) {
		& $curlPath -L --fail --retry 5 --output $archivePath $DownloadUrl
		if ($LASTEXITCODE -ne 0) {
			throw "curl download failed with exit code $LASTEXITCODE."
		}
	} else {
		Invoke-WebRequest -Uri $DownloadUrl -OutFile $archivePath
	}
} else {
	Write-Host "Using cached archive: $archivePath"
}

if (Test-Path $extractDir) {
	Remove-Item -Recurse -Force $extractDir
}
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

Write-Host "Extracting templates..."
Copy-Item -Path $archivePath -Destination $archiveZipPath -Force
Expand-Archive -Path $archiveZipPath -DestinationPath $extractDir -Force

if (Test-Path $targetDir) {
	Remove-Item -Recurse -Force $targetDir
}
New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

$sourceDir = $extractDir
$nestedVersionDir = Join-Path $extractDir $TemplateVersion
if (Test-Path $nestedVersionDir) {
	$sourceDir = $nestedVersionDir
}
$nestedTemplatesDir = Join-Path $sourceDir "templates"
if (Test-Path $nestedTemplatesDir) {
	$sourceDir = $nestedTemplatesDir
}

Copy-Item -Path (Join-Path $sourceDir "*") -Destination $targetDir -Recurse -Force

if (-not (Test-Path $androidSourcePath)) {
	throw "android_source.zip was not found after template extraction: $androidSourcePath"
}

Write-Host "Installed templates to: $targetDir"
