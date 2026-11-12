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
  | `rank` | 원래 목록의 빈도 순위 (2주차 난이도 분류 기준) |
  | `length` | 글자 수 |

- `words.csv` (2주차): `word_list.csv` + 힌트 데이터 (`tools/build_words.py`)

  | 열 | 내용 |
  |---|---|
  | `word`, `type`, `rank`, `source` | `word_list.csv` 와 같음 |
  | `level` | `beginner`(초급) / `intermediate`(중급) / `advanced`(고급) |
  | `pos` | 품사 |
  | `meaning_ko` | 한국어 뜻 (Wiktionary 초안 → 검수) |
  | `definition_en` | 쉬운 영어 정의 (TSL 정의 우선, 없으면 Wiktionary). 정답 철자는 `_____` 로 가림 |
  | `example` | 예문 원문 (정답 포함) |
  | `example_blank` | 빈칸 처리된 예문 (힌트) |
  | `example_ref` | 예문 출처, 예: `tatoeba:12345` |
  | `reviewed` | 사람 검수 완료 여부 (`true`/`false`) |

  검수할 때는 `meaning_ko`, `definition_en`, `example` 을 고치고 `reviewed` 를 `true` 로 바꿉니다.
  `build_words.py` 를 다시 돌려도 `reviewed=true` 행은 유지됩니다.

- `templates/*.json`: 격자 틀. `grid` 의 `#` 은 검은 칸, `.` 은 흰 칸
- `puzzles/*.json`: 퍼즐 하나당 파일 하나
  - 예: `{"id": "mid-001", "level": "intermediate", "size": [13, 13], "template": "uk-13-03", "words": [{"no": 1, "word": "SCHEDULE", "row": 0, "col": 0, "dir": "across"}], "quality": {...}, "reviewed": false}`

## 라이선스

이 폴더의 데이터는 CC BY-SA 4.0 자료(TSL, BSL, NGSL, Wiktionary)를 가공한 것이므로 같은 라이선스(CC BY-SA 4.0)를 따릅니다.
예문은 Tatoeba(CC BY 2.0 FR)에서 가져왔습니다.
