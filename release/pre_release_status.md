# Pre-Release Status

Last updated: `2026-03-23`

## 현재 기준 완료된 항목

- 코어 플레이 루프
  - 홈 -> 런 -> 전투 -> 결과 -> 메타 흐름 구현
- 저장/복구
  - 프로필 저장, 활성 런 저장, 30분 이내 런 복구
- 데이터 기반 콘텐츠
  - 타일, 적, 이벤트, 유물, 런 업그레이드, 메타 업그레이드, 보스 JSON 구성
- 광고 런타임
  - mock fallback, QA override, Android bridge hook, consent/app-open/rewarded/interstitial 게이트
- Android 준비
  - export preset, AAR 빌드, fallback export, smoke 실행 스크립트
- 검증 스크립트
  - 핵심 테스트, 광고 서비스 테스트, UI smoke, 시뮬레이션 리포트, 프리릴리스 통합 체크 스크립트
- 릴리스 제출 초안
  - 스토어 설명 초안, privacy policy 초안, data safety 초안, 사용자 입력 문서 기본안 작성
- 릴리스 산출물 생성기
  - HTML/JSON draft 출력물과 release bundle 생성 스크립트 추가

## 지금 남은 외부 블로커

- `01_user_answers_accounts_and_signing.md`
  - 실제 출시 계정과 production keystore만 확정 필요
- `02_user_answers_ads_privacy_and_policy.md`
  - privacy policy 실제 호스팅 URL과 운영 지원 메일 확정 필요
- `03_user_answers_store_listing.md`
  - 실제 스크린샷/스토어 자산 확정 필요
- `04_user_answers_launch_ops_and_support.md`
  - 실제 출시일과 운영 책임자 명시만 확정 필요

## 권장 실행 순서

1. 사용자 답변 문서 4개를 채운다.
2. `tools/release/run_pre_release_checks.ps1`를 실행한다.
   - 필요하면 `-GodotPath`, `GODOT_PATH`, 또는 `.local/godot` 경로를 사용한다.
   - 현재 환경에서 Godot가 없으면 `-DocsOnly`로 문서/릴리스 초안부터 검증할 수 있다.
3. 필요하면 `-IncludeAndroidPreflight`, `-ExportReleaseApk`, `-RunAndroidSmoke` 옵션으로 확장한다.
4. 실기기 광고 QA와 스토어 제출 항목을 확정한다.
5. 제출 직전에는 `tools/release/check_release_docs.ps1 -Mode Submission`으로 확정본 상태를 검증한다.
6. 전달용 묶음이 필요하면 `tools/release/prepare_release_bundle.ps1`를 실행한다.

## 완료 정의

아래 조건이 모두 충족되면 프리릴리스 완료로 본다.

- 사용자 답변 문서 4개가 `확정`
- 통합 프리릴리스 검증 통과
- 실기기 광고 QA 완료
- production release signing 적용
- 스토어 제출 메타데이터 및 정책 응답 확정
