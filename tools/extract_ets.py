"""ETS 토익 기출 보카(Day 1~30) 엑셀에서 단어를 뽑는다 → data/raw/ets/ets_words.csv

    # 암호 걸린 원본을 한 번 풀어 data/raw/ets/ets_voca.xlsx 로 둔다 (커밋 안 함)
    pip install msoffcrypto-tool
    msoffcrypto-tool -p <비밀번호> "ETS 토익 기출 보카 Day1~30 _protected.xlsx" data/raw/ets/ets_voca.xlsx
    python3 tools/extract_ets.py

 * "Day N" 시트만 읽고 "Test" 시트는 건너뛴다 (Day 단어를 다시 나열한 시험지).
 * 시트마다 기본 목록(번호·단어·뜻)과 오른쪽 추가 목록이 있어서, 행마다 (번호, 영어, 뜻) 묶음을 모두 찾는다.
 * 같은 단어(대소문자·공백 무시)는 처음 나온 것 하나만 남긴다.
 * 교재 내용이므로 결과는 data/raw/ 아래(커밋 안 함)에만 둔다.
"""
from __future__ import annotations

import csv
import re
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "raw" / "ets" / "ets_voca.xlsx"
OUT = ROOT / "data" / "raw" / "ets" / "ets_words.csv"

POS_MAP = {"v": "동사", "n": "명사", "a": "형용사", "adj": "형용사", "ad": "부사", "adv": "부사",
           "prep": "전치사", "conj": "접속사", "phr": "구", "pron": "대명사"}
EN_RE = re.compile(r"^[A-Za-z][A-Za-z ()'\-./~,]*$")
HANGUL_RE = re.compile(r"[가-힣]")


def split_meaning(raw: str) -> tuple[str, str]:
    """'v. 들다, 잡다\\nn. 그늘' → ('동사, 명사', '들다, 잡다; 그늘')"""
    pos, parts = [], []
    for line in re.split(r"\n|(?=\b(?:v|n|a|adj|ad|adv|prep|conj|phr|pron)\.\s)", raw.strip()):
        line = line.strip()
        if not line:
            continue
        m = re.match(r"^(v|n|a|adj|ad|adv|prep|conj|phr|pron)\.\s*(.*)$", line)
        if m:
            p = POS_MAP[m.group(1)]
            if p not in pos:
                pos.append(p)
            line = m.group(2).strip()
        if line:
            parts.append(line)
    return ", ".join(pos), "; ".join(parts)


def normalize(word: str) -> str:
    """대소문자·공백 정리. '(re)pave' → 'repave', 'pack (up)' → 'pack up'."""
    w = word.strip().lower()
    w = re.sub(r"^\((\w+)\)(\w)", r"\1\2", w)      # (re)pave → repave
    w = re.sub(r"\s*\([^)]*\)", "", w)               # pack (up) → pack
    return re.sub(r"\s+", " ", w).strip()


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"{SRC.relative_to(ROOT)} 가 없습니다. 위 설명대로 원본 암호를 풀어 두세요.")
    wb = openpyxl.load_workbook(SRC, read_only=True, data_only=True)
    seen: dict[str, dict] = {}
    total = 0
    for name in wb.sheetnames:
        m = re.match(r"^Day\s*(\d+)$", name.strip())
        if not m:
            continue                                     # Test 시트 제외
        day = int(m.group(1))
        section = ""
        for row in wb[name].iter_rows(values_only=True):
            cells = ["" if c is None else str(c).strip() for c in row]
            if cells and cells[0].startswith("<DAY"):
                section = cells[0]
            for i in range(len(cells) - 1):
                num, word = cells[i], cells[i + 1]
                if not num.isdigit() or not EN_RE.match(word):
                    continue
                meaning = cells[i + 2] if i + 2 < len(cells) else ""
                if not HANGUL_RE.search(meaning):
                    continue
                total += 1
                key = normalize(word)
                if key in seen:
                    continue
                pos, ko = split_meaning(meaning)
                tag = cells[i + 3] if i + 3 < len(cells) and not cells[i + 3].isdigit() else ""
                seen[key] = {"word": key, "day": day, "list": "main" if i < 10 else "extra",
                             "pos": pos, "meaning_ko": ko, "tag": tag, "section": section,
                             "single": bool(re.fullmatch(r"[a-z]+", key))}
    rows = list(seen.values())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0]))
        wr.writeheader()
        wr.writerows(rows)
    single = [r for r in rows if r["single"]]
    print(f"Day 시트에서 읽은 항목 {total}개 → 중복 제거 {len(rows)}개 ({OUT.relative_to(ROOT)})")
    print(f"  한 단어 {len(single)}개, 여러 단어 표현 {len(rows) - len(single)}개 (퍼즐에는 한 단어만 사용)")
    print(f"  3~11글자 한 단어 {sum(3 <= len(r['word']) <= 11 for r in single)}개")


if __name__ == "__main__":
    main()
