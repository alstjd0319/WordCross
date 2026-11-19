# tools — 단어 가공, 퍼즐 생성

담당: 김민성

개발 PC에서만 실행하는 도구입니다. 앱과 Supabase에는 들어가지 않습니다. Python 3.10 이상.

## 1주차: 토익 단어 목록 정리

```
python3 tools/fetch_sources.py        # 원본 목록 받기 → data/raw/ (커밋 안 함)
python3 tools/build_word_list.py      # → data/word_list.csv
```

| 파일 | 하는 일 |
|---|---|
| `fetch_sources.py` | TSL·BSL·NGSL 목록, TSL 정의, Tatoeba 영어 예문을 받는다. `--kaikki` 를 주면 단어별 Wiktionary 항목도 받는다(2주차 뜻 초안용, 오래 걸림). 이미 받은 파일은 건너뛴다. |
| `build_word_list.py` | TSL + BSL 합치고 중복 제거(학습 단어), NGSL 은 채움 단어. 3~11글자 알파벳 단어만, `blocklist.txt` 단어 제외. |
| `blocklist.txt` | 퍼즐에 넣지 않을 단어. 검수하며 추가한다. |

결과 (2026-11-12 기준): 학습 단어 2,225개 (TSL 1,161 · BSL 1,064), 채움 단어 2,702개.
BSL 중 532개는 TSL 과 겹쳐 TSL 로 남겼다.

참고: TSL·BSL 은 NGSL 을 보충하는 목록이라 `schedule`, `supply` 처럼 일반 영어에도 흔한 단어는
TSL 이 아니라 NGSL(채움 단어)에 들어 있다. 이런 단어를 학습 단어로 볼지는 2주차 난이도 분류 때 정한다.

## 2주차: 난이도 분류·뜻 초안, 퍼즐 틀·퍼즐 생성 도구

```
python3 tools/fetch_sources.py --kaikki      # Wiktionary 항목까지 받기 (처음엔 20분 이상)
python3 tools/build_words.py                 # word_list.csv → data/words.csv
python3 tools/make_templates.py              # 격자 틀 (이미 data/templates/ 에 있음. 다시 만들 때만)
python3 tools/generate_puzzles.py --level intermediate --count 5
python3 tools/review_puzzle.py mid-001       # 빈 격자로 직접 풀어 보기
python3 tools/review_puzzle.py mid-001 --answers
python3 tools/review_puzzle.py mid-001 --approve
python3 tools/export_sql.py                  # 검수한 퍼즐 → supabase/seed.sql (3주차 퍼즐 등록)
```

| 파일 | 하는 일 |
|---|---|
| `build_words.py` | `word_list.csv` 에 난이도, 품사, 한국어 뜻·영어 정의 초안(Wiktionary·TSL 정의), Tatoeba 예문·빈칸 예문을 붙인다. 사전에 고유명사·약어·변화형으로만 나오는 단어는 뺀다. 이미 `reviewed=true` 인 행은 덮어쓰지 않는다. |
| `crossword.py` | 공용 코드: 슬롯 추출, 번호 매기기, 틀 규칙 검사, CSP 채우기(MRV, 전방 검사, 백트래킹) |
| `make_templates.py` | 180도 대칭 영국식 격자 틀 생성 → `data/templates/uk-<크기>-<번호>.json` |
| `generate_puzzles.py` | 틀 + 단어로 퍼즐 후보를 여러 개 만들어 품질 점수가 가장 높은 것을 저장 |
| `review_puzzle.py` | 격자·힌트 출력, 검수 완료 표시 |
| `export_sql.py` | 검수한 퍼즐과 그 단어를 `supabase/seed.sql` 로 (여러 번 실행해도 안전한 upsert). `--dev` 는 검수 전 퍼즐도 앱에 공개(개발용) |

### 난이도 기준

| | 초급 | 중급 | 고급 |
|---|---|---|---|
| 격자 | 9×9, 11×11 | 13×13 | 15×15 |
| 단어 길이 | 3~7 | 4~9 | 5~11 |
| 단어 수 | 15~25 | 약 28 | 약 32 |
| 학습 단어 | TSL 1~400위 | TSL 401~800위 | TSL 801위~, BSL |
| 채움 단어 난이도 | NGSL 1~1000위 | NGSL 1001~2000위 | NGSL 2001위~ |

- 영국식 격자(흰 칸이 한 칸씩 건너 교차)는 신문처럼 단어 수가 13×13에서 약 28개, 15×15에서 약 32개가 된다.
  설계서의 30~40개, 40~60개보다 적어서 생성 기준을 26~40개, 30~60개로 낮췄다.
- 퍼즐에 쓰는 채움 단어: 초급은 NGSL 2000위까지, 중급·고급은 전체.
- 후보 단어 점수: 같은 난이도 학습 단어 3, 더 쉬운 학습 단어 2, 채움 단어 1, 이미 다른 퍼즐에 쓴 학습 단어는 -1.5.

### 품질 기준 (`generate_puzzles.py`)

