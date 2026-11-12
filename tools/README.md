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

## 2주차 이후 예정

- 난이도 분류, Wiktionary 로 한국어 뜻·영어 정의 초안, Tatoeba 예문 → `data/words.csv`
- 격자 틀, 퍼즐 생성(CSP), 품질 평가 → `data/templates/`, `data/puzzles/`
- 검수한 데이터를 Supabase 입력용 SQL 로 변환
