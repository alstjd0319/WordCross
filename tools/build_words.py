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

# 난이도 기준: 영어 예문(Tatoeba 약 200만 문장)에 나온 횟수.
# 목록 순위(TSL 순위)는 토익 안에서의 빈도라 일상적인 쉬움과 잘 맞지 않아서(예: prune, courier 가 초급) 바꿨다.
# 설계서 예시 단어: 초급 apple 1,265·water 7,555회, 중급 improve 800·journey 609회, 고급 adequate 47회.
FREQ_BEGINNER_MIN = 300      # 300회 이상 → 초급
FREQ_INTERMEDIATE_MIN = 60   # 60~299회 → 중급, 그 미만 → 고급

POS_KO = {"noun": "명사", "verb": "동사", "adj": "형용사", "adv": "부사", "prep": "전치사",
          "conj": "접속사", "pron": "대명사", "det": "한정사", "num": "수사", "intj": "감탄사"}
SKIP_POS = {"name", "abbrev", "symbol", "prefix", "suffix", "character", "phrase",
            "prep_phrase", "proverb", "contraction", "affix", "particle"}
SKIP_GLOSS_TAGS = {"form-of", "alt-of", "abbreviation", "initialism", "acronym",
                   "obsolete", "archaic", "rare", "dated", "vulgar", "offensive",
                   "derogatory", "slang", "misspelling", "nonstandard", "dialectal"}
BLANK = "_____"
MAX_DEF_LEN = 80   # 영어 정의 최대 글자 수 (휴대폰 힌트 바 2줄 정도)
# Wiktionary 에 한국어 번역이 없는 단어의 뜻 초안 (사람이 작성, 검수 전)
DRAFT_KO = ROOT / "data" / "meanings_ko_draft.csv"
# 사람이 고친 힌트 (한국어 뜻·영어 정의). 다른 모든 출처보다 우선한다.
HINT_OVERRIDES = ROOT / "data" / "hint_overrides.csv"
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


def shorten_definition(g: str, limit: int = MAX_DEF_LEN) -> str:
    """휴대폰 힌트 바에 맞게 줄인다: 첫 절(; : —)까지, 그래도 길면 40자 뒤 쉼표나 단어 경계에서 자르고 '…'."""
    g = re.split(r"\s*(?:;|:|—| - )\s*", g, maxsplit=1)[0].strip()
    if len(g) <= limit:
        return g
    cut = g[: limit - 1]
    comma = cut.rfind(", ")
    cut = cut[:comma] if comma >= 40 else cut[: cut.rfind(" ")]
    return cut.rstrip(" ,") + "…"


# 뜻이 아니라 쓰임 설명으로 시작하는 정의 (예: "Chiefly with a qualifying word", "During the Middle Ages, …")
USAGE_NOTE_RE = re.compile(r"^(Chiefly|During|Used|Especially|Usually|Formerly|Originally|Alternative|"
                           r"Obsolete|Synonym|Abbreviation|Initialism|Plural|Clipping|Short for|Preceded by)\b")


def useful_gloss(g: str, word: str) -> bool:
    """힌트로 쓸 만한 정의인지: 너무 짧거나, 정답을 그대로 담거나, '이 원소' 같은 지시만 있으면 안 됨."""
    low = g.lower()
    # 같은 어근도 정답을 알려 준다 (clearly → "in a clear manner", repayment → "the act of repaying")
    stem = word[: max(4, len(word) - 4)] if len(word) >= 5 else word
    return (len(g) >= 12 and stem not in low and "this element" not in low
            and not USAGE_NOTE_RE.match(g))


