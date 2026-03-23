# Territory Conquest Idle Project Status

Last reviewed: `2026-03-23`

이 문서는 현재 저장소 기준 구현 진행상황, 검증 결과, 문서 위치, 남은 작업을 한 번에 확인하기 위한 상태 문서다.

## Document Map

- `agent.md`
  - 전체 설계, 시스템 규칙, MVP 범위, 확장 로드맵, 개발 원칙
- `project_status.md`
  - 현재 구현 상태, 검증 결과, 문서 커버리지, 우선순위 작업
- `admob_setup.md`
  - Android AdMob 앱 ID, 슬롯 ID, UMP 체크리스트, 광고 슬롯 매핑
- `asset_import_report.md`
  - 초기 자산 임포트 스냅샷, 중복 사용, 리뷰 대기 원본, placeholder 이력
- `asset_regeneration_list.md`
  - 현재 기준 재생성 완료 항목과 남은 리뷰 대기 원본 목록
- `image_prompts.md`
  - 메인 이미지 프롬프트 모음
- `asset_regeneration_prompts.md`
  - 재생성에 사용한 프롬프트 모음
- `release/README.md`
  - 출시 전 사용자 답변 문서 인덱스와 프리릴리스 검증 스크립트 진입점
- `release/pre_release_status.md`
  - 현재 기준 프리릴리스 완료 항목, 외부 블로커, 완료 정의
- `release/store_listing_draft.md`
  - 스토어 메타데이터와 스크린샷 촬영 계획 초안
- `release/privacy_policy_draft.md`
  - 배포 전 호스팅할 개인정보 처리방침 초안
- `release/data_safety_draft.md`
  - Play Console Data safety 응답 초안
- `tools/release/generate_release_artifacts.ps1`
  - 릴리스용 JSON/HTML 초안 산출물 생성기
- `tools/release/prepare_release_bundle.ps1`
  - 문서와 generated 아티팩트를 묶는 release bundle 생성기

## Current Implementation Snapshot

### Core Loop

- 홈 -> 런 -> 전투 -> 결과 -> 메타 흐름이 연결되어 있다.
- 저장/로드와 활성 런 복구가 구현되어 있다.
- 시드 기반 맵 생성, 타일 해상도, 이벤트 해상도, 자동 전투 해상도, 보스 보상, 유물 선택, 런 업그레이드 선택이 구현되어 있다.
- 결과 화면에 전투/경제/영토/빌드 요약이 출력된다.
- 광고 서비스는 오토로드로 등록되어 있으며 mock fallback, QA override, Android bridge hook을 함께 지원한다.
- `rewarded_revive`, `rewarded_double_run_reward`, `rewarded_bonus_reroll`, `interstitial_run_end`, `app_open_launch` 흐름이 런타임 설정과 UI 게이트에 연결되어 있다.
- First prototype boss prep now uses a pending-combat player snapshot and a small `Frontline Rally` heal before the fight.

### Playable Screens

- `Home`
- `Run`
- `Combat`
- `Relic Choice`
- `Run Upgrade`
- `Result`
- `Meta`

### Content Counts

- Tiles: `11`
- Enemies: `8`
- Events: `12`
- Relics: `14`
- Run upgrades: `24`
- Meta upgrades: `18`
- Bosses: `5`

### Current Scope Note

- 현재 런은 장기 밸런스 버전이 아니라 프로토타입 길이에 맞춰 압축되어 있다.
- 현재 클리어 조건은 `11 captures` 기준이다.
- 보스 진입도 `prototype_gate` 기준으로 `6 / 9 / 12 / 15 / 18` 캡처에서 동작한다.

## Verification Status

검증 기준일: `2026-03-23`

- Source review
  - `pass`
  - 핵심 루프, 저장/복구, 광고 게이트, 테스트/시뮬레이션 엔트리 연결 상태를 코드 기준으로 재확인했다.
- Runtime verification in current shell
  - `pass`
  - `tools/android/resolve_android_tooling.ps1`가 패키지된 Godot 바이너리를 WinGet 링크보다 먼저 해석하도록 수정한 뒤, 현재 셸에서 headless 검증 명령을 직접 재실행했다.
- UI smoke in current shell
  - `pending`
  - 현재 셸에서는 GUI 기반 수동 smoke를 다시 돌리지 않았다.

## Verification Addendum (`2026-03-23`)

