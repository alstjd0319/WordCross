import 'attempt.dart';
import 'puzzle.dart';

/// 퍼즐 풀이 화면의 상태: 칸마다 입력한 글자, 지금 칸, 입력 방향, 보고 있는 힌트 종류.
///
/// 바꾸지 않는(immutable) 값이라, 동작마다 새 [PlayState]를 돌려준다. 화면 없이 단위 테스트한다.
/// 채점은 서버 RPC가 하고, 여기서는 그 결과([progress])를 받아 맞힌 단어를 잠근다.
class PlayState {
  const PlayState._({
    required this.puzzle,
    required this.letters,
    required this.row,
    required this.col,
    required this.dir,
    required this.hintKind,
    required this.progress,
    required this.locked,
  });

  /// 첫 가로 단어(없으면 첫 단어)의 첫 칸에서 시작한다.
  factory PlayState.start(PuzzleData puzzle) {
    final first = puzzle.clues.isEmpty ? null : puzzle.clues.first;
    return PlayState._(
      puzzle: puzzle,
      letters: const {},
      row: first?.row ?? 0,
      col: first?.col ?? 0,
      dir: first?.dir ?? Direction.across,
      hintKind: HintKind.meaningKo,
      progress: const {},
      locked: const {},
    );
  }

  final PuzzleData puzzle;

  /// (행, 열) → 대문자 한 글자. 비어 있는 칸은 없다.
  final Map<(int, int), String> letters;
  final int row;
  final int col;
  final Direction dir;

  /// 사용자가 마지막으로 고른 힌트 종류. 지금 단어에 그 힌트가 없으면 [shownHintKind]가 다른 것을 고른다.
  final HintKind hintKind;

  /// 단서 id → 확인 횟수·점수·맞힘. 서버가 알려 준 값.
  final Map<int, WordProgress> progress;

  /// 맞혔거나 정답을 공개한 단어의 칸. 교차하는 단어에서도 글자를 바꿀 수 없다 (기획서 4장).
  final Set<(int, int)> locked;

  PlayState _copy({
    Map<(int, int), String>? letters,
    int? row,
    int? col,
    Direction? dir,
    HintKind? hintKind,
    Map<int, WordProgress>? progress,
    Set<(int, int)>? locked,
  }) =>
      PlayState._(
        puzzle: puzzle,
        letters: letters ?? this.letters,
        row: row ?? this.row,
        col: col ?? this.col,
        dir: dir ?? this.dir,
        hintKind: hintKind ?? this.hintKind,
        progress: progress ?? this.progress,
        locked: locked ?? this.locked,
      );

  // ---------------------------------------------------------------------------
  // 읽기
  // ---------------------------------------------------------------------------

  /// 지금 고른 단어.
  Clue? get currentClue => puzzle.clueAt(row, col, dir) ?? puzzle.clueAt(row, col, dir.other);

  String? letterAt(int r, int c) => letters[(r, c)];

  bool isCursor(int r, int c) => r == row && c == col;

  bool inCurrentWord(int r, int c) {
    final clue = currentClue;
    if (clue == null) return false;
    return clue.dir == Direction.across
        ? r == clue.row && c >= clue.col && c < clue.col + clue.length
        : c == clue.col && r >= clue.row && r < clue.row + clue.length;
  }

  bool isWordFilled(Clue clue) => clue.cells.every(letters.containsKey);

  bool isLocked(int r, int c) => locked.contains((r, c));

  WordProgress progressOf(Clue clue) => progress[clue.id] ?? WordProgress(clueId: clue.id);

  /// 맞혔거나 정답을 공개한 단어 수.
  int get doneWordCount => puzzle.clues.where((c) => progressOf(c).done).length;

  /// 아직 못 푼 단어 수. 다 채웠어도 확인하지 않았으면 못 푼 단어다.
  int get remainingWordCount => puzzle.clues.length - doneWordCount;

  /// 단어 칸에 넣은 글자. 빈칸이 있으면 null.
  String? guessFor(Clue clue) => isWordFilled(clue) ? clue.cells.map((c) => letters[c]!).join() : null;

  /// 화면에 보여 줄 힌트 종류. 지금 단어에 힌트가 하나도 없으면 null.
  HintKind? get shownHintKind {
    final kinds = currentClue?.hintKinds ?? const <HintKind>[];
    if (kinds.isEmpty) return null;
    return kinds.contains(hintKind) ? hintKind : kinds.first;
  }

  /// 힌트 전환 버튼을 누르면 보일 힌트 종류. 바꿀 힌트가 없으면 null.
  HintKind? get nextHintKind {
    final kinds = currentClue?.hintKinds ?? const <HintKind>[];
    final shown = shownHintKind;
    if (shown == null || kinds.length < 2) return null;
    return kinds[(kinds.indexOf(shown) + 1) % kinds.length];
  }

  // ---------------------------------------------------------------------------
  // 동작
  // ---------------------------------------------------------------------------

  /// 칸을 누름. 검은 칸은 무시하고, 지금 칸을 다시 누르면 가로·세로를 바꾼다.
  PlayState tapCell(int r, int c) {
    if (puzzle.isBlock(r, c) || r < 0 || c < 0 || r >= puzzle.rows || c >= puzzle.cols) return this;
    if (isCursor(r, c)) return toggleDirection();
    final keep = puzzle.clueAt(r, c, dir) != null;
    return _copy(row: r, col: c, dir: keep ? dir : dir.other);
  }

