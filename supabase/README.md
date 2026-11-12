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
| `attempts` | 풀이 기록, 점수 | 본인 행 읽기·추가 |
| `attempt_words` | 단어별 시도 횟수, 글자 힌트, 정답 공개 | 본인 기록 읽기 |
| `wrong_words` | 오답 횟수, 복습 상자(1·2), 다음 복습일, 숙달 | 본인 행 읽기·수정·삭제 |

점수·오답 기록은 앱이 직접 쓰지 않고 3·4주차 정답 확인 RPC(security definer)에서 씁니다.

## RPC (앱에서 `supabase.rpc(...)`)

| 함수 | 내용 |
|---|---|
| `get_puzzle(p_puzzle_id)` | 퍼즐 틀과 힌트(번호, 방향, 위치, 길이, 한국어 뜻, 영어 정의, 빈칸 예문). 정답 철자는 보내지 않음 |
| `delete_my_account()` | 계정 삭제. 관련 데이터도 함께 지워짐 |
| (3주차) 정답 확인 | 단어 단위 정답 확인, 점수 계산 |

`get_puzzle` 반환 예:

```json
{"id": "mid-001", "level": "intermediate", "rows": 13, "cols": 13, "template": "uk-13-01",
 "blocks": [[0, 4], [1, 1]],
 "clues": [{"id": 17, "no": 1, "dir": "across", "row": 0, "col": 0, "length": 4,
            "meaning_ko": "일정", "definition_en": "...", "example_blank": "Check the _____."}]}
```

## 데이터 입력

2~3주차에 검수한 단어·퍼즐을 `seed.sql` 로 변환하는 도구(`tools/export_sql.py`)를 추가합니다.
로컬은 `supabase db reset` 때 `seed.sql` 이 자동 적용되고, 실제 프로젝트는 SQL Editor 에서 실행합니다.

## 규칙

- DB 변경(테이블, RLS, RPC)은 모두 migration 파일로 남깁니다.
  - 새 변경: `supabase migration new 이름`
  - 대시보드에서 바꾼 내용 가져오기: `supabase db diff -f 이름`
- 바꾼 뒤에는 RLS 검사를 돌립니다 (Docker만 있으면 됨): `bash supabase/tests/run_rls_check.sh`
