Set-StrictMode -Version Latest

function Get-EnvValue {
	param([string]$Name)

	$item = Get-Item -Path "Env:$Name" -ErrorAction SilentlyContinue
	if ($item -eq $null) {
		return ""
	}
	return [string]$item.Value
}

function Resolve-CommandPath {
	param([string[]]$Names)

	foreach ($name in $Names) {
		$command = Get-Command $name -ErrorAction SilentlyContinue
		if ($command -ne $null) {
			return $command.Source
		}
	}
	return ""
}

function Resolve-FirstExistingPath {
	param([string[]]$Candidates)

	foreach ($candidate in $Candidates) {
		if ([string]::IsNullOrWhiteSpace($candidate)) {
			continue
		}
		if (Test-Path $candidate) {
			return (Resolve-Path $candidate).Path
		}
	}
	return ""
}

function Test-ExecutablePath {
	param(
		[string]$Path,
		[string[]]$ProbeArguments = @("--version")
	)

	if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path $Path)) {
		return $false
	}

	try {
		$null = & $Path @ProbeArguments 2>&1 | Select-Object -First 1
		return $true
	} catch {
		return $false
	}
}

function Resolve-FirstRunnablePath {
	param(
		[string[]]$Candidates,
		[string[]]$ProbeArguments = @("--version")
	)

	foreach ($candidate in $Candidates) {
		if ([string]::IsNullOrWhiteSpace($candidate)) {
			continue
		}
		if (-not (Test-Path $candidate)) {
			continue
		}
		$resolvedPath = (Resolve-Path $candidate).Path
		if (Test-ExecutablePath -Path $resolvedPath -ProbeArguments $ProbeArguments) {
			return $resolvedPath
		}
	}
	return ""
}

function Resolve-FirstMatch {
	param([string[]]$Patterns)

	foreach ($pattern in $Patterns) {
		if ([string]::IsNullOrWhiteSpace($pattern)) {
			continue
		}
		$match = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | Select-Object -First 1
		if ($match -ne $null) {
			return $match.FullName
		}
	}
	return ""
}

function Resolve-FirstRunnableMatch {
	param(
		[string[]]$Patterns,
		[string[]]$ProbeArguments = @("--version")
	)

	foreach ($pattern in $Patterns) {
		if ([string]::IsNullOrWhiteSpace($pattern)) {
			continue
		}
		$matches = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTimeUtc -Descending
		foreach ($match in $matches) {
			if ($match -eq $null) {
				continue
			}
			if (Test-ExecutablePath -Path $match.FullName -ProbeArguments $ProbeArguments) {
				return $match.FullName
			}
		}
	}
	return ""
}

function Resolve-AndroidSdkRoot {
	$envSdk = Get-EnvValue "ANDROID_SDK_ROOT"
	if (-not [string]::IsNullOrWhiteSpace($envSdk) -and (Test-Path $envSdk)) {
		return (Resolve-Path $envSdk).Path
	}

	$envHome = Get-EnvValue "ANDROID_HOME"
	if (-not [string]::IsNullOrWhiteSpace($envHome) -and (Test-Path $envHome)) {
		return (Resolve-Path $envHome).Path
	}

	$localSdk = Join-Path $env:LOCALAPPDATA "Android\\Sdk"
	if (Test-Path $localSdk) {
		return (Resolve-Path $localSdk).Path
	}

	return ""
}

function Resolve-AndroidSdkToolPath {
	param(
		[string]$RelativePath,
		[string[]]$CommandNames = @()
	)

	$sdkRoot = Resolve-AndroidSdkRoot
	if (-not [string]::IsNullOrWhiteSpace($sdkRoot)) {
		$candidate = Join-Path $sdkRoot $RelativePath
		if (Test-Path $candidate) {
			return (Resolve-Path $candidate).Path
		}
	}

	if ($CommandNames.Count -gt 0) {
		return Resolve-CommandPath $CommandNames
	}
	return ""
}

function Get-JavaMajorVersion {
	param([string]$JavaExecutable)

	if ([string]::IsNullOrWhiteSpace($JavaExecutable) -or -not (Test-Path $JavaExecutable)) {
		return 0
	}

	try {
		$versionOutput = & $JavaExecutable -version 2>&1 | Select-Object -First 1
		if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($versionOutput)) {
			return 0
		}
		if ($versionOutput -match '"(?<major>\d+)(\.\d+)?') {
			return [int]$matches["major"]
		}
	} catch {
	}

	return 0
}

