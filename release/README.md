# Release Input Document Index

이 폴더는 출시 전까지 사용자가 직접 답하거나 외부 계정/플랫폼에서 확정해야 하는 항목만 분리해 둔 문서 모음이다.

## 문서 사용 순서

1. `01_user_answers_accounts_and_signing.md`
   - 계정, 소유권, 서명키, 배포 주체
2. `02_user_answers_ads_privacy_and_policy.md`
   - AdMob, consent, 개인정보 처리, 정책 응답
3. `03_user_answers_store_listing.md`
   - 스토어 문구, 카테고리, 자산, 연락처
4. `04_user_answers_launch_ops_and_support.md`
   - 론칭 일정, 지원 채널, 운영 정책, QA 승인
5. `pre_release_status.md`
   - 현재 코드 기준으로 완료된 항목, 자동화 검증 루틴, 외부 블로커 요약
6. `store_listing_draft.md`
   - 스토어 short/full description과 스크린샷 촬영 계획 초안
7. `privacy_policy_draft.md`
   - 배포 전 호스팅할 개인정보 처리방침 초안
8. `data_safety_draft.md`
   - Play Console Data safety 제출용 응답 초안

## 작성 원칙

- 이 폴더 문서는 `사용자 답변 필요` 항목만 다룬다.
- 코드로 해결 가능한 항목은 별도 개발 작업과 자동화 스크립트로 처리한다.
- 각 문서의 `status`를 `pending`, `in_progress`, `confirmed` 중 하나로 바꿔가며 사용한다.

## 실행 스크립트

- 핵심 Godot 검증: `tools/godot/run_tests.ps1`
- 광고 서비스 전용 검증: `tools/godot/run_ad_service_tests.ps1`
- UI smoke: `tools/godot/run_ui_smoke.ps1`
- 시뮬레이션 리포트: `tools/godot/run_simulation_report.ps1`
- 릴리스 문서 검사: `tools/release/check_release_docs.ps1`
- 릴리스 아티팩트 생성: `tools/release/generate_release_artifacts.ps1`
- 릴리스 번들 준비: `tools/release/prepare_release_bundle.ps1`
- 통합 프리릴리스 검증: `tools/release/run_pre_release_checks.ps1`
  - 문서만 먼저 검증하려면 `-DocsOnly`

## Godot 경로 메모

- 실행 가능한 Godot 경로를 직접 넘기려면 각 스크립트에 `-GodotPath`를 전달한다.
- 반복 실행 환경이면 `GODOT_PATH` 또는 `CODEX_GODOT_PATH` 환경변수를 설정할 수 있다.
- 로컬 워크스페이스 기준 우선 탐색 경로:
  - `.local/godot/`
  - `.local/tools/godot/`
