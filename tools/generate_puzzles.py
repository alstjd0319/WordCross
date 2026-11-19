"""격자 틀 + 단어 DB 로 퍼즐을 생성하고, 품질 점수가 높은 것만 data/puzzles/ 에 저장한다.

    python3 tools/generate_puzzles.py --level intermediate --count 5
    python3 tools/generate_puzzles.py --level beginner --count 3 --candidates 30 --seed 1

흐름 (설계서 4.1): 틀 고르기 → 슬롯 추출 → CSP 채우기 → 품질 평가 → (사람 검수) → JSON 저장
퍼즐 한 개마다 후보를 --candidates 개 만들어 점수가 가장 높은 것을 남긴다.
저장된 퍼즐은 reviewed=false 이며, review_puzzle.py 로 풀어 보고 검수 표시한다.
"""
from __future__ import annotations

import argparse
import csv
import json
import random
import time
from pathlib import Path

from crossword import LEVEL_ORDER, LEVELS, Filler, Timeout, WordIndex

ROOT = Path(__file__).resolve().parent.parent
# ETS 교재 단어를 합친 파일(merge_ets.py, 커밋 안 함)이 있으면 그것을 쓴다.
WORDS_CSV = next(p for p in (ROOT / "data" / "words_ets.csv", ROOT / "data" / "words.csv") if p.exists())
TEMPLATE_DIR = ROOT / "data" / "templates"
PUZZLE_DIR = ROOT / "data" / "puzzles"

# 품질 기준 (설계서 5장)
# 초급은 3~7글자 학습 단어가 182개뿐이라(설계서도 초급 주요 단어를 "NGSL + 쉬운 토익 단어"로 둠)
# 난이도별로 단어 수에 맞춰 둔다. 설계서 5장의 60~70%는 고급만 맞춘다.
MIN_LEARN_RATIO = {"beginner": 0.45, "intermediate": 0.55, "advanced": 0.6}
MAX_OVERLAP = 0.35          # 이미 만든 퍼즐과 학습 단어가 이 비율 넘게 겹치면 탈락


