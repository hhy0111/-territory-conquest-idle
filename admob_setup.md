# AdMob Setup

## App

- App name: `Territory Conquest Idle`
- Platform: `Android`
- Recorded on: `2026-03-18`
- Package name: `com.hhy0111.territoryconquestidle`
- AdMob app id: `ca-app-pub-4402708884038037~2144372327`
- Consent policy: `UMP enabled`

## Current Integration Status

- Status checked on: `2026-03-23`
- Ad unit ids are recorded and ready to wire into runtime config.
- `data/ad_runtime.json` now stores Android app id, slot ids, consent flag, bridge singleton name, and the app-open resume threshold.
- `scripts/autoload/ad_service.gd` now reads runtime config, exposes a bridge hook, and still falls back to the mock flow when no Android singleton is present.
- `scripts/app/main.gd` now saves on app background, discards stale runs after a 30 minute background gap, and attempts `app_open_launch` on cold start or after a long background resume when the Android bridge is active, no run is active, and the player is on session 2 or later.
- Home input stays gated while a queued app-open request waits on consent and until the app-open ad closes or fails.
- Rewarded and interstitial flows now resolve asynchronously, and in-game rewards/navigation only apply after the ad close or reward callback arrives.
- `scripts/autoload/analytics_service.gd` now records consent/show/failure ad events for QA and later SDK mapping.
- `scripts/autoload/ad_service.gd` now supports QA-only forced consent and per-slot outcome overrides, so ad callback success/failure paths can be simulated without live ad fill.
- `addons/territory_conquest_ads` now provides a Godot Android v2 export-plugin scaffold for manifest injection and Maven dependency wiring.
- `addons/territory_conquest_ads/android` now contains the native Android bridge source project for `TerritoryConquestAds`, including UMP request flow, ad preload/show handling, and bridge signals.
- `export_presets.cfg` now includes Android Debug and Android Release preset scaffolds, and `tools/android` now contains helper scripts for plugin build and Godot export.
- `tools/android/export_android_gradle_fallback.ps1` is now verified end-to-end for the debug path: `Godot --export-pack`, asset staging into `android/build/assets`, Gradle assemble, signed APK output, emulator install, and app launch.
- `tools/android/export_android_gradle_fallback.ps1` is now also reverified for the release path after rebuilding the plugin AARs, producing a fresh fallback APK without manual Godot path overrides.
- `tools/android/export_android.ps1` now supports `-UseGradleFallback` and `-FallbackOnFailure` so the fallback route can be used without switching scripts manually.
- Release fallback export is now verified with a local QA-only release keystore, and the resulting APK preserves the intended package name and app label.
- `tools/android/run_android_smoke.ps1` now automates install, launch, log capture, signature-mismatch recovery, multi-session warmup, and long background resume smoke runs on the emulator.
- `tools/android/run_android_smoke.ps1` is now reverified against the fresh release fallback APK after the 2026-03-23 plugin rebuild/export pass.
- `tools/godot/run_tests.ps1` now runs the project-backed `tests/test_harness.tscn` entrypoint, which is the working headless path for the current test suite.
- `tools/godot/run_ad_service_tests.ps1` now runs the isolated `tests/ad_service_runner.gd` entrypoint for the AdService suite.
- `tools/godot/run_ui_smoke.ps1` now runs the `tests/ui_smoke_harness.tscn` scene as a dedicated UI smoke entrypoint.
- `tools/release/check_release_docs.ps1` now validates release-input docs and draft-policy assets in `Draft` or `Submission` mode.
- `tools/release/generate_release_artifacts.ps1` now emits JSON/HTML release draft outputs from the current repo state.
- `tools/release/prepare_release_bundle.ps1` now assembles release docs and generated outputs into a handoff bundle.
- `tools/release/run_pre_release_checks.ps1` now chains core tests, AdService tests, UI smoke, simulation reports, and optional Android preflight/export/smoke into one release-readiness command.
- The headless harness now exits cleanly after the `SaveService` test frees its temporary node instance.
- Result reward doubling, revive, reroll, and run-end interstitial flows are wired to mock ad requests.
- `interstitial_run_end` gating is implemented in-app, the native bridge source exists, and debug/release AAR build plus addon staging are now verified.
- Production release keystore handoff and real-device ad QA are still pending.