- 학습 단어 비율: 초급 45%, 중급 55%, 고급 60% 이상
  - 설계서 5장은 60~70%지만, 3~7글자 초급 학습 단어가 182개뿐이라 난이도별로 낮췄다.
    설계서 2장도 초급 주요 단어를 "NGSL + 쉬운 토익 단어"로 둔다.
- 이미 저장한 퍼즐과 학습 단어 겹침 35% 이하
- 힌트(한국어 뜻 또는 영어 정의)가 없는 단어는 쓰지 않음. `--require-reviewed` 를 주면 검수한 단어만 사용

### 퍼즐 채우는 방법 (`crossword.py`)

1. 틀의 슬롯을 MRV(후보가 가장 적은 슬롯부터) + 전방 검사 + 백트래킹으로 채운다.
   후보는 점수 순(학습 단어 > 채움 단어), 같은 점수 안에서는 랜덤으로 섞는다.
2. 다 채우면 `improve()` 로 채움 단어를 학습 단어로 바꿔 본다. 영국식 격자는 단어마다 절반쯤이
   다른 단어와 겹치지 않는 칸이라, 겹치는 칸 글자만 맞으면 다른 단어를 건드리지 않고 바꿀 수 있다.
3. 후보를 여러 개(`--candidates`) 만들어 품질 점수가 가장 높은 것을 저장한다.

### 현재 결과 (2026-11-18)

| | 초급 | 중급 | 고급 |
|---|---|---|---|
| 퍼즐 (검수 전) | 9 | 11 | 12 |
| 학습 단어 비율 | 45~58% | 55~64% | 62~81% |
| 한 개 만드는 시간 (후보 30~100개) | 1초 안 | 1초 안 | 20~40초 |

- 초급은 학습 단어가 적어 9개째부터 다른 퍼즐과 겹침(35%)에 걸린다. 초급을 더 만들려면
  겹침 기준을 늘리거나 초급 학습 단어 범위(TSL 400위까지)를 넓혀야 한다.
- 한국어 뜻은 Wiktionary 번역을 자동으로 고른 초안이라, 영어 정의와 다른 뜻이 붙은 경우가 있다
  (예: TIE → "무승부"인데 정의는 "a knot"). 검수 때 고친다.

### 앱 개발용 퍼즐 넣기

검수 전이라도 앱 화면을 만들 수 있게 실제 프로젝트에 넣어 둔다. 검수가 끝나 기본 실행을 하면 검수 안 된 퍼즐은 다시 숨겨진다.

```
python3 tools/export_sql.py --dev --out /tmp/dev_seed.sql
supabase db query --remote -f /tmp/dev_seed.sql --yes
```

## ETS 토익 기출 보카 단어 합치기 (2026-11-19)

교재 엑셀(Day 1~30)의 단어를 학습 단어로 합친다. 교재 내용(한국어 뜻)이 들어가므로
원본과 결과 파일은 **공개 저장소에 올리지 않는다** (`data/raw/`, `data/words_ets.csv` 는 .gitignore).

```
pip install msoffcrypto-tool
msoffcrypto-tool -p <비밀번호> "ETS 토익 기출 보카 Day1~30 _protected.xlsx" data/raw/ets/ets_voca.xlsx
python3 tools/extract_ets.py     # Day 시트만 (Test 시트 제외), 중복 제거 → data/raw/ets/ets_words.csv
python3 tools/merge_ets.py       # words.csv + ETS → data/words_ets.csv
```

- `extract_ets.py`: 3,128개 항목 → 중복 제거 3,036개 (한 단어 2,493 · 여러 단어 표현 543)
- `merge_ets.py`: 알파벳 3~15글자 한 단어 2,491개를 합침
  - 이미 있던 단어 1,669개: 학습 단어로 바꾸고 한국어 뜻·품사를 교재 것으로 (채움→학습 981개, 예: SCHEDULE)
  - 새 단어 822개: 난이도는 Day 1~10 초급, 11~20 중급, 21~30 고급 ("토익 만점 완성"은 고급),
    영어 정의는 Wiktionary, 예문은 Tatoeba
  - 여러 단어 표현(`put on` 등)은 퍼즐·DB(`words.word` 는 알파벳만)에 넣을 수 없어 뺐다
- `generate_puzzles.py`, `review_puzzle.py`, `export_sql.py` 는 `data/words_ets.csv` 가 있으면 그것을 쓴다.
  없으면(예: 교재 파일이 없는 PC) `words.csv` 로 그대로 동작한다.

결과: 학습 단어 4,008개 (초급 920 · 중급 1,019 · 고급 2,069), 퍼즐 36개 (난이도별 12개) 모두 기준 통과,
학습 단어 비율 초급 71~88%, 중급 75~93%, 고급 81~97%.

실제 DB 입력 (단어 전체 + 개발용 퍼즐):

```
python3 tools/export_sql.py --dev --all-words --out /tmp/dev_seed.sql
supabase db query --remote -f /tmp/dev_seed.sql --yes
```
