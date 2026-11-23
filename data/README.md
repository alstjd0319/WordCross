# data — 단어와 퍼즐 데이터

가공한 결과만 커밋합니다. 원본 다운로드 파일은 `data/raw/`에 두며, 커밋하지 않습니다.
만드는 방법은 `tools/README.md` 를 보세요.

## 파일

- `word_list.csv` (1주차): 정리한 단어 목록 (`tools/build_word_list.py`)

  | 열 | 내용 |
  |---|---|
  | `word` | 대문자 영어 단어 |
  | `type` | `learn`(학습, TSL·BSL) / `fill`(채움, NGSL) |
  | `source` | `TSL` / `BSL` / `NGSL` |
  | `rank` | 원래 목록의 순위 (참고용. 난이도는 영어 예문 빈도로 정함) |
  | `length` | 글자 수 |

- `words.csv` (2주차): `word_list.csv` + 힌트 데이터 (`tools/build_words.py`)

  | 열 | 내용 |
  |---|---|
  | `word`, `type`, `rank`, `source` | `word_list.csv` 와 같음 |
  | `level` | `beginner`(초급) / `intermediate`(중급) / `advanced`(고급). Tatoeba 영어 예문에 300회 이상 초급, 60~299회 중급, 그 미만 고급 |
  | `pos` | 품사 |
  | `meaning_ko` | 한국어 뜻 (Wiktionary 초안, 없으면 `meanings_ko_draft.csv`, ETS 단어는 교재 뜻) |
  | `definition_en` | 쉬운 영어 정의 (TSL 정의 우선, 없으면 Wiktionary 첫 뜻, 80자 이내). 정답 철자는 `_____` 로 가림 |
  | `example` | 예문 원문 (정답 포함) |
  | `example_blank` | 빈칸 처리된 예문 (힌트) |
  | `example_ref` | 예문 출처: `tatoeba:12345`, 직접 쓴 예문은 `team` |
  | `reviewed` | 사람 검수 완료 여부 (`true`/`false`) |

  **이 파일을 직접 고치지 않습니다.** 다시 만들 때마다 덮어써지고, ETS 교재 단어에는 반영되지 않습니다.
  힌트를 고칠 때는 `hint_overrides.csv` 에 적습니다 (아래).

- `hint_overrides.csv`: 사람이 고친 힌트. 사전·교재 데이터보다 우선 적용된다
  - 열: `word`, `meaning_ko`, `definition_en`, `example`(정답 단어가 그대로 든 문장, 빈칸은 자동), `note`
  - 빈 칸은 원래 값을 그대로 둔다
- `meanings_ko_draft.csv`: Wiktionary 에 한국어 번역이 없던 단어의 뜻 초안 (직접 작성)
- 검수 완료 표시: 퍼즐을 직접 풀어 보고 `python3 tools/review_puzzle.py <id> --approve` 하면,
  `export_sql.py` 가 그 퍼즐과 퍼즐에 든 단어를 모두 `reviewed=true` 로 DB 에 넣는다 (기획서 7장)

- `templates/*.json`: 격자 틀. `grid` 의 `#` 은 검은 칸, `.` 은 흰 칸
- `puzzles/*.json`: 퍼즐 하나당 파일 하나
  - 예: `{"id": "mid-001", "level": "intermediate", "size": [13, 13], "template": "uk-13-03", "words": [{"no": 1, "word": "SCHEDULE", "row": 0, "col": 0, "dir": "across"}], "quality": {...}, "reviewed": false}`

## 라이선스

이 폴더의 데이터는 CC BY-SA 4.0 자료(TSL, BSL, NGSL, Wiktionary)를 가공한 것이므로 같은 라이선스(CC BY-SA 4.0)를 따릅니다.
예문은 Tatoeba(CC BY 2.0 FR)에서 가져왔습니다.
