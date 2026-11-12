"""단어 목록·사전·예문 원본을 data/raw/ 에 내려받는다.

    python3 tools/fetch_sources.py            # 단어 목록 + Tatoeba 예문
    python3 tools/fetch_sources.py --kaikki   # + 단어별 Wiktionary(kaikki) 항목 (build_words 전에 필요)

이미 받은 파일은 다시 받지 않는다. data/raw/ 는 커밋하지 않는다.
"""
from __future__ import annotations

import argparse
import csv
import sys
import time
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
KAIKKI_DIR = RAW / "kaikki"

NGSL_BASE = "https://www.newgeneralservicelist.com/s/"
LIST_FILES = [
    "TSL_12_stats.csv",          # TOEIC Service List: 단어, 순위
    "TSL_12_definitions.xlsx",   # TSL 쉬운 영어 정의
    "BSL_120_stats.csv",         # Business Service List
    "NGSL_12_stats.csv",         # New General Service List (채움 단어)
]
TATOEBA_FILES = {
    "eng_sentences.tsv.bz2":
        "https://downloads.tatoeba.org/exports/per_language/eng/eng_sentences.tsv.bz2",
}
KAIKKI_URL = "https://kaikki.org/dictionary/English/meaning/{a}/{ab}/{w}.jsonl"
USER_AGENT = "WordCross-tools/0.1 (student project; data prep)"


def read_text_any(path: Path) -> str:
    """목록 CSV 중 일부는 UTF-8이 아니라 Windows-1252로 저장돼 있다."""
    data = path.read_bytes()
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return data.decode("cp1252", errors="replace")


def download(url: str, dest: Path) -> bool:
    if dest.exists() and dest.stat().st_size > 0:
        return True
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    for attempt in range(3):
        try:
            tmp = dest.with_suffix(dest.suffix + ".part")
            with urllib.request.urlopen(req, timeout=60) as r, open(tmp, "wb") as f:
                while chunk := r.read(1 << 16):
                    f.write(chunk)
            tmp.replace(dest)  # 다 받은 뒤에만 이름을 바꿔, 중간에 끊긴 파일이 남지 않게
            return True
        except urllib.error.HTTPError as e:
            if e.code == 404:
                dest.write_bytes(b"")  # 없음 표시: 빈 파일 (다시 요청하지 않음)
                return False
            time.sleep(1 + attempt)
        except Exception:
            time.sleep(1 + attempt)
    print(f"  실패: {url}", file=sys.stderr)
    return False


def candidate_words() -> list[str]:
    """kaikki 항목을 받을 단어: 세 목록의 3~11글자 알파벳 단어."""
    words: set[str] = set()
    for name in ("TSL_12_stats.csv", "BSL_120_stats.csv", "NGSL_12_stats.csv"):
        for row in csv.reader(read_text_any(RAW / name).splitlines()):
            w = (row[0] if row else "").strip().lower()
            if w.isascii() and w.isalpha() and 3 <= len(w) <= 11:
                words.add(w)
    return sorted(words)


def kaikki_path(word: str) -> Path:
    return KAIKKI_DIR / f"{word}.jsonl"


def fetch_kaikki(word: str) -> bool:
    url = KAIKKI_URL.format(a=word[0], ab=word[:2], w=urllib.parse.quote(word))
    return download(url, kaikki_path(word))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kaikki", action="store_true", help="단어별 Wiktionary 항목도 받기")
    ap.add_argument("--workers", type=int, default=4)
    args = ap.parse_args()

    for name in LIST_FILES:
        print("목록", name, "ok" if download(NGSL_BASE + name, RAW / name) else "실패")
    for name, url in TATOEBA_FILES.items():
        print("예문", name, "ok" if download(url, RAW / name) else "실패")

    if args.kaikki:
        words = candidate_words()
        todo = [w for w in words if not kaikki_path(w).exists()]
        print(f"kaikki: 전체 {len(words)}개, 새로 받을 {len(todo)}개")
        done = 0
        with ThreadPoolExecutor(max_workers=args.workers) as ex:
            for _ in ex.map(fetch_kaikki, todo):
                done += 1
                if done % 200 == 0:
                    print(f"  {done}/{len(todo)}")
        missing = sum(1 for w in words if kaikki_path(w).stat().st_size == 0)
        print(f"kaikki 완료. 항목 없는 단어 {missing}개")


if __name__ == "__main__":
    main()
