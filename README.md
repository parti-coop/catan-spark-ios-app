# 빠띠앱

## 개발 환경 설정

Info.plist를 설정합니다.

```
cp PartiApp/natrium.files/Info-DEV.plist.sample PartiApp/natrium.files/Info-DEV.plist
```

위의 PartiApp/natrium.files/Info-DEV.plist 파일에 NSExceptionDomains 아래 key "parti.test"를 테스트할 서버에 맞춰 설정합니다.

```
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <true/>
  <key>NSAllowsArbitraryLoadsInWebContent</key>
  <true/>
  <key>NSExceptionDomains</key>
  <dict>
      <key>parti.test</key>       <!-- *== 이부분 -->
      <dict>
          <key>NSIncludesSubdomains</key>
          <true/>
          <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
          <true/>
      </dict>
  </dict>
</dict>
```

GoogleService-Info.plist 파일이 있다면 이를 준비해서 PartiApp/natrium.files/GoogleService-Info-DEV.plist에 복사해 둡니다.

pod를 설치합니다. pod로 관련된 라이브러리를 설치합니다. 소스 레포지토리에 이미 들어가 있기는 합니다. 그래도 아래 명령어로 라이브러리를 다시 설치하는게 좋습니다.

```
$ pod install
```

[https://github.com/e-sites/Natrium] 의 설정 파일을 세팅합니다. ${PROJECT_DIR}/.natrium.yml.sample을 복사하여 만듭니다.

```
$ cp .natrium.yml.sample .natrium.yml
```

${PROJECT_DIR}/.natrium.yml을 열어서 variables > apiBaseUrl > Development와 variables > apiBaseUrlRegex > Development를 자신의 환경에 맞게 설정합니다.

```
variables:
  apiBaseUrl:
    Development: https://parti.test/  # <-- 이부분
    Staging: https://dev.parti.xyz/
    Production: https://parti.xyz/
  apiBaseUrlRegex:
    Development: ^https:\\/\\/(.*\\.)?parti\\.test(\\$|\\/)  # <-- 이부분
    Staging: ^https:\\/\\/(.*\\.)?dev.parti\\.xyz(\\$|\\/)
    Production: ^https:\\/\\/(.*\\.)?parti\\.xyz(\\$|\\/)

```

https://github.com/e-sites/Natrium/blob/master/docs/INSTALL_COCOAPODS.md#step-3 를 보고 그대로 세팅합니다. 다만 환경 설정값은 Development로 지정합니다.
