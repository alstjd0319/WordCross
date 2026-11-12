# data — 단어와 퍼즐 데이터

검수가 끝난 결과만 커밋합니다. 원본 다운로드 파일은 `data/raw/`에 두며, 커밋하지 않습니다.

## 파일

- `words.csv`: 단어 데이터
  - 열: `word, type(학습/채움), level, meaning_ko, definition_en, example, source, reviewed`
- `puzzles/*.json`: 퍼즐 하나당 파일 하나
  - 예: `{"id": "mid-001", "level": "중급", "size": [13, 13], "template": "uk-13-03", "words": [{"no": 1, "word": "SCHEDULE", "row": 0, "col": 0, "dir": "across"}], "reviewed": true}`

## 라이선스

이 폴더의 데이터는 CC BY-SA 4.0 자료(TSL, BSL, NGSL, Wiktionary)를 가공한 것이므로 같은 라이선스(CC BY-SA 4.0)를 따릅니다.
예문은 Tatoeba(CC BY 2.0 FR)에서 가져왔습니다.
