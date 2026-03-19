# AdMob Setup

## App

- App name: `Territory Conquest Idle`
- Platform: `Android`
- Recorded on: `2026-03-18`
- Package name: `com.hhy0111.territoryconquestidle`
- AdMob app id: `ca-app-pub-4402708884038037~2144372327`
- Consent policy: `UMP enabled`

## Current Integration Status

- Status checked on: `2026-03-20`
- Ad unit ids are recorded and ready to wire into runtime config.
- `scripts/autoload/ad_service.gd` is still a mock stub and does not call a live SDK yet.
- Result reward doubling, revive, reroll reward, and run-end interstitial flows are not wired to production ad requests yet.
- Android export preset, consent runtime flow, and analytics event mapping are still pending.

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
  - trigger: cold app launch or long background resume
  - extra rule: never interrupt active gameplay state

## Still Needed Before SDK Integration

- Test device registration
  - collect after first on-device ad SDK run
- Store privacy configuration
  - decide whether to expose personalized ads consent flow now or later

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
