"""TSL·BSL·NGSL과 Wiktionary·Tatoeba로 data/words.csv 를 만든다.

    python3 tools/fetch_sources.py --kaikki   # 먼저 원본 받기 (Wiktionary 포함)
    python3 tools/build_word_list.py          # 1주차: data/word_list.csv
    python3 tools/build_words.py

가공 순서 (퍼즐 제작 설계서 3.5)
 1~2. (1주차 build_word_list.py) 목록 합치기, 중복 제거, 3~11글자 알파벳, blocklist
 2'. 사전에 고유명사·약어·변화형으로만 나오는 단어 제외
 3. 빈도 순위로 난이도 분류.
 4. Wiktionary 로 한국어 뜻·영어 정의 초안.
 5. Tatoeba 예문 + 빈칸 예문.
 6. reviewed = false 로 두고 사람이 검수한다.

이미 data/words.csv 에 reviewed=true 로 표시된 행은 덮어쓰지 않고 그대로 둔다.
"""
from __future__ import annotations

import bz2
import csv
import json
import re
from pathlib import Path

import openpyxl

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
OUT = ROOT / "data" / "words.csv"
WORD_LIST = ROOT / "data" / "word_list.csv"   # 1주차 build_word_list.py 결과

COLUMNS = ["word", "type", "level", "rank", "pos", "meaning_ko", "definition_en",
           "example", "example_blank", "example_ref", "source", "reviewed"]

# 난이도 기준 (설계서 3.5 ③)
TSL_BEGINNER_MAX = 400
TSL_INTERMEDIATE_MAX = 800
NGSL_BEGINNER_MAX = 1000
NGSL_INTERMEDIATE_MAX = 2000

POS_KO = {"noun": "명사", "verb": "동사", "adj": "형용사", "adv": "부사", "prep": "전치사",
          "conj": "접속사", "pron": "대명사", "det": "한정사", "num": "수사", "intj": "감탄사"}
SKIP_POS = {"name", "abbrev", "symbol", "prefix", "suffix", "character", "phrase",
            "prep_phrase", "proverb", "contraction", "affix", "particle"}
SKIP_GLOSS_TAGS = {"form-of", "alt-of", "abbreviation", "initialism", "acronym",
                   "obsolete", "archaic", "rare", "dated", "vulgar", "offensive",
                   "derogatory", "slang", "misspelling", "nonstandard", "dialectal"}
BLANK = "_____"
STOPWORDS = {"a", "an", "the", "of", "to", "or", "and", "in", "on", "for", "by", "with", "as",
             "that", "which", "is", "be", "something", "someone", "one", "from", "at", "it"}


def read_tsl_definitions() -> dict[str, str]:
    wb = openpyxl.load_workbook(RAW / "TSL_12_definitions.xlsx", read_only=True)
    out = {}
    for row in wb.active.iter_rows(min_row=2, values_only=True):
        if row and row[0] and row[1]:
            out[str(row[0]).strip().lower()] = " ".join(str(row[1]).split())
    return out


# ---------------------------------------------------------------------------
# Wiktionary (kaikki)
# ---------------------------------------------------------------------------
def load_kaikki(word: str) -> list[dict]:
    p = RAW / "kaikki" / f"{word}.jsonl"
    if not p.exists() or p.stat().st_size == 0:
        return []
    entries = []
    for line in p.read_text(encoding="utf-8").splitlines():
        try:
            e = json.loads(line)
        except json.JSONDecodeError:
            continue
        # 대소문자가 정확히 같은 영어 항목만 (예: "may" 와 "May" 구분 → 고유명사 거르기)
        if e.get("lang_code") == "en" and e.get("word") == word:
            entries.append(e)
    return entries


def mask_word(text: str, word: str) -> str:
    """힌트 안에 정답(과 그 변화형)이 보이지 않게 가린다."""
    return re.sub(rf"\b{re.escape(word)}\w*", BLANK, text, flags=re.IGNORECASE)


def clean_gloss(g: str) -> str:
    g = re.sub(r"\s*\([^)]*\)\s*$", "", g.strip())   # 끝의 괄호 설명 제거
    return g.rstrip(".;: ")


def pick_dictionary(word: str, entries: list[dict]) -> dict | None:
    """품사, 영어 정의, 한국어 뜻을 고른다. 고유명사·약어만 있는 단어는 None."""
    usable = [e for e in entries if e.get("pos") not in SKIP_POS]
    if not usable:
        return None
    pos, gloss = None, None
    for e in usable:
        for s in e.get("senses", []):
            tags = set(s.get("tags", []))
            if tags & SKIP_GLOSS_TAGS or s.get("form_of") or s.get("alt_of"):
                continue
            gl = s.get("glosses") or []
            if gl:
                pos, gloss = e["pos"], clean_gloss(gl[-1])
                break
        if gloss:
            break
    if not gloss:  # 변화형 항목만 있는 경우 (예: 동사 과거형) → 학습 단어로 쓰지 않음
        return None

    # 한국어 번역: 고른 정의와 같은 품사 항목을 먼저, 번역의 sense 설명이 정의와 많이 겹칠수록 앞으로
    gloss_words = set(re.findall(r"[a-z]+", gloss.lower())) - STOPWORDS
    cands: list[tuple[float, int, str]] = []
    order = 0
    for e in usable:
        same_pos = e["pos"] == pos
        for t in e.get("translations", []):
            if t.get("code") != "ko" and t.get("lang_code") != "ko":
                continue
            k = (t.get("word") or "").strip()
            if not k or len(k) > 12:
                continue
            sense_words = set(re.findall(r"[a-z]+", (t.get("sense") or "").lower())) - STOPWORDS
            overlap = len(gloss_words & sense_words) / (len(gloss_words) or 1)
            cands.append((-(overlap + (0.5 if same_pos else 0)), order, k))
            order += 1
    ko: list[str] = []
    for _, _, k in sorted(cands):
        if k not in ko:
            ko.append(k)
        if len(ko) == 2:
            break
    return {"pos": POS_KO.get(pos, pos), "definition_en": gloss, "meaning_ko": ", ".join(ko)}


