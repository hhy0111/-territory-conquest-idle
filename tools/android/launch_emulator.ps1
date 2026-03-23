param(
	[string]$AvdName = "",
	[switch]$ListAvds,
	[switch]$NoBootWait,
	[switch]$ColdBoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "resolve_android_tooling.ps1")

$sdkRoot = Set-ResolvedAndroidEnvironment
$emulatorPath = Resolve-EmulatorPath
$adbPath = Resolve-AdbPath

if ([string]::IsNullOrWhiteSpace($emulatorPath)) {
	throw "Android emulator.exe was not found. Install the Android Emulator package or set ANDROID_SDK_ROOT."
}
if ([string]::IsNullOrWhiteSpace($adbPath)) {
	throw "adb.exe was not found. Install Android platform-tools or set ANDROID_SDK_ROOT."
}

$availableAvds = @(Get-AvailableAvdNames)
if ($ListAvds) {
	if ($availableAvds.Count -eq 0) {
		Write-Host "No AVDs were found."
		return
	}
	foreach ($name in $availableAvds) {
		Write-Host $name
	}
	return
}

if ($availableAvds.Count -eq 0) {
	throw "No Android Virtual Devices were found under $env:USERPROFILE\\.android\\avd."
}

if ([string]::IsNullOrWhiteSpace($AvdName)) {
	if ($availableAvds -contains "Pixel_7_API_35") {
		$AvdName = "Pixel_7_API_35"
	} else {
		$AvdName = $availableAvds[0]
	}
}

if ($availableAvds -notcontains $AvdName) {
	throw "AVD '$AvdName' was not found. Available AVDs: $($availableAvds -join ', ')"
}

$arguments = New-Object System.Collections.Generic.List[string]
$arguments.Add("-avd") | Out-Null
$arguments.Add($AvdName) | Out-Null
$arguments.Add("-netdelay") | Out-Null
$arguments.Add("none") | Out-Null
$arguments.Add("-netspeed") | Out-Null
$arguments.Add("full") | Out-Null
if ($ColdBoot) {
	$arguments.Add("-no-snapshot-load") | Out-Null
}

Write-Host "Launching AVD: $AvdName"
$process = Start-Process -FilePath $emulatorPath -ArgumentList $arguments -PassThru

if ($NoBootWait) {
	Write-Host "Emulator PID: $($process.Id)"
	return
}

$deadline = (Get-Date).AddMinutes(6)
$deviceSerial = ""

while ((Get-Date) -lt $deadline) {
	Start-Sleep -Seconds 5
	$deviceSerial = & $adbPath devices |
		Where-Object { $_ -match '^emulator-\d+\s+device$' } |
		ForEach-Object { ($_ -split '\s+')[0] } |
		Select-Object -First 1
	if (-not [string]::IsNullOrWhiteSpace($deviceSerial)) {
		break
	}
}

if ([string]::IsNullOrWhiteSpace($deviceSerial)) {
	throw "Emulator process started, but no emulator device became available through adb within 6 minutes."
}

Write-Host "ADB device: $deviceSerial"

while ((Get-Date) -lt $deadline) {
	Start-Sleep -Seconds 5
	$bootCompleted = (& $adbPath -s $deviceSerial shell getprop sys.boot_completed 2>$null | Out-String).Trim()
	if ($bootCompleted -eq "1") {
		Write-Host "Emulator boot completed."
		return
	}
}

throw "Emulator '$AvdName' connected as $deviceSerial, but sys.boot_completed did not reach 1 within 6 minutes."
