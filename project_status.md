# Territory Conquest Idle Project Status

Last reviewed: `2026-03-20`

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

## Current Implementation Snapshot

### Core Loop

- 홈 -> 런 -> 전투 -> 결과 -> 메타 흐름이 연결되어 있다.
- 저장/로드와 활성 런 복구가 구현되어 있다.
- 시드 기반 맵 생성, 타일 해상도, 이벤트 해상도, 자동 전투 해상도, 보스 보상, 유물 선택, 런 업그레이드 선택이 구현되어 있다.
- 결과 화면에 전투/경제/영토/빌드 요약이 출력된다.
- 광고 서비스는 오토로드로 등록되어 있지만 현재는 에디터 안전용 스텁 상태다.

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
- Events: `9`
- Relics: `14`
- Run upgrades: `18`
- Meta upgrades: `12`
- Bosses: `5`

### Current Scope Note

- 현재 런은 장기 밸런스 버전이 아니라 프로토타입 길이에 맞춰 압축되어 있다.
- 현재 클리어 조건은 `11 captures` 기준이다.
- 보스 진입도 `prototype_gate` 기준으로 `3 / 5 / 7 / 9 / 11` 캡처에서 동작한다.

## Verification Status

검증 기준일: `2026-03-20`

- Headless boot
  - `pass`
- UI smoke
  - `pass`
- Unit test runner
  - `investigate`
  - `tests/test_runner.gd` 실행이 120초 이상 종료되지 않아 타임아웃이 발생했다.

## Documentation Coverage Check

### Already Documented

- 전체 게임 설계와 MVP/로드맵: `agent.md`
- AdMob 앱/슬롯 정보와 UMP 작업 목록: `admob_setup.md`
- 자산 임포트 및 재생성 이력: `asset_import_report.md`, `asset_regeneration_list.md`
- 이미지 생성 프롬프트: `image_prompts.md`, `asset_regeneration_prompts.md`

### Was Missing Before This Update

- 현재 구현 상태를 한 장에서 보는 진행현황 문서
- 각 문서가 무엇을 담당하는지 설명하는 진입점
- 검증 결과와 남은 작업 우선순위를 문서로 고정한 항목

## Remaining Work

- `tests/test_runner.gd` 타임아웃 원인 파악 및 테스트 러너 안정화
- `AdService`를 실제 Android AdMob 브리지와 연결
- `rewarded_revive`, `rewarded_double_run_reward`, `rewarded_bonus_reroll`, `interstitial_run_end` UI 흐름 연결
- Android export preset, 광고 슬롯 설정 파일, UMP consent 흐름, analytics 이벤트 훅 추가
- MVP 목표 대비 부족한 콘텐츠 보강
  - Events `+3`
  - Run upgrades `+6`
  - Meta upgrades `+6`
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