def load_words(require_reviewed: bool) -> list[dict]:
    with open(WORDS_CSV, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    usable = []
    for r in rows:
        if require_reviewed and r["reviewed"] != "true":
            continue
        if not (r["meaning_ko"] or r["definition_en"]):   # 힌트 없는 단어는 쓰지 않음
            continue
        usable.append(r)
    return usable


def word_pool(rows: list[dict], level: str, reused: set[str]) -> tuple[list[str], dict[str, float]]:
    """난이도에 맞는 단어와 점수. 학습 단어(같은 난이도) 3 > 학습 단어(쉬운 난이도) 2 > 채움 단어 1."""
    li = LEVEL_ORDER.index(level)
    words, scores = [], {}
    for r in rows:
        w, wl = r["word"], LEVEL_ORDER.index(r["level"])
        if r["type"] == "learn":
            if wl > li:
                continue              # 더 어려운 학습 단어는 넣지 않음
            s = 3.0 if wl == li else 2.0
            if w in reused:
                s -= 1.5              # 다른 퍼즐에서 이미 쓴 학습 단어는 덜 고름
        else:
            if level == "beginner" and wl == 2:
                continue              # 초급에는 어려운 채움 단어 제외
            s = 1.0
        words.append(w)
        scores[w] = s
    return words, scores


def load_templates(level: str) -> list[dict]:
    out = []
    for p in sorted(TEMPLATE_DIR.glob("*.json")):
        t = json.loads(p.read_text(encoding="utf-8"))
        if t["level"] == level:
            out.append(t)
    return out


def load_existing() -> list[dict]:
    PUZZLE_DIR.mkdir(parents=True, exist_ok=True)
    return [json.loads(p.read_text(encoding="utf-8")) for p in sorted(PUZZLE_DIR.glob("*.json"))]


def evaluate(level: str, words: list[str], meta: dict[str, dict], used_learn: set[str]) -> dict:
    learn = [w for w in words if meta[w]["type"] == "learn"]
    on_level = [w for w in learn if meta[w]["level"] == level]
    overlap = len([w for w in learn if w in used_learn]) / max(1, len(learn))
    with_example = sum(bool(meta[w]["example_blank"]) for w in words) / len(words)
    with_ko = sum(bool(meta[w]["meaning_ko"]) for w in words) / len(words)
    learn_ratio = len(learn) / len(words)
    passed = learn_ratio >= MIN_LEARN_RATIO[level] and overlap <= MAX_OVERLAP
    score = (learn_ratio * 50 + len(on_level) / len(words) * 25 + with_ko * 15
             + with_example * 10 - overlap * 30)
    return {"score": round(score, 1), "passed": passed, "learn_ratio": round(learn_ratio, 2),
            "on_level": len(on_level), "overlap": round(overlap, 2),
            "with_meaning_ko": round(with_ko, 2), "with_example": round(with_example, 2)}


def generate_one(level: str, templates: list[dict], index: WordIndex, rng: random.Random,
                 time_limit: float) -> tuple[dict, list] | None:
    t = rng.choice(templates)
    filler = Filler(t["grid"], index, rng, time_limit=time_limit)
    try:
        if not filler.solve():
            return None
    except Timeout:
        return None
    filler.improve()   # 채움 단어를 교차 글자만 맞는 학습 단어로 바꿔 학습 단어 비율을 높인다
    return t, filler.result()[1]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", choices=LEVEL_ORDER, required=True)
    ap.add_argument("--count", type=int, default=1, help="저장할 퍼즐 수")
    ap.add_argument("--candidates", type=int, default=20, help="퍼즐 하나당 만들어 볼 후보 수")
    ap.add_argument("--time-limit", type=float, default=5.0, help="후보 하나 채우기 제한 시간(초)")
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument("--require-reviewed", action="store_true", help="검수한 단어만 사용")
    args = ap.parse_args()

    rng = random.Random(args.seed)
    rows = load_words(args.require_reviewed)
    meta = {r["word"]: r for r in rows}
    templates = load_templates(args.level)
    existing = load_existing()
    used_learn = {w["word"] for p in existing for w in p["words"]
                  if w["word"] in meta and meta[w["word"]]["type"] == "learn"}
    prefix = LEVELS[args.level]["prefix"]
    next_no = 1 + max([int(p["id"].split("-")[1]) for p in existing
                       if p["id"].startswith(prefix + "-")] or [0])

    for k in range(args.count):
        words, scores = word_pool(rows, args.level, used_learn)
        index = WordIndex(words, scores)
        best = None
        started = time.monotonic()
        made = 0
        for _ in range(args.candidates * 5):          # 실패한 시도는 세지 않고 다시
            if made >= args.candidates:
                break
            res = generate_one(args.level, templates, index, rng, args.time_limit)
            if not res:
                continue
            made += 1
            t, pairs = res
            q = evaluate(args.level, [w for _, w in pairs], meta, used_learn)
            if best is None or (q["passed"], q["score"]) > (best[2]["passed"], best[2]["score"]):
                best = (t, pairs, q)
        if best is None or not best[2]["passed"]:
            print(f"[{k + 1}/{args.count}] 기준을 넘는 퍼즐을 못 만듦 "
                  f"(후보 {made}개, 최고 {best[2] if best else '-'})")
            continue

        t, pairs, q = best
        pid = f"{prefix}-{next_no:03d}"
        next_no += 1
        puzzle = {
            "id": pid, "level": args.level, "size": t["size"], "template": t["id"],
            "words": [{"no": s.no, "word": w, "row": s.row, "col": s.col, "dir": s.dir}
                      for s, w in pairs],
            "quality": q,
            "reviewed": False,
        }
        (PUZZLE_DIR / f"{pid}.json").write_text(
            json.dumps(puzzle, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        used_learn |= {w for _, w in pairs if meta[w]["type"] == "learn"}
        print(f"[{k + 1}/{args.count}] {pid} ({t['id']}, 단어 {len(pairs)}개) 점수 {q['score']} "
              f"학습 비율 {q['learn_ratio']} 겹침 {q['overlap']} "
              f"— 후보 {made}개, {time.monotonic() - started:.1f}초")


if __name__ == "__main__":
    main()
