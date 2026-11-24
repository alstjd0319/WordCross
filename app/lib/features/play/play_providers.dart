import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import 'attempt.dart';
import 'attempt_repository.dart';
import 'play_session.dart';
import 'play_state.dart';
import 'puzzle.dart';
import 'puzzle_repository.dart';

/// main(또는 테스트)에서 실제 구현으로 덮어쓴다.
final puzzleRepositoryProvider = Provider<PuzzleRepository>(
  (ref) => throw UnimplementedError('puzzleRepositoryProvider를 main에서 override 해야 합니다.'),
);

/// main(또는 테스트)에서 실제 구현으로 덮어쓴다.
final attemptRepositoryProvider = Provider<AttemptRepository>(
  (ref) => throw UnimplementedError('attemptRepositoryProvider를 main에서 override 해야 합니다.'),
);

/// Riverpod 3은 실패한 provider를 저절로 다시 시도한다. 저장소가 이미 화면용 [PuzzleFailure]로
/// 바꿔 준 오류(없는 퍼즐, 연결 실패 등)는 다시 시도하지 않고 바로 보여 준다. 화면에 "다시 시도" 버튼이 있다.
Duration? _retryUnlessPuzzleFailure(int retryCount, Object error) {
  if (error is PuzzleFailure || retryCount >= 3) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}

/// 공개된 퍼즐 목록. 퍼즐 탭에 머무는 동안 유지하고, 당겨서 새로고침하면 다시 받는다.
/// 로그인한 사용자가 바뀌면 다시 받아서, 로그인이 풀렸을 때의 오류가 다시 로그인한 뒤까지 남지 않는다.
final puzzleListProvider = FutureProvider<List<PuzzleSummary>>(
  (ref) async {
    final repository = ref.watch(puzzleRepositoryProvider);
    final userId = await ref.watch(currentUserProvider.selectAsync((u) => u?.id));
    return userId == null ? const [] : repository.listPuzzles();
  },
  retry: _retryUnlessPuzzleFailure,
);

/// 퍼즐 id → 퍼즐 틀과 힌트. 화면을 떠나면 버린다.
final puzzleProvider = FutureProvider.autoDispose.family<PuzzleData, String>(
  (ref, puzzleId) => ref.watch(puzzleRepositoryProvider).fetchPuzzle(puzzleId),
  retry: _retryUnlessPuzzleFailure,
);

/// 퍼즐 id → 서버 풀이 기록. 풀이 화면을 열 때 시작하고(진행 중이면 이어 풀고), 화면을 떠나면 버린다.
final attemptProvider = FutureProvider.autoDispose.family<AttemptStart, String>(
  (ref, puzzleId) => ref.watch(attemptRepositoryProvider).start(puzzleId),
  retry: _retryUnlessPuzzleFailure,
);

/// 퍼즐 id → 풀이 상태. [puzzleProvider]와 [attemptProvider]가 데이터를 받은 뒤에만 읽는다.
final playProvider = NotifierProvider.autoDispose.family<PlayController, PlaySession, String>(PlayController.new);

typedef _PendingCheck = ({Clue clue, String guess, String requestId});

class PlayController extends Notifier<PlaySession> {
  PlayController(this.puzzleId);

  final String puzzleId;

  /// 응답을 받지 못한 확인 요청. 같은 단어·같은 답을 다시 보낼 때 같은 요청 번호를 쓴다.
  _PendingCheck? _pending;

  /// 안내의 "다시 시도"를 누르면 할 일.
  Future<void> Function()? _retry;

