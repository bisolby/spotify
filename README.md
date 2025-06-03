# Spotify Web API iOS 앱 튜토리얼

이 프로젝트는 Spotify Web API 공식 튜토리얼을 기반으로 한 iOS 앱 예제입니다.

## 🎯 구현 기능

- **Client Credentials Flow**: 액세스 토큰 획득
- **아티스트 정보 조회**: 특정 아티스트의 상세 정보 가져오기
- **아티스트 검색**: 이름으로 아티스트 검색
- **반응형 UI**: SwiftUI를 사용한 현대적인 인터페이스

## 🛠 설정 방법

### 1. Spotify Developer Dashboard 설정

1. [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)에 로그인
2. "Create an app" 버튼 클릭
3. 앱 정보 입력:
   - **App Name**: My Spotify API App
   - **App Description**: iOS tutorial app
   - **Redirect URI**: `http://127.0.0.1:3000`
4. Developer Terms of Service 체크박스 선택 후 "Create" 클릭

### 2. 클라이언트 자격 증명 획득

1. 생성된 앱을 클릭
2. "Settings" 버튼 클릭
3. **Client ID** 복사
4. "View client secret" 링크 클릭하여 **Client Secret** 복사

### 3. iOS 프로젝트 설정

1. `SpotifyAPIManager.swift` 파일에서 다음 부분 수정:

```swift
// TODO: Replace with