# ---------------------------------------------------------------------------
# Tatoeba
# ---------------------------------------------------------------------------
def find_examples(targets: set[str]) -> dict[str, tuple[str, str]]:
    """단어마다 짧고 적당한 예문 하나 (6~14 단어, 단어가 한 번만 나오는 문장)."""
    path = RAW / "eng_sentences.tsv.bz2"
    if not path.exists():
        print("  Tatoeba 파일 없음 → 예문 건너뜀")
        return {}
    best: dict[str, tuple[int, str, str]] = {}
    token_re = re.compile(r"[A-Za-z]+(?:['-][A-Za-z]+)*")  # anti-smoking 은 한 토큰
    with bz2.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            sid, text = parts[0], parts[2]
            tokens = token_re.findall(text)
            n = len(tokens)
            if not 6 <= n <= 14 or not text[:1].isupper():
                continue
            lower = [t.lower() for t in tokens]
            for t in set(lower):
                if t in targets and lower.count(t) == 1:
                    # 9단어 근처를 가장 좋게, 같은 점수면 먼저 나온(id 작은) 문장
                    score = abs(n - 9)
                    if t not in best or score < best[t][0]:
                        best[t] = (score, text, sid)
    return {w: (text, f"tatoeba:{sid}") for w, (_, text, sid) in best.items()}


def blank_example(text: str, word: str) -> str:
    return re.sub(rf"\b{re.escape(word)}\b", BLANK, text, flags=re.IGNORECASE)


# ---------------------------------------------------------------------------
def level_learn(source: str, rank: int) -> str:
    if source == "BSL":
        return "advanced"
    if rank <= TSL_BEGINNER_MAX:
        return "beginner"
    if rank <= TSL_INTERMEDIATE_MAX:
        return "intermediate"
    return "advanced"


def level_fill(rank: int) -> str:
    if rank <= NGSL_BEGINNER_MAX:
        return "beginner"
    if rank <= NGSL_INTERMEDIATE_MAX:
        return "intermediate"
    return "advanced"


def load_existing_reviewed() -> dict[str, dict]:
    if not OUT.exists():
        return {}
    with open(OUT, newline="", encoding="utf-8") as f:
        return {r["word"]: r for r in csv.DictReader(f) if r.get("reviewed") == "true"}


def main() -> None:
    if not WORD_LIST.exists():
        raise SystemExit("data/word_list.csv 가 없습니다. 먼저 python3 tools/build_word_list.py 를 실행하세요.")
    tsl_def = read_tsl_definitions()

    # 1~2. 1주차 결과(word_list.csv: 합치기·중복 제거·모양 거르기 완료)를 읽고
    # 3. 빈도 순위로 난이도를 나눈다.
    rows: dict[str, dict] = {}
    with open(WORD_LIST, newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            w, rank = r["word"].lower(), int(r["rank"])
            level = level_learn(r["source"], rank) if r["type"] == "learn" else level_fill(rank)
            rows[w] = {"word": w, "type": r["type"], "level": level, "rank": rank, "source": r["source"]}
    print(f"단어 목록: 학습 {sum(r['type'] == 'learn' for r in rows.values())}, "
          f"채움 {sum(r['type'] == 'fill' for r in rows.values())}")

    # 4. 사전
    dropped = []
    for w in list(rows):
        d = pick_dictionary(w, load_kaikki(w))
        if d is None:
            dropped.append(w)
            del rows[w]
            continue
        r = rows[w]
        r["pos"] = d["pos"]
        r["meaning_ko"] = d["meaning_ko"]
        definition = tsl_def.get(w) or d["definition_en"]
        r["definition_en"] = mask_word(definition, w)
    print(f"사전 없음·고유명사·변화형으로 제외: {len(dropped)}개")

    # 5. 예문
    examples = find_examples(set(rows))
    for w, r in rows.items():
        ex = examples.get(w)
        r["example"], r["example_ref"] = ex if ex else ("", "")
        r["example_blank"] = blank_example(ex[0], w) if ex else ""

    # 6. 검수 표시. 이미 검수한 행은 유지
    reviewed = load_existing_reviewed()
    out_rows = []
    for w, r in rows.items():
        if w.upper() in reviewed:
            out_rows.append(reviewed[w.upper()])
            continue
        r["word"] = w.upper()
        r["reviewed"] = "false"
        out_rows.append(r)
    out_rows.sort(key=lambda r: (r["type"] != "learn", r["source"], int(r["rank"])))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=COLUMNS, extrasaction="ignore")
        wr.writeheader()
        wr.writerows(out_rows)

    learn = [r for r in out_rows if r["type"] == "learn"]
    print(f"저장: {OUT.relative_to(ROOT)} ({len(out_rows)}행, 학습 {len(learn)})")
    for lv in ("beginner", "intermediate", "advanced"):
        print(f"  {lv:12} 학습 {sum(r['level'] == lv for r in learn):4}  "
              f"채움 {sum(r['level'] == lv and r['type'] == 'fill' for r in out_rows):4}")
    print(f"  한국어 뜻 있음 {sum(bool(r['meaning_ko']) for r in out_rows)}, "
          f"예문 있음 {sum(bool(r['example']) for r in out_rows)}")


if __name__ == "__main__":
    main()
