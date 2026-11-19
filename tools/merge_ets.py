"""ETS 토익 기출 보카 단어를 단어 데이터에 합친다 → data/words_ets.csv (커밋 안 함)

    python3 tools/extract_ets.py     # data/raw/ets/ets_words.csv
    python3 tools/merge_ets.py

규칙
 * 퍼즐·DB에 넣을 수 있는 한 단어(알파벳 3~15글자)만 쓴다. 여러 단어 표현은 건너뛴다.
 * 이미 words.csv 에 있는 단어: 학습 단어로 바꾸고, 한국어 뜻·품사는 교재 것으로 바꾼다.
   난이도는 기존 것(영어 예문 빈도 기준)을 그대로 둔다. source 에 "+ETS" 를 붙인다.
 * 새 단어: 학습 단어, 난이도는 다른 단어와 같이 영어 예문 빈도로 (교재 Day 순서는 난이도가 아니라 주제 순이라 쓰지 않음).
   영어 정의는 Wiktionary, 예문은 Tatoeba.
 * blocklist.txt 단어와 같은 단어의 중복은 뺀다.

교재 내용(한국어 뜻)이 들어가므로 결과는 공개 저장소에 올리지 않는다(.gitignore).
generate_puzzles.py · review_puzzle.py · export_sql.py 는 이 파일이 있으면 words.csv 대신 쓴다.
"""
from __future__ import annotations

import csv
import re
from pathlib import Path

from build_words import (COLUMNS, blank_example, find_examples, level_by_frequency, load_kaikki,
                         mask_word, pick_dictionary, word_frequencies)

ROOT = Path(__file__).resolve().parent.parent
BASE = ROOT / "data" / "words.csv"
ETS = ROOT / "data" / "raw" / "ets" / "ets_words.csv"
OUT = ROOT / "data" / "words_ets.csv"
BLOCKLIST = Path(__file__).resolve().parent / "blocklist.txt"

WORD_RE = re.compile(r"^[a-z]{3,15}$")


def main() -> None:
    blocked = {l.strip().lower() for l in BLOCKLIST.read_text(encoding="utf-8").splitlines()
               if l.strip() and not l.startswith("#")}
    with open(BASE, newline="", encoding="utf-8") as f:
        base = {r["word"]: r for r in csv.DictReader(f)}
    with open(ETS, newline="", encoding="utf-8") as f:
        ets = [r for r in csv.DictReader(f) if WORD_RE.match(r["word"]) and r["word"] not in blocked]

    freq = word_frequencies({e["word"] for e in ets if e["word"].upper() not in base})
    upgraded = new = skipped = 0
    new_rows: dict[str, dict] = {}
    for e in ets:
        W = e["word"].upper()
        if W in base:
            r = base[W]
            if r["type"] == "fill":
                upgraded += 1
            r["type"] = "learn"
            r["meaning_ko"] = e["meaning_ko"] or r["meaning_ko"]
            r["pos"] = e["pos"] or r["pos"]
            if "ETS" not in r["source"]:
                r["source"] += "+ETS"
            continue
        d = pick_dictionary(e["word"], load_kaikki(e["word"]))
        if d is None and not e["meaning_ko"]:
            skipped += 1
            continue
        new_rows[W] = {"word": W, "type": "learn", "level": level_by_frequency(freq[e["word"]]),
                       "rank": e["day"], "pos": e["pos"] or (d["pos"] if d else ""),
                       "meaning_ko": e["meaning_ko"],
                       "definition_en": mask_word(d["definition_en"], e["word"]) if d else "",
                       "source": "ETS", "reviewed": "false"}
        new += 1

    examples = find_examples({w.lower() for w in new_rows})
    for W, r in new_rows.items():
        ex = examples.get(W.lower())
        r["example"], r["example_ref"] = ex if ex else ("", "")
        r["example_blank"] = blank_example(ex[0], W.lower()) if ex else ""

    rows = list(base.values()) + list(new_rows.values())
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=COLUMNS, extrasaction="ignore")
        wr.writeheader()
        wr.writerows(rows)

    learn = [r for r in rows if r["type"] == "learn"]
    print(f"저장: {OUT.relative_to(ROOT)} ({len(rows)}행, 학습 {len(learn)})")
    print(f"  ETS 한 단어 {len(ets)}개 → 기존 단어 갱신 {len(ets) - new - skipped} "
          f"(채움→학습 {upgraded}), 새 단어 {new}, 사전·뜻 없어 제외 {skipped}")
    for lv in ("beginner", "intermediate", "advanced"):
        print(f"  {lv:12} 학습 {sum(r['level'] == lv for r in learn):4}")
    print(f"  한국어 뜻 있음 {sum(bool(r['meaning_ko']) for r in rows)}, 예문 있음 {sum(bool(r['example']) for r in rows)}")


if __name__ == "__main__":
    main()