## Registered Ad Units

| Slot Key | Format | Ad Unit ID | In-Game Usage |
| --- | --- | --- | --- |
| `app_open_launch` | `App Open` | `ca-app-pub-4402708884038037/8456964387` | Cold start or long background return loading gate only |
| `interstitial_run_end` | `Interstitial` | `ca-app-pub-4402708884038037/8437750689` | After result flow ends or on return to home under gating rules |
| `rewarded_bonus_reroll` | `Rewarded` | `ca-app-pub-4402708884038037/7699384083` | One reroll reward for relic, run upgrade, or event choice flow |
| `rewarded_double_run_reward` | `Rewarded` | `ca-app-pub-4402708884038037/5585456719` | Result screen reward multiplier, doubles essence only |
| `rewarded_revive` | `Rewarded` | `ca-app-pub-4402708884038037/1017458066` | One revive per run on defeat, disabled during final boss second phase |

## Runtime Mapping

- `rewarded_revive`
  - trigger: player defeat
  - reward: restore `50 percent HP`
  - extra rule: remove `10 danger`
- `rewarded_double_run_reward`
  - trigger: result screen reward panel
  - reward: double `essence`
  - extra rule: do not double `sigils`
- `rewarded_bonus_reroll`
  - trigger: relic choice, run upgrade choice, or approved event choice reroll
  - reward: `1 reroll`
  - extra rule: cap by per-run gating rule
- `interstitial_run_end`
  - trigger: after result claim or when returning to home
  - extra rule: do not show during combat, boss intro, event choice, or upgrade choice
- `app_open_launch`
  - trigger: cold app launch or long background resume after `180 seconds`
  - extra rule: never interrupt active gameplay state

## Runtime Config Files

- `data/ad_runtime.json`
  - runtime app id, slot ids, consent toggle, app-open resume threshold, analytics event keys, and QA override config
- `scripts/autoload/ad_service.gd`
  - runtime loader, mock fallback, Android bridge singleton adapter, and QA override layer for forced consent/slot outcomes
- `scripts/autoload/analytics_service.gd`
  - QA-facing analytics event recorder used before production analytics SDK wiring
- `addons/territory_conquest_ads`
  - Godot Android v2 export plugin scaffold
- `addons/territory_conquest_ads/android`
  - Gradle Android library project that builds the `TerritoryConquestAds` singleton AAR
- `export_presets.cfg`
  - Android Debug and Android Release export preset scaffold with Gradle build enabled
- `tools/android/build_plugin.ps1`
  - wrapper script for building and staging the Android bridge AAR
- `tools/android/export_android.ps1`
  - wrapper script for Godot Android export once Gradle and Godot are available, with optional fallback to the Gradle-based export-pack workflow
- `tools/android/export_android_gradle_fallback.ps1`
  - fallback exporter that uses `--export-pack`, stages the exported project data into `android/build/assets`, rewrites the Android app label resources, and produces an APK through Gradle
- `tools/android/check_environment.ps1`
  - preflight checker for Godot, Gradle, Java, Android SDK, `adb`, emulator, AAR presence, and signing inputs
- `tools/android/resolve_android_tooling.ps1`
  - shared resolver that auto-detects local Android SDK, `adb`, emulator, Gradle, and common Godot install paths
- `tools/android/launch_emulator.ps1`
  - starts a named AVD, or lists available AVDs, and waits for Android boot completion
- `tools/android/install_apk.ps1`
  - installs the newest exported APK onto the first connected adb device or a specified serial, including fallback APK outputs
- `tools/android/generate_local_release_keystore.ps1`
  - creates a local QA-only release keystore under `.local/android` and can emit a matching environment script for release export validation
