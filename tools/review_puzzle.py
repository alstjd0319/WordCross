"""퍼즐 검수 도우미: 격자와 힌트를 보여 주고, 통과하면 reviewed 를 표시한다.

    python3 tools/review_puzzle.py mid-001            # 빈 격자 + 힌트 (직접 풀어 보기)
    python3 tools/review_puzzle.py mid-001 --answers  # 정답 격자 + 단어 정보
    python3 tools/review_puzzle.py mid-001 --approve  # 검수 완료 표시
    python3 tools/review_puzzle.py --list             # 퍼즐 목록과 검수 상태
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUZZLE_DIR = ROOT / "data" / "puzzles"
TEMPLATE_DIR = ROOT / "data" / "templates"
# ETS 교재 단어를 합친 파일(merge_ets.py, 커밋 안 함)이 있으면 그것을 쓴다.
WORDS_CSV = next(p for p in (ROOT / "data" / "words_ets.csv", ROOT / "data" / "words.csv") if p.exists())


def load(pid: str) -> tuple[Path, dict]:
    p = PUZZLE_DIR / f"{pid}.json"
    return p, json.loads(p.read_text(encoding="utf-8"))


def solved_grid(puzzle: dict) -> list[list[str]]:
    t = json.loads((TEMPLATE_DIR / f"{puzzle['template']}.json").read_text(encoding="utf-8"))
    g = [list(row) for row in t["grid"]]
    for w in puzzle["words"]:
        for i, ch in enumerate(w["word"]):
            r, c = (w["row"], w["col"] + i) if w["dir"] == "across" else (w["row"] + i, w["col"])
            if g[r][c] not in (".", ch):
                raise SystemExit(f"교차 글자 불일치: {w}")
            g[r][c] = ch
    return g


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("id", nargs="?")
    ap.add_argument("--answers", action="store_true")
    ap.add_argument("--approve", action="store_true")
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    if args.list or not args.id:
        for p in sorted(PUZZLE_DIR.glob("*.json")):
            d = json.loads(p.read_text(encoding="utf-8"))
            q = d.get("quality", {})
            print(f"{d['id']:8} {d['level']:12} {d['size'][0]}x{d['size'][1]} 단어 {len(d['words']):2} "
                  f"점수 {q.get('score', '-'):>5} {'검수 완료' if d['reviewed'] else '검수 전'}")
        return

    path, puzzle = load(args.id)
    if args.approve:
        puzzle["reviewed"] = True
        path.write_text(json.dumps(puzzle, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"{args.id} 검수 완료로 표시")
        return

    with open(WORDS_CSV, newline="", encoding="utf-8") as f:
        meta = {r["word"]: r for r in csv.DictReader(f)}
    g = solved_grid(puzzle)
    for row in g:
        print(" ".join("■" if ch == "#" else (ch if args.answers else "□") for ch in row))
    for d in ("across", "down"):
        print(f"\n[{'가로' if d == 'across' else '세로'}]")
        for w in puzzle["words"]:
            if w["dir"] != d:
                continue
            m = meta.get(w["word"], {})
            head = f"{w['no']:>2}. ({len(w['word'])}) "
            if args.answers:
                head += f"{w['word']} [{m.get('type')}/{m.get('level')}] "
            print(head + (m.get("meaning_ko") or "-"))
            print(f"      {m.get('definition_en') or '-'}")
            if m.get("example_blank"):
                print(f"      예) {m['example_blank']}")


if __name__ == "__main__":
    main()
