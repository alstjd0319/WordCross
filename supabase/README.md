# supabase — 백엔드

담당: 김민성

## 시작하기

저장소 최상위 폴더에서 실행합니다. 이 폴더에 `config.toml`과 `migrations/`가 생깁니다.

```
supabase init
supabase link --project-ref 프로젝트ID
```

## 규칙

- DB 변경(테이블, RLS, RPC)은 모두 migration 파일로 남깁니다.
  - 새 변경: `supabase migration new 이름`
  - 대시보드에서 바꾼 내용 가져오기: `supabase db diff -f 이름`
  - 실제 프로젝트에 반영: `supabase db push`
- 정답 컬럼은 RLS로 앱에서 읽지 못하게 막고, 정답 확인은 RPC로만 처리합니다.
- 풀이 기록, 오답, 통계 테이블은 "본인 행만 읽기·쓰기" 규칙을 겁니다.

## 예정 테이블

- `words`: 단어, 난이도, 한국어 뜻, 영어 정의, 예문, 출처
- `puzzles`: 퍼즐 틀, 크기, 난이도
- `puzzle_words`: 퍼즐에 들어간 단어와 위치·방향
- `attempts`: 풀이 기록과 점수
- `wrong_words`: 오답, 복습 상자, 다음 복습 날짜, 숙달 여부
