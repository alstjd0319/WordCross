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

- 2주차 예정
  - `words.csv`: `word_list.csv` + 난이도, 품사, 한국어 뜻, 영어 정의, 예문, 빈칸 예문, 예문 출처, 검수 여부
  - `templates/*.json`: 격자 틀
  - `puzzles/*.json`: 퍼즐 하나당 파일 하나
    - 예: `{"id": "mid-001", "level": "intermediate", "size": [13, 13], "template": "uk-13-03", "words": [{"no": 1, "word": "SCHEDULE", "row": 0, "col": 0, "dir": "across"}], "reviewed": true}`

## 라이선스

이 폴더의 데이터는 CC BY-SA 4.0 자료(TSL, BSL, NGSL, Wiktionary)를 가공한 것이므로 같은 라이선스(CC BY-SA 4.0)를 따릅니다.
예문은 Tatoeba(CC BY 2.0 FR)에서 가져왔습니다.
