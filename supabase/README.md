# supabase — 백엔드

담당: 김민성

## 시작하기

저장소 최상위 폴더에서 실행합니다. `config.toml` 과 `migrations/` 는 이미 들어 있습니다.

```
supabase link --project-ref 프로젝트ID
supabase db push              # migrations/ 를 실제 프로젝트에 반영
```

로컬에서 돌려 보기 (Docker 필요): `supabase start` → `supabase db reset` (migration 적용)

## 로그인 설정 (실제 프로젝트 대시보드)

`config.toml` 은 로컬용입니다. 호스팅 프로젝트는 대시보드 **Authentication** 에서 아래처럼 맞춥니다.

| 위치 | 값 |
|---|---|
| Sign In / Providers → Email | 켜기, Confirm email 켜기 |
| Sign In / Providers → Anonymous | 끄기 |
| Passwords | 최소 8자, 영문+숫자 |
| URL Configuration → Redirect URLs | `com.wordcross.wordcross://login-callback` 추가 (앱 딥링크) |

- 가입할 때 `options.data.nickname` 을 넘기면 `profiles.nickname` 에 들어갑니다 (트리거 `handle_new_user`).
- 앱에는 URL과 anon 키만 넣습니다. service_role 키는 `tools/` 에서만 씁니다.

## 테이블

| 테이블 | 내용 | 앱에서 |
|---|---|---|
| `profiles` | 닉네임, 알림 켜기·시간 | 본인 행 읽기·수정 |
| `words` | 단어(정답), 난이도, 뜻, 정의, 예문 | **직접 읽기 불가** |
| `puzzles` | 퍼즐 크기, 틀, 검은 칸, 공개 여부 | 공개된 퍼즐 목록 읽기 |
| `puzzle_words` | 퍼즐 속 단어 번호·방향·위치·길이 | **직접 읽기 불가** |
| `attempts` | 풀이 기록, 점수 | 본인 행 읽기 (만들기·고치기는 RPC로만) |
| `attempt_words` | 단어별 시도 횟수, 글자 힌트, 정답 공개 | 본인 기록 읽기 |
| `wrong_words` | 오답 횟수, 복습 상자(1·2), 다음 복습일, 숙달 | 본인 행 읽기·수정·삭제 |

풀이 기록·점수는 앱이 직접 쓰지 못하고 아래 RPC(security definer)만 씁니다. 오답 노트 자동 기록은 4주차.

## RPC (앱에서 `supabase.rpc(...)`)

모두 로그인한 사용자만 부를 수 있습니다 (비로그인은 401).

| 함수 | 내용 |
|---|---|
| `get_puzzle(p_puzzle_id)` | 퍼즐 틀과 힌트. 정답 철자는 보내지 않음. 진행 중 기록이 있으면 비공개로 바뀐 퍼즐도 받음 |
| `start_attempt(p_puzzle_id)` | 풀이 시작. 같은 퍼즐의 진행 중 기록이 있으면 그것을 돌려줌(이어 풀기) |
| `check_word(p_attempt_id, p_clue_id, p_guess, p_request_id?)` | "확인" 버튼: 단어 하나 채점 |
| `finish_attempt(p_attempt_id)` | "제출" 버튼: 퍼즐 끝내기. 빈칸이 있어도 됨 |
| `delete_my_account()` | 계정 삭제. 관련 데이터도 함께 지워짐 |
| (4주차) 글자 힌트·정답 공개 | `reveal_letter`, `reveal_word` 예정 |

`get_puzzle` 반환 예:

```json
{"id": "mid-001", "level": "intermediate", "rows": 13, "cols": 13, "template": "uk-13-01",
 "blocks": [[0, 4], [1, 1]],
 "clues": [{"id": 17, "no": 1, "dir": "across", "row": 0, "col": 0, "length": 4,
            "meaning_ko": "일정", "definition_en": "...", "example_blank": "Check the _____."}]}
```

### 풀이 흐름 (앱에서)

1. 퍼즐 화면을 열 때 `get_puzzle` 과 `start_attempt` 를 함께 부른다.
   `start_attempt` 의 `words[]` 로 이미 맞힌 단어(`solved`, `answer`)와 남은 시도(`tries_left`)를 격자에 채운다 (이어 풀기).
2. 단어 칸을 다 채우고 "확인" → `check_word(attempt_id, clue_id, guess, request_id)`.
   `clue_id` = `get_puzzle` 의 `clues[].id`. `request_id` 는 확인 한 번마다 새 UUID (네트워크가 끊겨 다시 보내도 한 번만 처리됨).
