"""격자·슬롯·채우기(CSP) 공용 코드. make_templates.py, generate_puzzles.py 가 쓴다.

격자 표현: 문자열 리스트. '#' = 검은 칸, '.' = 빈 흰 칸, 'A'~'Z' = 채운 칸.
"""
from __future__ import annotations

import random
import time
from dataclasses import dataclass, field

BLOCK = "#"
EMPTY = "."

# 난이도별 규칙 (퍼즐 제작 설계서 2장)
LEVELS = {
    "beginner":     {"prefix": "beg", "sizes": [9, 11], "min_len": 3, "max_len": 7,  "words": (15, 25)},
    "intermediate": {"prefix": "mid", "sizes": [13],    "min_len": 4, "max_len": 9,  "words": (26, 40)},
    "advanced":     {"prefix": "adv", "sizes": [15],    "min_len": 5, "max_len": 11, "words": (30, 60)},
}
LEVEL_ORDER = ["beginner", "intermediate", "advanced"]


@dataclass
class Slot:
    row: int
    col: int
    dir: str            # "across" | "down"
    length: int
    no: int = 0
    cells: list[tuple[int, int]] = field(default_factory=list)


def runs(grid: list[str]) -> list[Slot]:
    """길이 2 이상인 가로·세로 연속 흰 칸 (= 단어 자리)."""
    n_r, n_c = len(grid), len(grid[0])
    out: list[Slot] = []
    for r in range(n_r):
        c = 0
        while c < n_c:
            if grid[r][c] != BLOCK:
                s = c
                while c < n_c and grid[r][c] != BLOCK:
                    c += 1
                if c - s >= 2:
                    out.append(Slot(r, s, "across", c - s, cells=[(r, x) for x in range(s, c)]))
            else:
                c += 1
    for c in range(n_c):
        r = 0
        while r < n_r:
            if grid[r][c] != BLOCK:
                s = r
                while r < n_r and grid[r][c] != BLOCK:
                    r += 1
                if r - s >= 2:
                    out.append(Slot(s, c, "down", r - s, cells=[(y, c) for y in range(s, r)]))
            else:
                r += 1
    return out


def number_slots(grid: list[str], slots: list[Slot]) -> list[Slot]:
    """신문 크로스워드 번호: 위→아래, 왼→오른쪽으로 단어가 시작하는 칸에 번호."""
    starts = sorted({(s.row, s.col) for s in slots})
    num = {pos: i + 1 for i, pos in enumerate(starts)}
    for s in slots:
        s.no = num[(s.row, s.col)]
    slots.sort(key=lambda s: (s.dir != "across", s.no))
    return slots


def template_problems(grid: list[str], min_len: int, max_len: int) -> list[str]:
    """격자 틀 규칙 위반 목록 (빈 리스트면 통과)."""
    n_r, n_c = len(grid), len(grid[0])
    problems = []
    # 180도 회전 대칭
    for r in range(n_r):
        for c in range(n_c):
            if (grid[r][c] == BLOCK) != (grid[n_r - 1 - r][n_c - 1 - c] == BLOCK):
                problems.append(f"대칭 아님 ({r},{c})")
                return problems
    sl = runs(grid)
    for s in sl:
        if not min_len <= s.length <= max_len:
            problems.append(f"단어 길이 {s.length} ({s.dir} {s.row},{s.col})")
    covered = {cell for s in sl for cell in s.cells}
    whites = [(r, c) for r in range(n_r) for c in range(n_c) if grid[r][c] != BLOCK]
    for cell in whites:
        if cell not in covered:
            problems.append(f"단어에 속하지 않는 칸 {cell}")
    # 흰 칸 연결
    if whites:
        seen, stack = {whites[0]}, [whites[0]]
        white_set = set(whites)
        while stack:
            r, c = stack.pop()
            for nb in ((r + 1, c), (r - 1, c), (r, c + 1), (r, c - 1)):
                if nb in white_set and nb not in seen:
                    seen.add(nb)
                    stack.append(nb)
        if len(seen) != len(whites):
            problems.append("흰 칸이 끊어져 있음")
    return problems