- `tools/android/run_android_smoke.ps1`
  - installs and launches the selected APK, captures logcat, can recover from debug/release signature mismatch, and can simulate multi-session warmup plus long background resume
- `tools/godot/run_tests.ps1`
  - runs the headless Godot test harness scene (`tests/test_harness.tscn`) through the locally resolved Godot executable
- `tools/godot/run_ad_service_tests.ps1`
  - runs the dedicated AdService SceneTree runner (`tests/ad_service_runner.gd`) through the locally resolved Godot executable
- `tools/godot/run_ui_smoke.ps1`
  - runs the UI smoke scene (`tests/ui_smoke_harness.tscn`) through the locally resolved Godot executable
- `tools/release/run_pre_release_checks.ps1`
  - chains the Godot verification scripts with optional Android preflight/export/smoke for pre-release signoff
- `tools/release/check_release_docs.ps1`
  - validates required release docs, status markers, blank answers, and unresolved draft placeholders
- `tools/release/generate_release_artifacts.ps1`
  - generates draft release manifest, store listing JSON, data safety JSON, and publishable HTML outputs
- `tools/release/prepare_release_bundle.ps1`
  - assembles docs and generated outputs into a release bundle folder, optionally including APKs
- `tools/android/android_env.example.ps1`
  - example environment variable file for Android SDK and Godot keystore exports

## Android Build Requirements

- Minimum SDK: `23`
- Java: `JDK 17`
- Google Mobile Ads SDK: `com.google.android.gms:play-services-ads:24.9.0`
- UMP SDK: `com.google.android.ump:user-messaging-platform:4.0.0`

## Verified Debug Build Loop

- Verified on: `2026-03-21`
- Emulator: `Pixel_7_API_35`
- Export output: `.exports/android/territory-conquest-idle-debug-fallback.apk`
- Result: debug APK built, installed, and launched on the emulator through the fallback path
- Recommended command sequence:
  - `.\tools\android\export_android.ps1 -Variant Debug -FallbackOnFailure`
  - `.\tools\android\launch_emulator.ps1`
  - `.\tools\android\install_apk.ps1`

## Local Release QA Keystore

- Local QA-only release signing can now be generated without touching production keys.
- Generate the local keystore:
  - `.\tools\android\generate_local_release_keystore.ps1 -WriteEnvScript`
- Load the generated signing environment into the current shell:
  - `. .\.local\android\use_local_release_keystore.ps1`
- Then build the release APK through the same export entrypoint:
  - `.\tools\android\export_android.ps1 -Variant Release -FallbackOnFailure`
- Do not ship with this keystore. Replace it with the real release keystore before store submission.

## Verified Release Build Loop

- Verified on: `2026-03-21`
- Signing mode: `local QA-only release keystore`
- Export output: `.exports/android/territory-conquest-idle-release.apk`
- Result: release APK built successfully through the fallback path and passed `apksigner verify --print-certs`
- Verified APK metadata:
  - package: `com.hhy0111.territoryconquestidle`
  - label: `Territory Conquest Idle`

## Verified Release Emulator Smoke

- Verified on: `2026-03-22`
- Device: `emulator-5554`
- Script: `.\tools\android\run_android_smoke.ps1 -Variant Release -WarmupSessionCount 2 -ResumeAfterSeconds 185`
- Result: install, cold launch, second-session launch, `HOME` background, long resume, and live process check all passed
- Smoke log: `.exports/android/logs/android-smoke-release-20260322-082418.log`
- Note: the current emulator log did not surface explicit `TerritoryConquestAds` app-open callback lines, so real-device ad QA is still required for ad callback validation

## Verified Release Fallback Export Revalidation

- Verified on: `2026-03-23`
- Script: `.\tools\android\export_android_gradle_fallback.ps1 -Variant Release`
- Signing mode: `local QA-only release keystore`
- Result: fresh release fallback APK built successfully after rebuilding the plugin AARs
- Export output: `.exports/android/territory-conquest-idle-release-fallback.apk`