  @override
  PlaySession build() {
    final puzzle = ref.watch(puzzleProvider(puzzleId)).requireValue;
    final attempt = ref.watch(attemptProvider(puzzleId)).requireValue;
    _pending = null;
    _retry = null;
    final board = PlayState.start(puzzle).applyProgress(attempt.words);
    return PlaySession(
      board: board,
      attemptId: attempt.attemptId,
      notice: attempt.resumed
          ? PlayNotice(board.doneWordCount == 0 ? '풀던 기록을 이어서 풀어요.' : '이어서 풀어요. 맞힌 단어 ${board.doneWordCount}개를 불러왔어요.')
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // 격자 입력
  // ---------------------------------------------------------------------------

  /// 격자가 실제로 바뀌면 안내를 지운다.
  void _board(PlayState next) {
    if (identical(next, state.board)) return;
    state = state.copyWith(board: next, notice: () => null);
  }

  void tapCell(int row, int col) => _board(state.board.tapCell(row, col));
  void typeLetter(String letter) => _board(state.board.typeLetter(letter));
  void backspace() => _board(state.board.backspace());
  void toggleDirection() => _board(state.board.toggleDirection());
  void nextClue() => _board(state.board.nextClue());
  void previousClue() => _board(state.board.previousClue());
  void moveCursor(int dRow, int dCol) => _board(state.board.moveCursor(dRow, dCol));

  /// 힌트를 바꿔 보는 동안에도 안내는 남긴다.
  void cycleHint() => state = state.copyWith(board: state.board.cycleHint());

  // ---------------------------------------------------------------------------
  // 확인·제출
  // ---------------------------------------------------------------------------

  /// 확인: 지금 단어 하나를 서버에서 채점한다.
  Future<void> checkWord() async {
    if (!state.canCheck) return;
    final clue = state.board.currentClue!;
    final guess = state.board.guessFor(clue)!;
    final p = _pending;
    await _sendCheck(
      p != null && p.clue == clue && p.guess == guess ? p : (clue: clue, guess: guess, requestId: newRequestId()),
    );
  }

  Future<void> _sendCheck(_PendingCheck request) async {
    if (state.busy) return;
    _pending = request;
    final attemptId = state.attemptId;
    state = state.copyWith(checking: true, notice: () => null);
    try {
      final r = await ref.read(attemptRepositoryProvider).check(
            attemptId: attemptId,
            clueId: request.clue.id,
            guess: request.guess,
            requestId: request.requestId,
          );
      if (!ref.mounted || state.attemptId != attemptId) return;
      _pending = null;
      final wasDone = state.board.progressOf(request.clue).done;
      final board = state.board.applyCheck(request.clue, r);
      state = state.copyWith(board: board, checking: false, notice: () => _checkNotice(r, board, wasDone: wasDone));
    } on AttemptFailure catch (e) {
      if (!ref.mounted || state.attemptId != attemptId) return;
      // 서버가 받아서 거절한 요청은 다시 보낼 필요가 없다. 닿았는지 모르는 요청만 번호를 남긴다.
      if (e.error != AttemptError.network) _pending = null;
      state = state.copyWith(
        checking: false,
        board: e.error == AttemptError.noTriesLeft ? state.board.applyNoTriesLeft(request.clue) : null,
      );
      _fail(e, retry: () => _sendCheck(request));
    }
  }

  PlayNotice _checkNotice(CheckResult r, PlayState board, {required bool wasDone}) {
    if (r.correct) {
      if (board.remainingWordCount == 0) return const PlayNotice('모든 단어를 맞혔어요! 제출해 주세요.', tone: NoticeTone.success);
      // 다른 기기에서 먼저 맞힌 단어 등 이번에 세지 않은 정답
      if (!r.counted && !wasDone) return const PlayNotice('이미 풀었어요.', tone: NoticeTone.success);
      return PlayNotice('정답이에요! +${r.score}점', tone: NoticeTone.success);
    }
    if (r.revealed) return const PlayNotice('정답을 공개한 단어예요.');
    if (r.triesLeft <= 0) return PlayNotice(AttemptError.noTriesLeft.message, tone: NoticeTone.error);
    if (!r.counted) return const PlayNotice('방금과 같은 답이에요. 횟수는 줄지 않았어요.', tone: NoticeTone.error);
    return PlayNotice('아직 아니에요. 확인이 ${r.triesLeft}번 남았어요.', tone: NoticeTone.error);
  }

  /// 제출: 퍼즐을 끝낸다. 못 푼 단어가 있으면 화면이 먼저 확인 창을 띄운다.
  Future<void> submit() async {
    if (!state.canSubmit) return;
    final attemptId = state.attemptId;
    state = state.copyWith(submitting: true, notice: () => null);
    try {
      final result = await ref.read(attemptRepositoryProvider).finish(attemptId);
      if (!ref.mounted || state.attemptId != attemptId) return;
      state = state.copyWith(submitting: false, result: result);
    } on AttemptFailure catch (e) {
      if (!ref.mounted || state.attemptId != attemptId) return;
      state = state.copyWith(submitting: false);
      _fail(e, retry: submit);
    }
  }

  void _fail(AttemptFailure e, {required Future<void> Function() retry}) {
    switch (e.error) {
      case AttemptError.attemptEnded || AttemptError.puzzleNotFound:
        state = state.copyWith(end: SessionEnd.attemptEnded);
      case AttemptError.notAuthenticated:
        state = state.copyWith(end: SessionEnd.authExpired);
      case AttemptError.network || AttemptError.unknown:
        _retry = retry;
        state = state.copyWith(notice: () => PlayNotice(e.message, tone: NoticeTone.error, canRetry: true));
      case AttemptError.invalidGuess || AttemptError.noTriesLeft:
        state = state.copyWith(notice: () => PlayNotice(e.message, tone: NoticeTone.error));
    }
  }

  Future<void> retry() async => _retry?.call();
}