3. "제출" → 못 맞힌 단어가 있으면 "아직 n단어 남았어요. 제출할까요?" 확인 창 → `finish_attempt(attempt_id)` → 결과 화면.
   기준은 빈칸이 아니라 **맞힌 것으로 확정되지 않은 단어**다. 칸을 다 채웠어도 "확인"을 누르지 않았거나 틀린 단어는 0점이고
   제출은 되돌릴 수 없어서, 확인을 깜빡한 단어도 알려 준다 (n = 못 맞힌 단어 수).

### `start_attempt` 반환

```json
{"attempt_id": 12, "puzzle_id": "beg-001", "started_at": "2026-11-23T06:00:54Z", "resumed": false,
 "words": [{"clue_id": 33, "no": 1, "dir": "across", "solved": false, "revealed": false,
            "tries": 0, "tries_left": 5, "letter_hints": 0, "score": 0, "answer": null}]}
```

### `check_word` 반환

```json
{"correct": true, "solved": true, "revealed": false, "tries": 3, "tries_left": 2,
 "score": 80, "answer": "NOTE", "counted": true}
```

- `answer` 는 맞혔을 때만 들어 있음 (틀리면 맞은 글자 위치도 알려 주지 않음)
- `counted: false` = 시도 횟수에 안 들어감: 바로 앞과 같은 오답을 다시 냈거나, 이미 맞힌 단어
- 대소문자는 구분하지 않음

### `finish_attempt` 반환

```json
{"attempt_id": 12, "puzzle_id": "beg-001", "score": 1580, "max_score": 1900,
 "correct": 17, "total": 19, "accuracy": 0.895, "duration_sec": 412,
 "words": [{"clue_id": 33, "no": 1, "dir": "across", "word": "NOTE", "meaning_ko": "...",
            "solved": true, "revealed": false, "tries": 1, "letter_hints": 0, "score": 100}]}
```

- 결과 화면용이라 `words[]` 에 **모든 단어의 정답 철자**가 들어 있음
- 이미 제출한 기록에 다시 부르면 같은 결과를 돌려줌

### 오류 (예외 메시지 → 앱 문구 예)

| 메시지 | 언제 | 앱에서 |
|---|---|---|
| `not_authenticated` | 로그인 안 함 | 로그인 화면으로 |
| `puzzle_not_found` | 없는·비공개 퍼즐로 시작 | "퍼즐을 찾을 수 없어요." |
| `attempt_not_found` | 없는 기록이거나 남의 기록 | 퍼즐을 다시 열기 |
| `attempt_closed` | 제출했거나 24시간이 지나 포기 처리됨 | "이 풀이는 끝났어요." 후 다시 시작 |
| `clue_not_in_puzzle` | 다른 퍼즐의 단어 | (앱 버그) |
| `invalid_guess` | 빈칸, 글자 수 다름, 알파벳 아님 (시도 안 셈) | 확인 버튼을 막아 두면 안 생김 |
| `no_tries_left` | 5번 다 틀림 | "정답 공개만 할 수 있어요." (정답 공개는 4주차) |

### 점수 규칙 (기획서 4장)

- 맞힌 단어 = max(20, 100 − 10 × 틀린 확인 횟수 − 20 × 글자 힌트 횟수), 공개·못 푼 단어 = 0
- 퍼즐 점수 = 단어 점수의 합, 정답률 = 공개 없이 맞힌 단어 ÷ 전체
- 진행 중 기록은 퍼즐당 하나, 시작 후 24시간이 지나면 포기(`abandoned`)로 정리
- 검사: `bash supabase/tests/run_rls_check.sh` (정답 확인·점수 35가지)

## 데이터 입력

`python3 tools/export_sql.py` 가 검수한 퍼즐과 그 단어로 `seed.sql` 을 만듭니다 (3주차 퍼즐 등록에 사용).
개발용으로 검수 전 퍼즐 36개(난이도별 12개)를 실제 프로젝트에 공개해 두었습니다 (`export_sql.py --dev`, `tools/README.md` 참고).
로컬은 `supabase db reset` 때 `seed.sql` 이 자동 적용되고, 실제 프로젝트는 SQL Editor 에서 실행합니다.

## 규칙

- DB 변경(테이블, RLS, RPC)은 모두 migration 파일로 남깁니다.
  - 새 변경: `supabase migration new 이름`
  - 대시보드에서 바꾼 내용 가져오기: `supabase db diff -f 이름`
- 바꾼 뒤에는 RLS 검사를 돌립니다 (Docker만 있으면 됨): `bash supabase/tests/run_rls_check.sh`
