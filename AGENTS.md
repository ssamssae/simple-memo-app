# AGENTS.md

## 작업 규칙

### 커밋 & 푸시
- 모든 코드 수정 작업이 끝나면 반드시 git add, commit, push를 실행할 것
- 커밋 메시지는 한글로 작성
- 커밋 메시지 형식: "fix: 수정 내용 요약" 또는 "feat: 기능 추가 요약"

### 코드 수정 원칙
- 수정 전 반드시 flutter analyze 실행
- 수정 후 반드시 flutter analyze 실행하여 에러 없는지 확인
- try-catch 없이 SharedPreferences, jsonDecode 사용 금지
- late 변수 사용 최소화, 가능하면 nullable 타입 사용
- initState 내 async 호출 시 반드시 mounted 체크

### 빌드 확인
- iOS 관련 수정 시 빌드 가능 여부 확인
