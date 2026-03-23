# Territory Conquest Ads Android Plugin

This addon is a Godot 4.2+ Android v2 export-plugin scaffold for the `TerritoryConquestAds` bridge singleton expected by `scripts/autoload/ad_service.gd`.

What it already does:

- Registers a Godot editor plugin through `plugin.cfg`.
- Adds Android Maven dependencies from `data/ad_runtime.json`.
- Injects the AdMob app id into the exported Android manifest.
- Exposes stable AAR drop locations for debug and release builds.
- Includes an Android Gradle project at `addons/territory_conquest_ads/android` that builds the `TerritoryConquestAds` bridge AAR.
- Ships Android export preset scaffolds in `export_presets.cfg` and helper scripts under `tools/android`.

What it does not do yet:

- It does not include a prebuilt Android AAR checked into `bin/`.
- If the AAR is missing, the game keeps using the mock ad flow on Android.
- It has not been validated on a physical Android device from this workspace.

Expected workflow:

1. Enable this addon in `Project -> Project Settings -> Plugins`.
2. Install the Android build template in Godot.
3. Create an Android export preset.
4. In the Android export preset, enable `Use Gradle Build`.
5. Build the Android bridge from `addons/territory_conquest_ads/android`.
6. Place or confirm the Android plugin AAR files in:
   - `addons/territory_conquest_ads/bin/debug/territory-conquest-ads-debug.aar`
   - `addons/territory_conquest_ads/bin/release/territory-conquest-ads-release.aar`
7. Run `tools/android/export_android.ps1` or export through the Godot editor once keystore values are configured.
8. Use `tools/android/check_environment.ps1` if you need a fast preflight report before build/export.

Expected Android bridge methods:

- `configure_runtime(runtime_json: String)`
- `request_consent() -> bool`
- `show_app_open(slot_key: String, unit_id: String) -> bool`
- `show_rewarded(slot_key: String, unit_id: String) -> bool`
- `show_interstitial(slot_key: String, unit_id: String) -> bool`
- `show_*` should only report whether the request started; completion is delivered through bridge signals.

Expected Android bridge signals:

- `consent_result(status: String, detail: String)`
- `app_open_closed(slot_key: String)`
- `app_open_failed(slot_key: String, reason: String)`
- `rewarded_completed(slot_key: String)`
- `rewarded_failed(slot_key: String, reason: String)`
- `interstitial_closed(slot_key: String)`
- `interstitial_failed(slot_key: String, reason: String)`
