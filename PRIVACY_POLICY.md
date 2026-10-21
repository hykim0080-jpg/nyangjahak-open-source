# Privacy implementation notes / 개인정보 구현 참고

**이 소스 배포본에 대한 기술 설명이며, 배포 앱에 사용할 최종 법률 문서나 개인정보처리방침은 아닙니다.** 재배포자는 실제 기능과 배포 지역에 맞는 정책·연락처를 직접 준비해야 합니다. 원 개발자의 연락처는 이 사본에 넣지 않았습니다.

## 확인한 소스의 동작

- 진행 중 운반, 상자·고양이·발견 물건·일지 등 게임 상태는 JSON으로 인코딩되어 앱의 `UserDefaults`에 저장됩니다.
- 언어 설정도 `UserDefaults`에 저장됩니다.
- Core Motion 중력 값과 근접 센서 상태를 엎기 판단에 사용합니다. 검토한 소스에서 센서 값의 디스크 기록·네트워크 전송은 발견되지 않았습니다.
- 검토한 앱 소스에서 계정/로그인, 광고·분석 SDK, 앱 자체의 인터넷 전송이나 서버 저장 기능은 발견되지 않았습니다.
- Debug 상태 화면은 개발용 기록과 센서 상태를 표시할 수 있습니다. 화면을 공유할 때도 실제 개인 정보가 없는지 확인하세요.

## 삭제와 OS 백업

앱 내 Debug 초기화나 앱 삭제는 현재 앱 저장 영역에 영향을 줄 수 있지만, iOS 기기 백업·복원에 남아 있는 데이터까지 모두 지운다고 보장하지 않습니다. iCloud/컴퓨터 백업, 기기 진단·App Store 통계 등 OS/플랫폼 기능은 앱의 직접 전송과 구분해야 합니다. 이 자료의 삭제·복원 동작은 실기기에서 별도로 확인해야 합니다.

## Manifest

`PrivacyInfo.xcprivacy`는 추적 없음, 수집 데이터 유형 없음, UserDefaults 접근 API의 사유 `CA92.1`을 선언합니다. 재배포자가 기능을 추가하면 실제 동작·정책·manifest를 함께 검토해야 합니다.

## English summary

This source distribution stores progress and language settings locally in UserDefaults. The reviewed app source did not show accounts, ad/analytics SDKs, application-originated network transmission, or storage/transmission of sensor samples. This is a bounded implementation review, not a guarantee or a distribution-ready legal policy. OS/device backups and diagnostics are separate; deletion does not guarantee removal from all backups. Derivative distributors must provide their own accurate privacy policy and contact channel.
