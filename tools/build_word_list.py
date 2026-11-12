"""토익 단어 목록 정리 (1주차) → data/word_list.csv

    python3 tools/fetch_sources.py      # 먼저 원본 목록 받기 (data/raw/)
    python3 tools/build_word_list.py

하는 일 (퍼즐 제작 설계서 3.5 ①②)
 1. TSL + BSL 을 합치고 중복을 제거한다 → 학습 단어(learn). 두 목록에 다 있으면 TSL 을 따른다.
 2. NGSL 은 채움 단어(fill)로 따로 둔다. 학습 단어와 겹치면 학습 단어로만 남긴다.
 3. 3~11글자 알파벳 단어만 남긴다. 하이픈·띄어쓰기·숫자가 든 표현과 blocklist 단어는 뺀다.

난이도 분류, 한국어 뜻·영어 정의·예문(설계서 ③~⑤)은 2주차에 이 파일을 입력으로 붙인다.
고유명사·약어 거르기도 사전 데이터가 필요하므로 2주차에 한다.
"""
from __future__ import annotations

import csv
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
OUT = ROOT / "data" / "word_list.csv"
BLOCKLIST = Path(__file__).resolve().parent / "blocklist.txt"

MIN_LEN, MAX_LEN = 3, 11
WORD_RE = re.compile(r"^[a-z]+$")
SOURCES = [  # (파일, 목록 이름, 종류) — 앞에 있는 목록이 우선
    ("TSL_12_stats.csv", "TSL", "learn"),
    ("BSL_120_stats.csv", "BSL", "learn"),
    ("NGSL_12_stats.csv", "NGSL", "fill"),
]


def read_text_any(path: Path) -> str:
    """목록 CSV 중 일부는 UTF-8이 아니라 Windows-1252로 저장돼 있다."""
    data = path.read_bytes()
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return data.decode("cp1252", errors="replace")


def read_ranked(name: str) -> list[tuple[str, int]]:
    reader = csv.reader(read_text_any(RAW / name).splitlines())
    next(reader)  # 머리글
    out = []
    for rank, row in enumerate(reader, start=1):
        if row and row[0].strip():
            out.append((row[0].strip().lower(), rank))
    return out


def load_blocklist() -> set[str]:
    if not BLOCKLIST.exists():
        return set()
    return {l.strip().lower() for l in BLOCKLIST.read_text(encoding="utf-8").splitlines()
            if l.strip() and not l.startswith("#")}


def exclusion_reason(w: str, blocked: set[str]) -> str | None:
    if not WORD_RE.match(w):
        return "알파벳 외 문자(하이픈·띄어쓰기 등)"
    if not MIN_LEN <= len(w) <= MAX_LEN:
        return "길이 3~11 밖"
    if w in blocked:
        return "blocklist"
    return None


def main() -> None:
    blocked = load_blocklist()
    rows: dict[str, dict] = {}
    excluded: Counter[str] = Counter()
    duplicates: Counter[str] = Counter()

    for fname, source, wtype in SOURCES:
        for w, rank in read_ranked(fname):
            reason = exclusion_reason(w, blocked)
            if reason:
                excluded[f"{source}: {reason}"] += 1
                continue
            if w in rows:
                duplicates[f"{source} → {rows[w]['source']}"] += 1
                continue
            rows[w] = {"word": w.upper(), "type": wtype, "source": source,
                       "rank": rank, "length": len(w)}

    out = sorted(rows.values(), key=lambda r: ([s for _, s, _ in SOURCES].index(r["source"]), r["rank"]))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=["word", "type", "source", "rank", "length"])
        wr.writeheader()
        wr.writerows(out)

    print(f"저장: {OUT.relative_to(ROOT)} ({len(out)}개)")
    for source in ("TSL", "BSL", "NGSL"):
        n = sum(r["source"] == source for r in out)
        print(f"  {source:5} {n:5}개")
    print(f"  학습 단어 {sum(r['type'] == 'learn' for r in out)}개, 채움 단어 {sum(r['type'] == 'fill' for r in out)}개")
    print("제외:")
    for k, v in sorted(excluded.items()):
        print(f"  {k}: {v}")
    print("중복 (뒤 목록 → 남긴 목록):")
    for k, v in sorted(duplicates.items()):
        print(f"  {k}: {v}")
    lengths = Counter(r["length"] for r in out if r["type"] == "learn")
    print("학습 단어 길이 분포:", " ".join(f"{L}:{lengths[L]}" for L in sorted(lengths)))


if __name__ == "__main__":
    main()
