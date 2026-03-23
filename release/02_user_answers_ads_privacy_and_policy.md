# Release Inputs: Ads, Privacy, And Policy

status: `in_progress`

이 문서는 광고 정책, 개인정보 처리, consent 방향처럼 코드 밖에서 사용자가 결정해야 하는 항목만 정리한다.

## 답변 표

| 항목 | 사용자 답변 | 메모 |
| --- | --- | --- |
| 실제 운영용 AdMob 앱 ID 최종 승인 여부 | Assumed: 현재 `ad_runtime.json` 값 사용 | 문서 기록값과 일치 |
| 운영용 광고 슬롯 그대로 사용 여부 | 유지 | 변경 시 `data/ad_runtime.json` 갱신 필요 |
| personalized ads consent를 첫 출시부터 노출할지 | 노출 | UMP enabled 기준 |
| privacy policy URL | Assumed: 배포 전 `release/privacy_policy_draft.md`를 실제 호스팅 URL로 게시 | 스토어 제출에는 URL 필요 |
| support email | Assumed: 실제 운영 메일 생성 후 정책/스토어에 동일 반영 | 초안 문서에는 메일 슬롯만 정의 |
| 데이터 수집/공유 설명 초안 승인 여부 | 초안 생성 완료 | `release/data_safety_draft.md` 참고 |
| 아동 대상 앱 여부 | 아니오 | 일반 모바일 전략/로그라이트 기준 |
| 광고 노출 금지 국가/지역 여부 | Assumed: 없음 | 별도 정책이 있으면 추가 |
| 출시 전 실기기 테스트 디바이스 등록 담당자 | Assumed: 릴리스 담당자 | AdMob QA용 |
| 광고 장애 시 기본 대응 정책 | 광고 실패 시 게임 진행 유지, 보상은 미지급 처리 | 현재 런타임 동작과 일치 |

## 실제 기기 QA 확인 항목

- consent 요청
- cold start app-open
- background resume app-open
- rewarded 완료
- rewarded 실패
- interstitial 완료
- interstitial 실패

## 최종 확인

- privacy policy draft를 실제 URL로 호스팅
- consent 방향과 Data safety 응답 확정
- 운영 광고 단위와 테스트 디바이스 운영 방식 확정
