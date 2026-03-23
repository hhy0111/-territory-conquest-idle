param(
	[string]$KeystorePath = "",
	[string]$Alias = "territoryconquestlocal",
	[string]$Password = "territoryconquestlocal",
	[string]$DistinguishedName = "CN=Territory Conquest Local QA, OU=Development, O=HHY0111, L=Seoul, S=Seoul, C=KR",
	[switch]$Overwrite,
	[switch]$WriteEnvScript
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_android_tooling.ps1")

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
$localAndroidRoot = Join-Path $repoRoot ".local\\android"
$envScriptPath = Join-Path $localAndroidRoot "use_local_release_keystore.ps1"

if ([string]::IsNullOrWhiteSpace($KeystorePath)) {
	$KeystorePath = Join-Path $localAndroidRoot "territory-conquest-local-release.keystore"
}

$javaHome = Set-ResolvedJavaEnvironment -PreferredMajorVersion 17
if ([string]::IsNullOrWhiteSpace($javaHome)) {
	throw "JDK 17 was not found. Install Temurin 17 or set JAVA_HOME to a JDK 17 path."
}

$keytoolPath = Join-Path $javaHome "bin\\keytool.exe"
if (-not (Test-Path $keytoolPath)) {
	throw "keytool.exe was not found under: $javaHome"
}

$keystoreDirectory = Split-Path -Parent $KeystorePath
if (-not (Test-Path $keystoreDirectory)) {
	New-Item -ItemType Directory -Path $keystoreDirectory -Force | Out-Null
}

if ((Test-Path $KeystorePath) -and -not $Overwrite) {
	Write-Host "Local release keystore already exists: $KeystorePath"
} else {
	if ((Test-Path $KeystorePath) -and $Overwrite) {
		Remove-Item -Path $KeystorePath -Force
	}

	& $keytoolPath -genkeypair `
		-v `
		-keystore $KeystorePath `
		-storepass $Password `
		-keypass $Password `
		-alias $Alias `
		-keyalg RSA `
		-keysize 2048 `
		-validity 10000 `
		-dname $DistinguishedName

	if ($LASTEXITCODE -ne 0) {
		throw "keytool failed with exit code $LASTEXITCODE."
	}
}

if ($WriteEnvScript -or -not (Test-Path $envScriptPath)) {
	$envScriptContent = @(
		('$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH="{0}"' -f $KeystorePath.Replace('\', '\\')),
		('$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER="{0}"' -f $Alias),
		('$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="{0}"' -f $Password)
	)
	Set-Content -Path $envScriptPath -Value $envScriptContent -Encoding ascii
	Write-Host "Local release env script: $envScriptPath"
}

Write-Host "Local release keystore: $KeystorePath"
Write-Host "Release alias: $Alias"
