# 빠띠앱

## 스토어 출시 및 업그레이드

.natrium.yml의 plist > "PartiApp/Info.plist"의 CFBundleShortVersionString과 CFBundleVersion 값을 적절히 업데이트 합니다

"버전이름-rc번호"로 git 태깅합니다.

PartiApp_UITests.swift와 screenshots/Framefile.json을 적당히 조정하고 아래 명령을 이용해 스냅샷을 만들고 itunesconnect에 등록합니다.

```
$ fastlane snapshot
$ fastlane frameit silver --verbose
```

## 개발 환경 설정

GoogleService-Info.plist 을 준비해서 PartiApp/natrium.files/GoogleService-Info-DEV.plist에 복사해 둡니다. 릴리즈용을 빌드할 때에 필요한 GoogleService-Info-PRODUCTION.plist 도 만듭니다.

[https://github.com/e-sites/Natrium] 의 설정 파일을 세팅합니다. ${PROJECT_DIR}/.natrium.yml.sample을 복사하여 만듭니다.

```
$ cp .natrium.yml.sample .natrium.yml
```

${PROJECT_DIR}/.natrium.yml을 열어서 자신의 환경에 맞게 설정합니다.
Fabric[https://fabric.io/kits/ios/crashlytics/install]의 API 키를 참조합니다.
Development Key와 Production Key가 다르게 설정되었는지 확인합니다.

```
---
environments:
  - Development
  - Staging
  - Production

natrium_variables:
  environmentSlug:
    Development: DEV
    Staging: STAGING
    Production: PRODUCTION

variables:
  apiBaseUrl:
    Development: https://dev.parti.xyz/
    Staging: https://dev.parti.xyz/
    Production: https://parti.xyz/
  apiBaseUrlRegex:
    Development: ^https:\\/\\/(.*\\.)?dev.parti\\.xyz(\\$|\\/)
    Staging: ^https:\\/\\/(.*\\.)?dev.parti\\.xyz(\\$|\\/)
    Production: ^https:\\/\\/(.*\\.)?parti\\.xyz(\\$|\\/)
  authGoogleClientId:
    Development: xxx # <-- 이부분
    Staging: xxx # <-- 이부분
    Production: xxx # <-- 이부분
  authGoogleServerClientId:
    Development: xxx # <-- 이부분
    Staging: xxx # <-- 이부분
    Production: xxx # <-- 이부분
  authFacebookAppId:
    Development: xxx # <-- 이부분
    Staging: xxx # <-- 이부분
    Production: xxx # <-- 이부분

plists:
  "PartiApp/Info.plist":
    CFBundleDisplayName:
      Development: 빠띠-개발
      Staging: 빠띠-테스트
      Production: 빠띠
    CFBundleShortVersionString: xxx # <-- 이부분
    CFBundleVersion: xxx # <-- 이부분
    "CFBundleURLTypes:0:CFBundleURLSchemes:0": xxx # <-- 이부분
    "CFBundleURLTypes:0:CFBundleURLSchemes:1": xxx # <-- 이부분
    "Fabric:APIKey":
      Development: xxx # <-- 이부분
      Staging: xxx # <-- 이부분
      Production: xxx # <-- 이부분
    FacebookClientToken: xxx # <-- 이부분

files:
  PartiApp/GoogleService-Info.plist: PartiApp/natrium.files/GoogleService-Info-#{environmentSlug}.plist
```

https://github.com/e-sites/Natrium/blob/main/docs/INSTALL_SWIFTPM.md 를 보고 그대로 세팅합니다. 다만 환경 설정값은 Development로 지정합니다.
