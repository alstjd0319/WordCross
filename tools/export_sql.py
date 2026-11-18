"""검수한 단어와 퍼즐을 Supabase 입력용 SQL 로 바꾼다 → supabase/seed.sql

    python3 tools/export_sql.py                 # 검수 완료(reviewed=true) 퍼즐만
    python3 tools/export_sql.py --all           # 검수 전 퍼즐도 넣되 앱에는 숨김 (published=false)
    python3 tools/export_sql.py --dev --out /tmp/dev_seed.sql   # 개발용: 검수 전 퍼즐도 앱에 공개

 * --dev 로 넣은 검수 전 퍼즐은 기본 실행(검수 완료만)을 다시 하면 숨겨진다 (published=false).

 * 퍼즐에 쓰인 단어만 words 에 넣는다 (word 기준 upsert).
 * 퍼즐은 id 기준 upsert, puzzle_words 는 지우고 다시 넣는다. 같은 파일을 여러 번 실행해도 안전하다.
 * 로컬: supabase db reset 때 seed.sql 이 자동 실행된다.
   실제 프로젝트: supabase db push 후 SQL Editor 나 psql 로 seed.sql 을 실행한다.
"""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WORDS_CSV = ROOT / "data" / "words.csv"
PUZZLE_DIR = ROOT / "data" / "puzzles"
TEMPLATE_DIR = ROOT / "data" / "templates"
OUT = ROOT / "supabase" / "seed.sql"

WORD_COLS = ["word", "type", "level", "pos", "meaning_ko", "definition_en",
             "example", "example_blank", "example_ref", "source", "reviewed"]


def q(v) -> str:
    if v is None or v == "":
        return "null"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    return "'" + str(v).replace("'", "''") + "'"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true", help="검수 전 퍼즐도 포함 (공개하지 않음)")
    ap.add_argument("--dev", action="store_true",
                    help="개발용: 검수 전 퍼즐도 포함하고 앱에 공개 (앱 화면 개발·시험용)")
    ap.add_argument("--out", type=Path, default=OUT, help=f"저장할 파일 (기본 {OUT.relative_to(ROOT)})")
    args = ap.parse_args()
    if args.dev:
        args.all = True

    with open(WORDS_CSV, newline="", encoding="utf-8") as f:
        meta = {r["word"]: r for r in csv.DictReader(f)}
    puzzles = [json.loads(p.read_text(encoding="utf-8")) for p in sorted(PUZZLE_DIR.glob("*.json"))]
    puzzles = [p for p in puzzles if args.all or p["reviewed"]]
    used = sorted({w["word"] for p in puzzles for w in p["words"]})
    missing = [w for w in used if w not in meta]
    if missing:
        raise SystemExit(f"words.csv 에 없는 단어: {missing}")

    out = ["-- tools/export_sql.py 가 만든 파일입니다. 직접 고치지 마세요.",
           "-- 단어: TSL·BSL·NGSL (CC BY-SA 4.0), Wiktionary (CC BY-SA), 예문: Tatoeba (CC BY 2.0 FR)",
           "begin;", ""]
    if used:
        out.append(f"insert into public.words ({', '.join(WORD_COLS)}) values")
        vals = []
        for w in used:
            r = meta[w]
            vals.append("  (" + ", ".join(
                q(r["reviewed"] == "true") if c == "reviewed" else q(r[c]) for c in WORD_COLS) + ")")
        out.append(",\n".join(vals))
        out.append("on conflict (word) do update set " + ", ".join(
            f"{c} = excluded.{c}" for c in WORD_COLS if c != "word") + ";")
        out.append("")

    for p in puzzles:
        t = json.loads((TEMPLATE_DIR / f"{p['template']}.json").read_text(encoding="utf-8"))
        blocks = [[r, c] for r, row in enumerate(t["grid"]) for c, ch in enumerate(row) if ch == "#"]
        out.append(
            "insert into public.puzzles (id, level, rows, cols, template, blocks, word_count, reviewed, published) "
            f"values ({q(p['id'])}, {q(p['level'])}, {p['size'][0]}, {p['size'][1]}, {q(p['template'])}, "
            f"{q(json.dumps(blocks))}::jsonb, {len(p['words'])}, {q(p['reviewed'])}, {q(p['reviewed'] or args.dev)})\n"
            "on conflict (id) do update set level = excluded.level, rows = excluded.rows, cols = excluded.cols, "
            "template = excluded.template, blocks = excluded.blocks, word_count = excluded.word_count, "
            "reviewed = excluded.reviewed, published = excluded.published;")
        out.append(f"delete from public.puzzle_words where puzzle_id = {q(p['id'])};")
        out.append("insert into public.puzzle_words (puzzle_id, no, dir, row, col, length, word_id) values")
        out.append(",\n".join(
            f"  ({q(p['id'])}, {w['no']}, {q(w['dir'])}, {w['row']}, {w['col']}, {len(w['word'])}, "
            f"(select id from public.words where word = {q(w['word'])}))" for w in p["words"]) + ";")
        out.append("")
    if not args.dev:
        # 개발용으로 공개했던 검수 전 퍼즐을 다시 숨긴다.
        out.append("update public.puzzles set published = false where not reviewed;")
    out.append("commit;")
    args.out.write_text("\n".join(out) + "\n", encoding="utf-8")
    shown = args.out.relative_to(ROOT) if args.out.is_relative_to(ROOT) else args.out
    print(f"저장: {shown} (퍼즐 {len(puzzles)}개, 단어 {len(used)}개, 공개 {'전체(개발용)' if args.dev else '검수 완료만'})")


if __name__ == "__main__":
    main()