  /// 지금 칸이 양쪽 단어에 모두 속할 때만 방향을 바꾼다.
  PlayState toggleDirection() => puzzle.clueAt(row, col, dir.other) == null ? this : _copy(dir: dir.other);

  /// 서버가 알려 준 단어 상태를 반영한다. 맞힌 단어는 정답 글자를 채우고 칸을 잠근다.
  PlayState applyProgress(Iterable<WordProgress> words) {
    final nextProgress = {...progress, for (final w in words) w.clueId: w};
    final nextLetters = {...letters};
    final nextLocked = {...locked};
    for (final clue in puzzle.clues) {
      final w = nextProgress[clue.id];
      final answer = w?.answer?.toUpperCase();
      if (w == null || !w.done || answer == null || answer.length != clue.length) continue;
      final cells = clue.cells;
      for (var i = 0; i < cells.length; i++) {
        nextLetters[cells[i]] = answer[i];
        nextLocked.add(cells[i]);
      }
    }
    return _copy(letters: nextLetters, progress: nextProgress, locked: nextLocked);
  }

  PlayState applyCheck(Clue clue, CheckResult result) => applyProgress([progressOf(clue).afterCheck(result)]);

  PlayState applyNoTriesLeft(Clue clue) => applyProgress([progressOf(clue).withoutTries()]);

  /// 지금 칸에 글자를 넣고 같은 단어의 다음 칸으로 간다. 단어 끝이면 그 자리에 있는다.
  /// 잠긴 칸에서는 그 칸의 글자를 치면 지나가기만 하고, 다른 글자를 치면 다음 빈 자리(안 잠긴 칸)에 넣는다.
  /// 그래서 단어를 처음부터 다 쳐도, 잠긴 글자를 빼고 쳐도 된다.
  PlayState typeLetter(String letter) {
    final ch = letter.toUpperCase();
    if (ch.length != 1 || ch.codeUnitAt(0) < 0x41 || ch.codeUnitAt(0) > 0x5A) return this;
    final clue = currentClue;
    if (clue == null) return this;
    final cells = clue.cells;
    final i = cells.indexOf((row, col));
    var target = i;
    if (locked.contains(cells[i])) {
      if (letters[cells[i]] == ch) {
        if (i + 1 >= cells.length) return this;
        final (nr, nc) = cells[i + 1];
        return _copy(row: nr, col: nc, dir: clue.dir);
      }
      target = cells.indexWhere((c) => !locked.contains(c), i);
      if (target < 0) return this;
    }
    final (nr, nc) = cells[target + 1 < cells.length ? target + 1 : target];
    return _copy(letters: {...letters, cells[target]: ch}, row: nr, col: nc, dir: clue.dir);
  }

  /// 지금 칸에 글자가 있으면 지우고, 비어 있으면 앞 칸으로 가서 지운다. 잠긴 칸은 건너뛴다.
  PlayState backspace() {
    if (letters.containsKey((row, col)) && !isLocked(row, col)) return _copy(letters: {...letters}..remove((row, col)));
    final clue = currentClue;
    if (clue == null) return this;
    final cells = clue.cells;
    final i = cells.indexOf((row, col));
    final prev = i <= 0 ? -1 : cells.lastIndexWhere((c) => !locked.contains(c), i - 1);
    if (prev < 0) return this;
    final (pr, pc) = cells[prev];
    return _copy(letters: {...letters}..remove((pr, pc)), row: pr, col: pc, dir: clue.dir);
  }

  /// 다음(또는 이전) 단어로. 가로 단어 다음에는 세로 단어가 이어지고, 끝에서는 처음으로 돌아간다.
  PlayState nextClue({bool backward = false}) {
    final clues = puzzle.clues;
    final clue = currentClue;
    if (clues.isEmpty) return this;
    final i = clue == null ? -1 : clues.indexOf(clue);
    final step = backward ? -1 : 1;
    final target = clues[(i + step + clues.length) % clues.length];
    return _jumpTo(target);
  }

  PlayState previousClue() => nextClue(backward: true);

  /// 단어로 이동: 첫 빈칸, 다 찼으면 잠기지 않은 첫 칸, 다 잠겼으면 첫 칸.
  PlayState _jumpTo(Clue clue) {
    final (r, c) = clue.cells.firstWhere(
      (cell) => !letters.containsKey(cell),
      orElse: () => clue.cells.firstWhere((cell) => !locked.contains(cell), orElse: () => clue.cells.first),
    );
    return _copy(row: r, col: c, dir: clue.dir);
  }

  /// 화살표 키. 다른 축의 화살표를 누르면 먼저 그 방향으로 바꾸고, 같은 축이면 검은 칸을 건너뛰어 한 칸 간다.
  PlayState moveCursor(int dRow, int dCol) {
    final axis = dRow == 0 ? Direction.across : Direction.down;
    if (axis != dir && puzzle.clueAt(row, col, axis) != null) return _copy(dir: axis);
    var r = row + dRow;
    var c = col + dCol;
    while (r >= 0 && c >= 0 && r < puzzle.rows && c < puzzle.cols) {
      if (!puzzle.isBlock(r, c)) {
        final keep = puzzle.clueAt(r, c, dir) != null;
        return _copy(row: r, col: c, dir: keep ? dir : dir.other);
      }
      r += dRow;
      c += dCol;
    }
    return this;
  }

  /// 힌트 전환 버튼: 한국어 뜻 → 영어 정의 → 예문 빈칸 → … (지금 단어에 있는 것만)
  PlayState cycleHint() {
    final next = nextHintKind;
    return next == null ? this : _copy(hintKind: next);
  }
}
