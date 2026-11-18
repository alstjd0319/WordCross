"""신문형(영국식) 격자 틀을 만들어 data/templates/ 에 저장한다.

    python3 tools/make_templates.py            # 크기별 12개
    python3 tools/make_templates.py --count 20 --seed 7

틀은 한 번 만들어 커밋해 두고, 퍼즐 생성기는 저장된 틀 중에서 고른다 (설계서 4.2).
 * 기본: (홀수 행, 홀수 열) 칸이 검은 칸 → 흰 칸이 한 칸씩 건너 교차하는 영국식 배치
 * 너무 긴 줄은 180도 대칭이 되도록 검은 칸을 더 넣어 끊는다.
 * 모든 단어는 난이도의 최소~최대 길이, 모든 흰 칸은 단어에 속하고 서로 이어져 있다.
"""
from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

from crossword import BLOCK, EMPTY, LEVELS, runs, template_problems

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "data" / "templates"


def base_grid(n: int) -> list[list[str]]:
    return [[BLOCK if r % 2 and c % 2 else EMPTY for c in range(n)] for r in range(n)]


def try_template(n: int, min_len: int, max_len: int, words: tuple[int, int],
                 rng: random.Random) -> list[str] | None:
    g = base_grid(n)

    def set_block(r: int, c: int) -> None:
        g[r][c] = BLOCK
        g[n - 1 - r][n - 1 - c] = BLOCK

    def ok_partial() -> bool:
        return all(s.length >= min_len for s in runs(["".join(x) for x in g]))

    # 길이 제한을 넘는 줄을 끊고, 목표 단어 수에 모자라면 긴 줄을 더 끊는다.
    target_words = rng.randint(*words)
    for _ in range(200):
        grid = ["".join(x) for x in g]
        sl = runs(grid)
        long_runs = [s for s in sl if s.length > max_len]
        extra = [s for s in sl if s.length >= 2 * min_len + 1] if len(sl) < target_words else []
        targets = long_runs or extra
        if not targets:
            break
        s = rng.choice(targets)
        cuts = [k for k in range(min_len, s.length - min_len)]
        rng.shuffle(cuts)
        for k in cuts:
            r, c = s.cells[k]
            saved = [row[:] for row in g]
            set_block(r, c)
            if ok_partial():
                break
            g[:] = saved
        else:
            return None
    grid = ["".join(x) for x in g]
    if template_problems(grid, min_len, max_len):
        return None
    n_words = len(runs(grid))
    if not words[0] <= n_words <= words[1]:
        return None
    return grid


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=12, help="크기별 틀 개수")
    ap.add_argument("--seed", type=int, default=2026)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for level, cfg in LEVELS.items():
        for n in cfg["sizes"]:
            made: list[list[str]] = []
            tries = 0
            while len(made) < args.count and tries < 20000:
                tries += 1
                t = try_template(n, cfg["min_len"], cfg["max_len"], cfg["words"], rng)
                if t and t not in made:
                    made.append(t)
            for k, t in enumerate(made, start=1):
                tid = f"uk-{n}-{k:02d}"
                lengths = sorted(s.length for s in runs(t))
                (OUT_DIR / f"{tid}.json").write_text(json.dumps({
                    "id": tid, "level": level, "size": [n, n],
                    "min_len": cfg["min_len"], "max_len": cfg["max_len"],
                    "word_count": len(lengths), "grid": t,
                }, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
            print(f"{level:12} {n}x{n}: 틀 {len(made)}개 ({tries}회 시도)")


if __name__ == "__main__":
    main()