# ---------------------------------------------------------------------------
# 단어 색인: 길이별 단어 목록 + (위치, 글자) → 비트셋
# ---------------------------------------------------------------------------
class WordIndex:
    def __init__(self, words: list[str], scores: dict[str, float]):
        self.by_len: dict[int, list[str]] = {}
        for w in sorted(set(words)):
            self.by_len.setdefault(len(w), []).append(w)
        self.scores = scores
        self.bits: dict[int, dict[tuple[int, str], int]] = {}
        self.all_bits: dict[int, int] = {}
        for L, ws in self.by_len.items():
            idx: dict[tuple[int, str], int] = {}
            for i, w in enumerate(ws):
                for p, ch in enumerate(w):
                    idx[(p, ch)] = idx.get((p, ch), 0) | (1 << i)
            self.bits[L] = idx
            self.all_bits[L] = (1 << len(ws)) - 1
        self.pos_of = {L: {w: i for i, w in enumerate(ws)} for L, ws in self.by_len.items()}

    def candidates(self, pattern: str, used_bits: int = 0) -> int:
        L = len(pattern)
        if L not in self.all_bits:
            return 0
        b = self.all_bits[L] & ~used_bits
        idx = self.bits[L]
        for p, ch in enumerate(pattern):
            if ch != EMPTY:
                b &= idx.get((p, ch), 0)
                if not b:
                    return 0
        return b

    def words_of(self, L: int, bits: int) -> list[str]:
        ws = self.by_len[L]
        out = []
        while bits:
            low = bits & -bits
            out.append(ws[low.bit_length() - 1])
            bits ^= low
        return out


class Timeout(Exception):
    pass


class Filler:
    """틀의 빈칸을 단어로 채운다. MRV + 점수 순(랜덤 섞기) + 전방 검사 + 백트래킹."""

    def __init__(self, template: list[str], index: WordIndex, rng: random.Random,
                 time_limit: float = 5.0, max_tries_per_slot: int = 40):
        self.grid = [list(row) for row in template]
        self.slots = runs(template)
        self.index = index
        self.rng = rng
        self.deadline = time.monotonic() + time_limit
        self.max_tries = max_tries_per_slot
        self.assigned: dict[int, str] = {}
        self.used: dict[int, int] = {}   # 길이별 사용한 단어 비트
        cell_slots: dict[tuple[int, int], list[int]] = {}
        for i, s in enumerate(self.slots):
            for cell in s.cells:
                cell_slots.setdefault(cell, []).append(i)
        self.crossing = [sorted({j for cell in s.cells for j in cell_slots[cell] if j != i})
                         for i, s in enumerate(self.slots)]

    def pattern(self, i: int) -> str:
        return "".join(self.grid[r][c] for r, c in self.slots[i].cells)

    def cands(self, i: int) -> int:
        L = self.slots[i].length
        return self.index.candidates(self.pattern(i), self.used.get(L, 0))

    def place(self, i: int, word: str) -> list[tuple[int, int]]:
        changed = []
        for (r, c), ch in zip(self.slots[i].cells, word):
            if self.grid[r][c] == EMPTY:
                self.grid[r][c] = ch
                changed.append((r, c))
        L = len(word)
        self.used[L] = self.used.get(L, 0) | (1 << self.index.pos_of[L][word])
        self.assigned[i] = word
        return changed

    def unplace(self, i: int, changed: list[tuple[int, int]]) -> None:
        for r, c in changed:
            self.grid[r][c] = EMPTY
        word = self.assigned.pop(i)
        L = len(word)
        self.used[L] &= ~(1 << self.index.pos_of[L][word])

    def ordered(self, i: int, bits: int) -> list[str]:
        words = self.index.words_of(self.slots[i].length, bits)
        sc = self.index.scores
        # 점수 + 랜덤: 학습 단어가 앞으로 오되 매번 다른 순서
        keyed = sorted(words, key=lambda w: -(sc.get(w, 0) + self.rng.random() * 1.5))
        return keyed[: self.max_tries]

    def solve(self) -> bool:
        if time.monotonic() > self.deadline:
            raise Timeout
        empty = [i for i in range(len(self.slots)) if i not in self.assigned]
        if not empty:
            return True
        # MRV: 후보가 가장 적은 슬롯
        best_i, best_bits, best_n = -1, 0, None
        for i in empty:
            b = self.cands(i)
            n = b.bit_count()
            if n == 0:
                return False
            if best_n is None or n < best_n:
                best_i, best_bits, best_n = i, b, n
                if n == 1:
                    break
        for word in self.ordered(best_i, best_bits):
            changed = self.place(best_i, word)
            # 전방 검사: 교차하는 빈 슬롯에 후보가 남아 있어야 함
            if all(j in self.assigned or self.cands(j) for j in self.crossing[best_i]):
                if self.solve():
                    return True
            self.unplace(best_i, changed)
        return False

    def result(self) -> tuple[list[str], list[tuple[Slot, str]]]:
        """채운 격자와 (번호 매긴 슬롯, 단어) 목록."""
        grid = ["".join(row) for row in self.grid]
        pairs = [(s, self.assigned[i]) for i, s in enumerate(self.slots)]
        number_slots(grid, [s for s, _ in pairs])
        pairs.sort(key=lambda p: (p[0].dir != "across", p[0].no))
        return grid, pairs