function Resolve-JavaHome {
	param([int]$PreferredMajorVersion = 17)

	$javaHome = Get-EnvValue "JAVA_HOME"
	if (-not [string]::IsNullOrWhiteSpace($javaHome)) {
		$javaExecutable = Join-Path $javaHome "bin\\java.exe"
		if ((Get-JavaMajorVersion $javaExecutable) -eq $PreferredMajorVersion) {
			return (Resolve-Path $javaHome).Path
		}
	}

	$patterns = @(
		"C:\\Program Files\\Eclipse Adoptium\\jdk-$PreferredMajorVersion*",
		"C:\\Program Files\\Java\\jdk-$PreferredMajorVersion*",
		"C:\\Program Files\\Microsoft\\jdk-$PreferredMajorVersion*"
	)
	foreach ($pattern in $patterns) {
		$match = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
		if ($match -ne $null) {
			return $match.FullName
		}
	}

	if (-not [string]::IsNullOrWhiteSpace($javaHome) -and (Test-Path $javaHome)) {
		return (Resolve-Path $javaHome).Path
	}

	$javaCommand = Resolve-CommandPath @("java")
	if (-not [string]::IsNullOrWhiteSpace($javaCommand)) {
		$binDirectory = Split-Path -Parent $javaCommand
		$resolvedHome = Split-Path -Parent $binDirectory
		if (Test-Path $resolvedHome) {
			return (Resolve-Path $resolvedHome).Path
		}
	}

	return ""
}

function Set-ResolvedJavaEnvironment {
	param([int]$PreferredMajorVersion = 17)

	$javaHome = Resolve-JavaHome -PreferredMajorVersion $PreferredMajorVersion
	if (-not [string]::IsNullOrWhiteSpace($javaHome)) {
		$env:JAVA_HOME = $javaHome
		$javaBin = Join-Path $javaHome "bin"
		$pathEntries = @($env:PATH -split ';')
		if ($pathEntries -notcontains $javaBin) {
			$env:PATH = "$javaBin;$env:PATH"
		}
	}
	return $javaHome
}

function Resolve-AdbPath {
	return Resolve-AndroidSdkToolPath -RelativePath "platform-tools\\adb.exe" -CommandNames @("adb")
}

function Resolve-EmulatorPath {
	return Resolve-AndroidSdkToolPath -RelativePath "emulator\\emulator.exe" -CommandNames @("emulator")
}

function Resolve-SdkManagerPath {
	$patterns = @()
	$sdkRoot = Resolve-AndroidSdkRoot
	if (-not [string]::IsNullOrWhiteSpace($sdkRoot)) {
		$patterns += (Join-Path $sdkRoot "cmdline-tools\\*\\bin\\sdkmanager.bat")
	}
	$resolved = Resolve-FirstMatch $patterns
	if (-not [string]::IsNullOrWhiteSpace($resolved)) {
		return $resolved
	}
	return Resolve-CommandPath @("sdkmanager")
}

function Resolve-AvdManagerPath {
	$patterns = @()
	$sdkRoot = Resolve-AndroidSdkRoot
	if (-not [string]::IsNullOrWhiteSpace($sdkRoot)) {
		$patterns += (Join-Path $sdkRoot "cmdline-tools\\*\\bin\\avdmanager.bat")
	}
	$resolved = Resolve-FirstMatch $patterns
	if (-not [string]::IsNullOrWhiteSpace($resolved)) {
		return $resolved
	}
	return Resolve-CommandPath @("avdmanager")
}

