# Android Bridge Build

This Gradle project builds the `TerritoryConquestAds` Godot Android plugin AAR used by the export addon in the parent folder.

## Prerequisites

- JDK 17
- Android SDK platform 34
- Android build tools installed through Android Studio
- A local Gradle installation or Android Studio import

## Build

From this directory:

```powershell
gradle :plugin:copyAarsToAddon
```

Or from the project root:

```powershell
.\tools\android\build_plugin.ps1
```

Preflight check from the project root:

```powershell
.\tools\android\check_environment.ps1 -Variant Release -RequireGradle -RequireJava -RequireAndroidSdk
```

That builds the debug and release AARs and stages them into:

- `../bin/debug/territory-conquest-ads-debug.aar`
- `../bin/release/territory-conquest-ads-release.aar`

## Notes

- Dependency versions live in `gradle.properties`.
- The bridge exposes the singleton name `TerritoryConquestAds`.
- `show_app_open`, `show_rewarded`, and `show_interstitial` are all asynchronous start requests.
- Rewarded and interstitial completion is delivered through Godot signals, not the `show_*` return value.
- Godot export can be driven through `.\tools\android\export_android.ps1` once Godot and Gradle are available.
- `.\tools\android\android_env.example.ps1` shows the expected environment variable shape for SDK and keystore setup.