## Verified Release Fallback Emulator Smoke

- Verified on: `2026-03-23`
- Device: `emulator-5554`
- Script: `.\tools\android\run_android_smoke.ps1 -Variant Release -ApkPath .\.exports\android\territory-conquest-idle-release-fallback.apk -WarmupSessionCount 2 -ResumeAfterSeconds 185`
- Result: install, two-session launch cycle, `HOME` background, long resume, and live process check all passed against the freshly exported fallback APK
- Smoke log: `.exports/android/logs/android-smoke-release-20260323-112111.log`
- Note: the emulator smoke still validates lifecycle and packaging, but real-device ad callback QA remains required

## Verified Headless Test Harness

- Verified on: `2026-03-22`
- Script: `.\tools\godot\run_tests.ps1`
- Scene: `res://tests/test_harness.tscn`
- Result: `All tests passed.`
- Exit state: clean, with no `ObjectDB` leak warning and no lingering resource warning

## Verified Plugin AAR Build

- Verified on: `2026-03-23`
- Script: `.\tools\android\build_plugin.ps1 -Variant All`
- Preconditions: `.\tools\android\check_environment.ps1 -Variant Release -RequireGradle -RequireJava -RequireAndroidSdk`
- Result: Gradle completed successfully and copied fresh debug/release AAR outputs into the Godot addon staging path
- Verified staged outputs:
  - `addons/territory_conquest_ads/bin/debug/territory-conquest-ads-debug.aar`
  - `addons/territory_conquest_ads/bin/release/territory-conquest-ads-release.aar`

## Expected Android Bridge Contract

- Singleton name
  - `TerritoryConquestAds`
- Methods
  - `configure_runtime(runtime_json: String)`
  - `request_consent() -> bool`
  - `show_app_open(slot_key: String, unit_id: String) -> bool`
  - `show_rewarded(slot_key: String, unit_id: String) -> bool`
  - `show_interstitial(slot_key: String, unit_id: String) -> bool`
  - `show_*` returns whether the request started; reward grant and navigation resume only after the bridge signal arrives.
- Signals
  - `consent_result(status: String, detail: String)`
  - `app_open_closed(slot_key: String)`
  - `app_open_failed(slot_key: String, reason: String)`
  - `rewarded_completed(slot_key: String)`
  - `rewarded_failed(slot_key: String, reason: String)`
  - `interstitial_closed(slot_key: String)`
  - `interstitial_failed(slot_key: String, reason: String)`

## Still Needed Before Release Validation

- User-owned release inputs
  - fill `release/01_user_answers_accounts_and_signing.md` through `release/04_user_answers_launch_ops_and_support.md`
- Test device registration
  - collect after first on-device ad SDK run
- Store privacy configuration
  - decide whether to expose personalized ads consent flow now or later
- Release signing
  - use `generate_local_release_keystore.ps1` only for QA, then replace it with the real release keystore before shipping
- On-device QA
  - verify consent flow, cold-start app-open, long-background resume app-open, rewarded completion, interstitial close, and failure signal paths on a real device
- Environment preflight
  - run `.\tools\android\check_environment.ps1 -Variant Release -RequireGodot -RequireJava -RequireAndroidSdk -RequireAdb -RequireEmulator -RequireReleaseSigning` before build/export

## UMP Integration Tasks

1. Add Google Mobile Ads SDK and UMP dependency to the Android build path used by the Godot AdMob bridge.
2. Request consent info on app launch before the first production ad load.
3. If required, load and present the UMP consent form.
4. Cache consent state and only initialize ad requests after consent flow completes.
5. Keep test-device mode enabled during development to avoid invalid traffic risk.
6. Log consent result, ad load result, reward grant result, and ad failure reason for QA.

## Recommended Code Keys

- `rewarded_revive`
- `rewarded_double_run_reward`
- `rewarded_bonus_reroll`
- `interstitial_run_end`
- `app_open_launch`
