# WordCross

영어 단어를 십자말풀이로 익히고, 틀린 단어를 복습으로 이어 주는 모바일 학습 앱입니다.

- 팀: 김민성 · 지태웅
- 앱: Flutter (Dart)
- 백엔드: Supabase (DB, 로그인, RLS, RPC)
- 퍼즐: 토익 필수 단어로 미리 생성하고 검수한 신문형 격자 퍼즐

## 폴더 구조

```
WordCross/
├─ app/        Flutter 앱 (담당: 지태웅)
├─ supabase/   DB 구조, RLS, RPC, 초기 데이터 (담당: 김민성)
├─ tools/      단어 가공, 퍼즐 생성 스크립트 (담당: 김민성)
└─ data/       정리된 단어 CSV, 퍼즐 JSON (공동 검수)
```

## 디자인

- Figma: [WordCross 화면 설계](https://www.figma.com/design/91oJco8deqzNoQkeQzDu2W/WordCross-%ED%99%94%EB%A9%B4-%EC%84%A4%EA%B3%84) (담당: 지태웅)
  - 맨 위 "0. 화면 흐름" 섹션에 화면 10개와 이동 경로를 정리한 흐름도가 있습니다.
  - 오른쪽 위 ▶(Present)를 누르면 로그인 화면부터 프로토타입으로 눌러 볼 수 있습니다.
- 색과 글자 스타일은 앱의 `app/lib/app/theme.dart`(`AppColors`, `AppTheme`)와 같은 값입니다.

## 작업 규칙

1. 작업을 시작하기 전에 `git pull`로 최신 내용을 받습니다.
2. 기능마다 브랜치를 만듭니다. 예: `feat/grid-screen`, `feat/check-answer-rpc`
3. 작업이 끝나면 PR을 올리고, 서로 리뷰한 뒤 `main`에 합칩니다.
4. DB를 바꾸면 반드시 `supabase/migrations/`에 migration 파일로 남겨 커밋합니다.
5. 비밀 키(service_role 키 등)는 절대 커밋하지 않습니다. `.env`에만 두세요.

## 데이터 출처

- 단어: TOEIC Service List, Business Service List, NGSL (Browne & Culligan, CC BY-SA 4.0)
- 사전 데이터: Wiktionary (CC BY-SA)
- 예문: Tatoeba (CC BY 2.0 FR), 일부는 팀이 직접 작성
- 추가 학습 단어 선정 참고: ETS 토익 기출 보카 (단어 선정에만 사용, 내용은 저장소에 싣지 않음)
