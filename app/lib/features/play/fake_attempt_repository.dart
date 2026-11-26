import 'dart:math';

import 'attempt.dart';
import 'attempt_repository.dart';
import 'puzzle_repository.dart';
import 'sample_puzzles.dart';

/// 로컬 모드 정답 비교. 앱에 정답 철자를 넣지 않으려고 샘플 퍼즐은 해시만 가지고 있다.
bool sampleIsCorrect(String puzzleId, int clueId, String guess) =>
    sampleAnswerHashes[puzzleId]?[clueId] == sampleAnswerHash(puzzleId, clueId, guess);

int sampleAnswerHash(String puzzleId, int clueId, String word) =>
    '$puzzleId/$clueId/$word'.codeUnits.fold(7, (h, c) => (h * 31 + c) % 1000000007);

class _Attempt {
  _Attempt(this.id, this.puzzleId, this.lengths) : words = {for (final id in lengths.keys) id: WordProgress(clueId: id)};

  final int id;
  final String puzzleId;

  /// 단서 id → 글자 수
  final Map<int, int> lengths;
  final Map<int, WordProgress> words;
  final startedAt = DateTime.now();
  final lastGuess = <int, String>{};
  final lastRequest = <int, (String, CheckResult)>{};
  AttemptResult? result;
}

/// Supabase 접속 정보가 없을 때(로컬 모드)와 테스트에서 쓰는 풀이 저장소.
/// 서버 함수와 같은 규칙(5번 제한, 같은 오답, 요청 번호, 점수, 이어 풀기)을 메모리 안에서 따른다.
class FakeAttemptRepository implements AttemptRepository {
  FakeAttemptRepository(this._puzzles, {this.isCorrect = sampleIsCorrect, this.answerOf});

  final PuzzleRepository _puzzles;
  final bool Function(String puzzleId, int clueId, String guess) isCorrect;

  /// 결과 화면에 보여 줄 못 푼 단어의 철자 (테스트용). 로컬 모드는 앱에 정답이 없어 비워 둔다.
  final String? Function(String puzzleId, int clueId)? answerOf;
  final _attempts = <int, _Attempt>{};

  @override
  Future<AttemptStart> start(String puzzleId) async {
    for (final a in _attempts.values) {
      if (a.puzzleId == puzzleId && a.result == null) {
        return AttemptStart(attemptId: a.id, resumed: true, words: a.words.values.toList());
      }
    }
    final puzzle = await _puzzles.fetchPuzzle(puzzleId);
    final a = _Attempt(_attempts.length + 1, puzzleId, {for (final c in puzzle.clues) c.id: c.length});
    _attempts[a.id] = a;
    return AttemptStart(attemptId: a.id, resumed: false, words: a.words.values.toList());
  }

  static CheckResult _result(WordProgress w, {required bool correct, required bool counted}) => CheckResult(
        correct: correct,
        solved: w.solved,
        revealed: w.revealed,
        tries: w.tries,
        triesLeft: w.triesLeft,
        score: w.score,
        answer: w.answer,
        counted: counted,
      );

  @override
  Future<CheckResult> check({
    required int attemptId,
    required int clueId,
    required String guess,
    required String requestId,
  }) async {
    final a = _attempts[attemptId];
    if (a == null || a.result != null) throw AttemptFailure(AttemptError.attemptEnded);
    final w = a.words[clueId];
    if (w == null) throw AttemptFailure(AttemptError.unknown);

    final last = a.lastRequest[clueId];
    if (last != null && last.$1 == requestId) return last.$2;
    if (w.done) return _result(w, correct: w.solved, counted: false);

    final g = guess.toUpperCase();
    if (!RegExp(r'^[A-Z]+$').hasMatch(g) || g.length != a.lengths[clueId]) {
      throw AttemptFailure(AttemptError.invalidGuess);
    }
    final correct = isCorrect(a.puzzleId, clueId, g);
    if (!correct && a.lastGuess[clueId] == g) return _result(w, correct: false, counted: false);
    if (w.triesLeft <= 0) throw AttemptFailure(AttemptError.noTriesLeft);

    final tries = w.tries + 1;
    final next = WordProgress(
      clueId: clueId,
      solved: correct,
      tries: tries,
      triesLeft: WordProgress.maxTries - tries,
      letterHints: w.letterHints,
      score: correct ? max(20, 100 - 10 * (tries - 1) - 20 * w.letterHints) : 0,
      answer: correct ? g : null,
    );
    final r = _result(next, correct: correct, counted: true);
    a.words[clueId] = next;
    a.lastGuess[clueId] = g;
    a.lastRequest[clueId] = (requestId, r);
    return r;
  }

  @override
  Future<AttemptResult> finish(int attemptId) async {
    final a = _attempts[attemptId];
    if (a == null) throw AttemptFailure(AttemptError.attemptEnded);
    if (a.result case final r?) return r;
    final puzzle = await _puzzles.fetchPuzzle(a.puzzleId);
    return a.result ??= AttemptResult(
      score: a.words.values.fold(0, (sum, w) => sum + w.score),
      maxScore: a.words.length * 100,
      correct: a.words.values.where((w) => w.solved).length,
      total: a.words.length,
      durationSec: DateTime.now().difference(a.startedAt).inSeconds,
      words: [
        for (final c in puzzle.clues)
          if (a.words[c.id] case final w?)
            WordResult(
              clueId: c.id,
              no: c.no,
              dir: c.dir.name,
              word: w.answer ?? answerOf?.call(a.puzzleId, c.id),
              length: c.length,
              meaningKo: c.meaningKo,
              solved: w.solved,
              revealed: w.revealed,
              tries: w.tries,
              letterHints: w.letterHints,
              score: w.score,
            ),
      ],
    );
  }
}
