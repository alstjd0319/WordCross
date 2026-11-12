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
| `export_sql.py` | 검수한 퍼즐과 그 단어를 `supabase/seed.sql` 로 (여러 번 실행해도 안전한 upsert) |

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

- 학습 단어 비율: 초급 50% 이상, 중급·고급 60% 이상
- 이미 저장한 퍼즐과 학습 단어 겹침 35% 이하
- 힌트(한국어 뜻 또는 영어 정의)가 없는 단어는 쓰지 않음. `--require-reviewed` 를 주면 검수한 단어만 사용