- Current-shell headless harness: `pass`
- Command used: `tools/godot/run_tests.ps1`
- Resolver fix: `tools/android/resolve_android_tooling.ps1`
- Unit test harness: `pass`
- Android bridge AAR build: `pass`
- Plugin build command: `tools/android/build_plugin.ps1 -Variant All`
- Staged outputs: `addons/territory_conquest_ads/bin/debug/territory-conquest-ads-debug.aar`, `addons/territory_conquest_ads/bin/release/territory-conquest-ads-release.aar`
- Release fallback export: `pass`
- Export command: `tools/android/export_android_gradle_fallback.ps1 -Variant Release`
- Exported APK: `.exports/android/territory-conquest-idle-release-fallback.apk`
- Release emulator smoke: `pass`
- Smoke command: `tools/android/run_android_smoke.ps1 -Variant Release -ApkPath ./.exports/android/territory-conquest-idle-release-fallback.apk -WarmupSessionCount 2 -ResumeAfterSeconds 185`
- Smoke log: `.exports/android/logs/android-smoke-release-20260323-112111.log`
- Seeded run simulation batch: `pass` (`50` automated runs)
- Balance report tool: `tools/godot/run_simulation_report.ps1`
- Starting commander baseline: `120 HP / 14 ATK / 7 ARM`
- Latest balance report: default `5 / 50` wins, meta `9 / 50` wins, default average captures `7.06`, meta average captures `8.56`

## Documentation Coverage Check

### Already Documented

- 전체 게임 설계와 MVP/로드맵: `agent.md`
- AdMob 앱/슬롯 정보와 UMP 작업 목록: `admob_setup.md`
- 자산 임포트 및 재생성 이력: `asset_import_report.md`, `asset_regeneration_list.md`
- 이미지 생성 프롬프트: `image_prompts.md`, `asset_regeneration_prompts.md`
- 출시 전 사용자 응답 문서와 프리릴리스 상태 진입점: `release/README.md`, `release/pre_release_status.md`
- 스토어/정책 제출 초안: `release/store_listing_draft.md`, `release/privacy_policy_draft.md`, `release/data_safety_draft.md`
- 릴리스 산출물 생성 스크립트: `tools/release/generate_release_artifacts.ps1`, `tools/release/prepare_release_bundle.ps1`

### Was Missing Before This Update

- 현재 구현 상태를 한 장에서 보는 진행현황 문서
- 각 문서가 무엇을 담당하는지 설명하는 진입점
- 검증 결과와 남은 작업 우선순위를 문서로 고정한 항목

## Remaining Work

- `release/01_user_answers_accounts_and_signing.md` 부터 `release/04_user_answers_launch_ops_and_support.md`까지 사용자 응답 항목 확정
- `tools/release/check_release_docs.ps1 -Mode Submission` 기준 초안 마커 제거 및 확정 상태 반영
- 접근 가능한 Godot 바이너리 경로 또는 GUI 가능한 환경에서 `tools/release/run_pre_release_checks.ps1` 재실행
- GUI 가능한 환경에서 홈/런/전투/결과/메타 화면 UI smoke를 다시 돌려 현재 시각 피드백 상태를 확정
- 실제 Android 기기에서 consent, app-open, rewarded, interstitial 콜백 경로 QA
- QA용 release keystore를 production release signing으로 교체하고 스토어 제출용 설정을 정리
- MVP 목표 대비 부족한 콘텐츠 보강
  - Content counts reached: Events `12`, Run upgrades `24`, Meta upgrades `18`
- 프로토타입 캡처 페이싱을 목표 런 길이 기준으로 재조정할지 결정하고 밸런스 패스 진행

## Asset Status

- 자산 재요청이 필요한 항목은 현재 없다.
- 다만 `review_pending` 원본 7개는 아직 정리 대상이다.
- placeholder 이력과 중복 원본 사용 이력은 `asset_import_report.md`를 기준 문서로 유지한다.

## Maintenance Rule

- 기능 구현 범위가 바뀌면 먼저 이 문서를 갱신한다.
- 설계가 바뀌면 `agent.md`를 갱신한다.
- 광고 계정/슬롯/정책이 바뀌면 `admob_setup.md`를 갱신한다.
- 자산 교체가 발생하면 `asset_import_report.md`와 `asset_regeneration_list.md`를 같이 갱신한다.
