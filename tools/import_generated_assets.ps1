param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$SourceDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "image")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

python (Join-Path $PSScriptRoot "import_generated_assets.py") --project-root $ProjectRoot --source-dir $SourceDir
exit $LASTEXITCODE
