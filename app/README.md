# app — Flutter 앱

담당: 지태웅

## 시작하기

이 폴더 안에서 Flutter 프로젝트를 만듭니다.

```
cd app
flutter create --org com.wordcross --project-name wordcross .
flutter pub add supabase_flutter flutter_local_notifications timezone
```

## 들어갈 화면

- 홈, 퍼즐 목록·상세, 퍼즐 풀이(격자, 힌트 바, 전용 키보드), 결과
- 오답 노트·복습 카드, 마이페이지·통계, 알림 설정

## 연결 정보

Supabase URL과 anon 키는 저장소 최상위의 `.env.example`을 참고해 `.env`에 넣고 사용합니다.
