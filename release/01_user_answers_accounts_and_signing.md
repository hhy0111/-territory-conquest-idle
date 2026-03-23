# Release Inputs: Accounts And Signing

status: `in_progress`

이 문서는 출시 주체와 실제 배포 서명 정보를 확정하는 용도다. 이 항목이 비어 있으면 최종 스토어 제출을 완료할 수 없다.

## 답변 표

| 항목 | 사용자 답변 | 메모 |
| --- | --- | --- |
| 앱을 게시할 스토어 계정 주체 | Assumed: 개인 계정 | 팀/사업자 전환 시 문구만 교체 |
| 스토어에 표시할 개발자명 | Assumed: `hhy0111` | 저장소/패키지 소유자 기준 |
| 앱 최종 표시 이름 | `Territory Conquest Idle` | 현재 프로젝트와 동일 |
| 최종 패키지명 유지 여부 | 유지 | 현재 값: `com.hhy0111.territoryconquestidle` |
| production release keystore 보관 위치 | Assumed: 저장소 외부 보안 저장소 | Git 저장 금지 |
| keystore 관리 책임자 | Assumed: 앱 배포 소유자 1명 + 백업 1명 | 1명 이상 권장 |
| key alias | Assumed: `territory-conquest-idle-release` | alias만 문서화 |
| keystore 비밀번호 전달 방식 | 환경변수 기반 전달 | 문서에 평문 저장 금지 |
| key 비밀번호 전달 방식 | 환경변수 기반 전달 | 문서에 평문 저장 금지 |
| 버전명 정책 | Assumed: internal/closed `0.1.0`, production 첫 배포 `1.0.0` | 현재 export preset은 `0.1.0` |
| 버전코드 정책 | 증가 정수 사용, 첫 배포 `1` | 이후 절대 감소 금지 |
| 첫 출시 트랙 | Assumed: `closed` | 바로 production보다 안전 |
| 첫 롤아웃 비율 | Assumed: `20%` | closed/open 이후 production 전환 시 사용 |

## 최종 확인

- QA용 로컬 서명키를 실제 출시 서명키로 교체
- 출시 계정 소유권과 keystore 백업 책임자 확정
- 패키지명과 앱 이름 동결