def pick_dictionary(word: str, entries: list[dict]) -> dict | None:
    """품사, 영어 정의, 한국어 뜻을 고른다. 고유명사·약어만 있는 단어는 None.

    정의는 가장 흔한 첫 뜻을 쓰되, 힌트로 쓸모없는 뜻(useful_gloss)은 건너뛰고, 길면 줄인다.
    """
    usable = [e for e in entries if e.get("pos") not in SKIP_POS]
    if not usable:
        return None
    candidates: list[tuple[str, str]] = []          # (품사, 정의)
    for e in usable:
        n = 0
        for s in e.get("senses", []):
            tags = set(s.get("tags", []))
            if tags & SKIP_GLOSS_TAGS or s.get("form_of") or s.get("alt_of"):
                continue
            gl = s.get("glosses") or []
            if gl:
                candidates.append((e["pos"], clean_gloss(gl[-1])))
                n += 1
                if n == 3:
                    break
    if not candidates:  # 변화형 항목만 있는 경우 (예: 동사 과거형) → 학습 단어로 쓰지 않음
        return None
    pos, gloss = next(((p, g) for p, g in candidates if useful_gloss(g, word)), candidates[0])
    gloss = shorten_definition(gloss)

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
def word_frequencies(targets: set[str]) -> dict[str, int]:
    """Tatoeba 영어 문장에서 단어가 나온 횟수 (대소문자 무시, 하이픈 붙은 말은 한 단어로)."""
    path = RAW / "eng_sentences.tsv.bz2"
    counts = dict.fromkeys(targets, 0)
    if not path.exists():
        print("  Tatoeba 파일 없음 → 빈도 0 (모두 고급)")
        return counts
    token_re = re.compile(r"[a-z]+(?:['-][a-z]+)*")
    with bz2.open(path, "rt", encoding="utf-8") as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3:
                continue
            for t in token_re.findall(parts[2].lower()):
                if t in counts:
                    counts[t] += 1
    return counts


def level_by_frequency(freq: int) -> str:
    if freq >= FREQ_BEGINNER_MIN:
        return "beginner"
    if freq >= FREQ_INTERMEDIATE_MIN:
        return "intermediate"
    return "advanced"


def load_draft_ko() -> dict[str, str]:
    if not DRAFT_KO.exists():
        return {}
    with open(DRAFT_KO, newline="", encoding="utf-8") as f:
        return {r["word"].strip().lower(): r["meaning_ko"].strip() for r in csv.DictReader(f)}


def load_hint_overrides() -> dict[str, dict]:
    if not HINT_OVERRIDES.exists():
        return {}
    with open(HINT_OVERRIDES, newline="", encoding="utf-8") as f:
        return {r["word"].strip().upper(): r for r in csv.DictReader(f)}


def apply_hint_overrides(rows: list[dict], overrides: dict[str, dict]) -> int:
    """data/hint_overrides.csv 의 뜻·정의로 바꾼다. 빈 칸은 그대로 둔다. 바꾼 행 수를 돌려준다."""
    changed = 0
    for r in rows:
        o = overrides.get(r["word"].upper())
        if not o:
            continue
        if o.get("meaning_ko", "").strip():
            r["meaning_ko"] = o["meaning_ko"].strip()
        if o.get("definition_en", "").strip():
            r["definition_en"] = mask_word(o["definition_en"].strip(), r["word"].lower())
        changed += 1
    return changed


def load_existing_reviewed() -> dict[str, dict]:
    if not OUT.exists():
        return {}
    with open(OUT, newline="", encoding="utf-8") as f:
        return {r["word"]: r for r in csv.DictReader(f) if r.get("reviewed") == "true"}


def main() -> None:
    if not WORD_LIST.exists():
        raise SystemExit("data/word_list.csv 가 없습니다. 먼저 python3 tools/build_word_list.py 를 실행하세요.")
    tsl_def = read_tsl_definitions()
    draft_ko = load_draft_ko()

    # 1~2. 1주차 결과(word_list.csv: 합치기·중복 제거·모양 거르기 완료)를 읽고
    # 3. 빈도 순위로 난이도를 나눈다.
    rows: dict[str, dict] = {}
    with open(WORD_LIST, newline="", encoding="utf-8") as f:
        for r in csv.DictReader(f):
            w, rank = r["word"].lower(), int(r["rank"])
            rows[w] = {"word": w, "type": r["type"], "rank": rank, "source": r["source"]}
    freq = word_frequencies(set(rows))
    for w, r in rows.items():
        r["level"] = level_by_frequency(freq[w])
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
        r["meaning_ko"] = d["meaning_ko"] or draft_ko.get(w, "")
        definition = tsl_def.get(w) or d["definition_en"]
        r["definition_en"] = mask_word(shorten_definition(definition), w)
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
    print(f"사람이 고친 힌트 적용: {apply_hint_overrides(out_rows, load_hint_overrides())}개")

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