function Resolve-GodotPath {
	$repoRoot = ""
	try {
		$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
	} catch {
		$repoRoot = ""
	}

	$envCandidates = @(
		(Get-EnvValue "GODOT_PATH"),
		(Get-EnvValue "CODEX_GODOT_PATH")
	)
	$resolved = Resolve-FirstRunnablePath $envCandidates
	if (-not [string]::IsNullOrWhiteSpace($resolved)) {
		return $resolved
	}

	$commandCandidates = @(
		"godot4",
		"godot",
		"Godot_v4.3-stable_win64_console",
		"Godot_v4.3-stable_win64"
	) | ForEach-Object { Resolve-CommandPath @($_) } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
	$resolved = Resolve-FirstRunnablePath $commandCandidates
	if (-not [string]::IsNullOrWhiteSpace($resolved)) {
		return $resolved
	}

	$exactCandidates = @(
		$(if (-not [string]::IsNullOrWhiteSpace($repoRoot)) { Join-Path $repoRoot ".local\\godot\\Godot_v4.3-stable_win64_console.exe" }),
		$(if (-not [string]::IsNullOrWhiteSpace($repoRoot)) { Join-Path $repoRoot ".local\\godot\\Godot_v4.3-stable_win64.exe" }),
		$(if (-not [string]::IsNullOrWhiteSpace($repoRoot)) { Join-Path $repoRoot ".local\\tools\\godot\\Godot_v4.3-stable_win64_console.exe" }),
		$(if (-not [string]::IsNullOrWhiteSpace($repoRoot)) { Join-Path $repoRoot ".local\\tools\\godot\\Godot_v4.3-stable_win64.exe" }),
		(Join-Path $env:LOCALAPPDATA "Microsoft\\WinGet\\Packages\\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\\Godot_v4.3-stable_win64_console.exe"),
		(Join-Path $env:LOCALAPPDATA "Microsoft\\WinGet\\Packages\\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\\Godot_v4.3-stable_win64.exe"),
		(Join-Path $env:USERPROFILE "Downloads\\Godot_v4.3-stable_win64_console.exe"),
		(Join-Path $env:USERPROFILE "Downloads\\Godot_v4.3-stable_win64.exe"),
		(Join-Path $env:USERPROFILE "Desktop\\Godot_v4.3-stable_win64_console.exe"),
		(Join-Path $env:USERPROFILE "Desktop\\Godot_v4.3-stable_win64.exe"),
		(Join-Path $env:LOCALAPPDATA "Programs\\Godot\\Godot_v4.3-stable_win64_console.exe"),
		(Join-Path $env:LOCALAPPDATA "Programs\\Godot\\Godot_v4.3-stable_win64.exe"),
		"C:\\Program Files\\Godot\\Godot_v4.3-stable_win64_console.exe",
		"C:\\Program Files\\Godot\\Godot_v4.3-stable_win64.exe"
	)
	$resolved = Resolve-FirstRunnablePath $exactCandidates
	if (-not [string]::IsNullOrWhiteSpace($resolved)) {
		return $resolved
	}

	return Resolve-FirstRunnableMatch @(
		$(if (-not [string]::IsNullOrWhiteSpace($repoRoot)) { Join-Path $repoRoot ".local\\godot\\Godot*.exe" }),
		$(if (-not [string]::IsNullOrWhiteSpace($repoRoot)) { Join-Path $repoRoot ".local\\tools\\godot\\Godot*.exe" }),
		(Join-Path $env:USERPROFILE "Downloads\\Godot*.exe"),
		(Join-Path $env:USERPROFILE "Desktop\\Godot*.exe")
	)
}

function Resolve-GradlePath {
	param([string]$WrapperPath = "")

	if (-not [string]::IsNullOrWhiteSpace($WrapperPath) -and (Test-Path $WrapperPath)) {
		return (Resolve-Path $WrapperPath).Path
	}

	$resolved = Resolve-CommandPath @("gradle")
	if (-not [string]::IsNullOrWhiteSpace($resolved)) {
		return $resolved
	}

	$exactCandidates = @(
		"C:\\Gradle\\bin\\gradle.bat",
		(Join-Path $env:USERPROFILE "scoop\\apps\\gradle\\current\\bin\\gradle.bat"),
		(Join-Path $env:ProgramData "chocolatey\\bin\\gradle.bat")
	)
	$resolved = Resolve-FirstExistingPath $exactCandidates
	if (-not [string]::IsNullOrWhiteSpace($resolved)) {
		return $resolved
	}

	return Resolve-FirstMatch @(
		"C:\\Program Files\\Gradle\\*\\bin\\gradle.bat",
		"C:\\Gradle\\*\\bin\\gradle.bat"
	)
}

function Set-ResolvedAndroidEnvironment {
	$sdkRoot = Resolve-AndroidSdkRoot
	if (-not [string]::IsNullOrWhiteSpace($sdkRoot)) {
		if ([string]::IsNullOrWhiteSpace((Get-EnvValue "ANDROID_SDK_ROOT"))) {
			$env:ANDROID_SDK_ROOT = $sdkRoot
		}
		if ([string]::IsNullOrWhiteSpace((Get-EnvValue "ANDROID_HOME"))) {
			$env:ANDROID_HOME = $sdkRoot
		}
	}
	return $sdkRoot
}

function Get-AvailableAvdNames {
	$avdRoot = Join-Path $env:USERPROFILE ".android\\avd"
	if (Test-Path $avdRoot) {
		$names = New-Object System.Collections.Generic.List[string]
		foreach ($entry in Get-ChildItem -Path $avdRoot -Filter "*.ini" -File -ErrorAction SilentlyContinue) {
			$names.Add([System.IO.Path]::GetFileNameWithoutExtension($entry.Name)) | Out-Null
		}
		if ($names.Count -gt 0) {
			return @($names)
		}
	}

	$emulatorPath = Resolve-EmulatorPath
	if (-not [string]::IsNullOrWhiteSpace($emulatorPath)) {
		try {
			$avdNames = & $emulatorPath -list-avds 2>$null
			if ($LASTEXITCODE -eq 0 -and $avdNames) {
				return @($avdNames | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
			}
		} catch {
		}
	}

	return @()
}
