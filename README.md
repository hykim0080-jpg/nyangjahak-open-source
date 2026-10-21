# Nyangjahak / Meowntum — iOS source

휴대폰을 내려놓는 동안 상자를 운반하고 고양이를 모으는 SwiftUI 집중 앱의 소스 배포본입니다.

> **빌드·실행 미검증 소스 배포본입니다.** 원본 비공개 저장소와 분리한 소스입니다. 저장소 소유자가 포함된 코드·번역·아이콘 및 공동 기여분을 공개·라이선스 적용할 권한이 있음을 확인하고, 2026-10-21 MIT 적용과 신규 Public 저장소 생성을 승인했습니다. 전체 빌드·실기기 검증은 아직 완료되지 않았습니다.

## 포함한 기능

- SwiftUI 화면과 Canvas/Path 기반 고양이·상자 그리기
- Core Motion 중력 값과 근접 센서를 활용한 엎기 판단
- 집중 시간 / 도착 시간 / 열 때까지 운반 모드
- 창고·도감·운반 일지와 한국어/영어 문자열
- 기기 내부 `UserDefaults`에 저장하는 진행 상태
- 시뮬레이터용 Debug 보조 기능

검토한 앱 소스에는 로그인, 광고·분석 SDK, 앱 자체의 네트워크 전송 코드가 보이지 않습니다. 이는 소스 범위 확인이지 보안 인증이나 모든 실행환경에 대한 보장은 아닙니다. OS 백업·진단은 별개입니다.

## 실행 환경

- Xcode 26 이상 권장: 프로젝트는 objectVersion 77 / 파일 시스템 동기화 그룹을 사용합니다.
- iOS 17 이상, iPhone 대상, Swift 5 언어 모드
- 별도 Swift Package·CocoaPods 의존성은 발견되지 않았습니다.

```sh
open NyangJahak.xcodeproj
```

Xcode에서 `NyangJahak` scheme과 설치된 iPhone 시뮬레이터를 선택해 Run합니다. 시뮬레이터는 실제 센서를 재현하지 않으므로 Debug 화면의 엎기 시뮬레이션을 사용합니다. Debug 전용 1분 운반과 상태 패널은 제품 동작을 확인하기 위한 보조 장치입니다.

**개인 설정 분리:** 원 개발자의 signing team은 제거했고 bundle identifier는 `org.example.meowntum`으로 바꿨습니다. 실제 기기로 빌드하려면 본인의 team과 고유 bundle identifier를 지정하세요. 원 앱의 App Store 배포 정보나 서명 자격증명은 포함하지 않습니다. 예제 bundle identifier로 App Store에 제출하지 마세요.

서명 없이 컴파일만 확인하는 예시:

```sh
xcodebuild -project NyangJahak.xcodeproj -scheme NyangJahak \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/meowntum-build CODE_SIGNING_ALLOWED=NO build
```

이 명령은 안내 예시이며 실제 검증 여부는 `docs/VALIDATION.md`를 따릅니다. 빌드 산출물은 저장소 밖에 두세요.

## 소스 지도

- `GameStore.swift`: 센서, 운반 상태, 보상, 저장/복원
- `Models.swift`: 모델·게임 카탈로그·언어와 스타일
- `CarryScreens.swift`, `BoxScreens.swift`: 앱 화면
- `Drawing.swift`: 코드로 그리는 고양이·상자
- `CarryLog.swift`: 운반 일지
- `NyangJahakApp.swift`: 앱 시작과 Debug UI
- `Localizable.xcstrings`, `InfoPlist.xcstrings`: 번역
- `tools/render_icon.swift`: Core Graphics 앱 아이콘 렌더러

## 검증

```sh
node scripts/check.mjs
```

Node.js 20+로 프로젝트 파일·로컬 문자열·에셋 참조와 공개 경계를 정적으로 검사합니다. 앱 동작 단위 테스트나 보안 감사의 대체물이 아닙니다. 실기기·센서와 수동 기능 검증은 [TESTING.md](TESTING.md), 이번 준비본에서 실행한 검증/실패는 [docs/VALIDATION.md](docs/VALIDATION.md)를 보세요.

## 공개 범위와 라이선스

스토어 스크린샷·홍보물, 판매 문구, 연락처가 있는 기존 정책 페이지, 기획 초안과 원본 Git 이력은 포함하지 않습니다. 앱 실행에 필요한 코드·문자열·아이콘을 포함하며, 소유자의 권리 확인을 근거로 MIT를 적용했습니다. 이는 독립적인 법률 검토나 제3자 권리에 대한 보증은 아닙니다. [에셋 출처와 권리 범위](docs/ASSETS_AND_RIGHTS.md)를 확인하세요.

포함된 소스·번역·카탈로그·앱 아이콘은 [MIT 라이선스](LICENSE)로 제공합니다. Apple SDK·SF Symbols는 MIT로 재라이선스되는 것이 아니며, 앱 이름·상표에 대한 권리도 별도입니다. 공개 승인 기록과 향후 배포 체크리스트는 [docs/RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md)에 있습니다.

이 프로젝트를 공개한다는 사실만으로 개발자 혜택, 사용자 수, 다운로드, 커뮤니티 유지관리 실적을 주장하지 않습니다.
