/// 풀이 기록(attempt) 데이터. `supabase/README.md`의 start_attempt · check_word · finish_attempt 응답과 같은 모양이다.
library;

import 'dart:math';

int _int(Object? v, [int fallback = 0]) => (v as num?)?.toInt() ?? fallback;

/// 단어 하나의 풀이 상태. 정답 철자([answer])는 맞혔거나 공개한 단어에만 들어 있다.
class WordProgress {
  const WordProgress({
    required this.clueId,
    this.solved = false,
    this.revealed = false,
    this.tries = 0,
    this.triesLeft = maxTries,
    this.letterHints = 0,
    this.score = 0,
    this.answer,
  });

  factory WordProgress.fromJson(Map<String, dynamic> j) => WordProgress(
        clueId: (j['clue_id'] as num).toInt(),
        solved: j['solved'] == true,
        revealed: j['revealed'] == true,
        tries: _int(j['tries']),
        triesLeft: _int(j['tries_left'], maxTries),
        letterHints: _int(j['letter_hints']),
        score: _int(j['score']),
        answer: j['answer'] as String?,
      );

  /// 단어당 확인 횟수 (기획서 4장).
  static const maxTries = 5;

  final int clueId;
  final bool solved;
  final bool revealed;
  final int tries;
  final int triesLeft;
  final int letterHints;
  final int score;
  final String? answer;

  /// 더 풀 것이 없는 단어 (맞혔거나 정답을 공개함).
  bool get done => solved || revealed;

  WordProgress afterCheck(CheckResult r) => WordProgress(
        clueId: clueId,
        solved: r.solved,
        revealed: r.revealed,
        tries: r.tries,
        triesLeft: r.triesLeft,
        letterHints: letterHints,
        score: r.score,
        answer: r.answer ?? answer,
      );

  /// 서버가 no_tries_left 라고 했을 때.
  WordProgress withoutTries() => WordProgress(
        clueId: clueId,
        solved: solved,
        revealed: revealed,
        tries: maxTries,
        triesLeft: 0,
        letterHints: letterHints,
        score: score,
        answer: answer,
      );
}

/// start_attempt 결과. [resumed]면 진행 중이던 기록을 이어 푼다.
class AttemptStart {
  const AttemptStart({required this.attemptId, required this.resumed, required this.words});

  factory AttemptStart.fromJson(Map<String, dynamic> j) => AttemptStart(
        attemptId: (j['attempt_id'] as num).toInt(),
        resumed: j['resumed'] == true,
        words: [
          for (final w in (j['words'] as List? ?? const []).cast<Map>()) WordProgress.fromJson(w.cast<String, dynamic>()),
        ],
      );

  final int attemptId;
  final bool resumed;
  final List<WordProgress> words;
}

/// check_word 결과. [counted]가 false면 시도 횟수에 들어가지 않았다 (방금과 같은 오답, 이미 맞힌 단어).
class CheckResult {
  const CheckResult({
    required this.correct,
    required this.solved,
    required this.revealed,
    required this.tries,
    required this.triesLeft,
    required this.score,
    required this.counted,
    this.answer,
  });

  factory CheckResult.fromJson(Map<String, dynamic> j) => CheckResult(
        correct: j['correct'] as bool,
        solved: j['solved'] == true,
        revealed: j['revealed'] == true,
        tries: (j['tries'] as num).toInt(),
        triesLeft: (j['tries_left'] as num).toInt(),
        score: _int(j['score']),
        counted: j['counted'] != false,
        answer: j['answer'] as String?,
      );

  final bool correct;
  final bool solved;
  final bool revealed;
  final int tries;
  final int triesLeft;
  final int score;
  final bool counted;
  final String? answer;
}

/// finish_attempt 의 단어 하나. 결과 화면용이라 못 푼 단어도 정답 철자([word])가 들어 있다.
/// (로컬 모드는 앱에 정답이 없어 맞힌 단어만 철자가 있다.)
class WordResult {
  const WordResult({
    required this.clueId,
    required this.no,
    required this.dir,
    this.word,
    this.length = 0,
    this.meaningKo,
    this.solved = false,
    this.revealed = false,
    this.tries = 0,
    this.letterHints = 0,
    this.score = 0,
  });

  factory WordResult.fromJson(Map<String, dynamic> j) {
    final word = j['word'] as String?;
    final meaning = (j['meaning_ko'] as String?)?.trim();
    return WordResult(
      clueId: (j['clue_id'] as num).toInt(),
      no: _int(j['no']),
      dir: j['dir'] as String? ?? 'across',
      word: word,
      length: word?.length ?? _int(j['length']),
      meaningKo: meaning == null || meaning.isEmpty ? null : meaning,
      solved: j['solved'] == true,
      revealed: j['revealed'] == true,
      tries: _int(j['tries']),
      letterHints: _int(j['letter_hints']),
      score: _int(j['score']),
    );
  }

  final int clueId;
  final int no;

  /// across / down
  final String dir;
  final String? word;
  final int length;
  final String? meaningKo;
  final bool solved;
  final bool revealed;

  /// 확인을 누른 횟수 (맞힌 확인 포함).
  final int tries;
  final int letterHints;
  final int score;

  /// 틀린 확인 횟수. 맞힌 단어는 마지막 확인 한 번이 정답이다.
  int get wrongTries => solved ? max(0, tries - 1) : tries;

  /// 오답 노트에 들어가는 단어: 한 번이라도 틀렸거나, 정답을 공개했거나, 끝내지 못한 단어 (기획서 4장).
  bool get toWrongNote => revealed || !solved || wrongTries > 0;

  /// 화면에 보일 철자. 모르면 글자 수만큼 물음표.
  String get display => word ?? '?' * length;
}

/// finish_attempt 결과.
class AttemptResult {
  const AttemptResult({
    required this.score,
    required this.maxScore,
    required this.correct,
    required this.total,
    required this.durationSec,
    this.words = const [],
  });

  factory AttemptResult.fromJson(Map<String, dynamic> j) => AttemptResult(
        score: (j['score'] as num).toInt(),
        maxScore: _int(j['max_score']),
        correct: _int(j['correct']),
        total: _int(j['total']),
        durationSec: _int(j['duration_sec']),
        words: [
          for (final w in (j['words'] as List? ?? const []).cast<Map>()) WordResult.fromJson(w.cast<String, dynamic>()),
        ],
      );

  final int score;
  final int maxScore;
  final int correct;
  final int total;
  final int durationSec;
  final List<WordResult> words;

  /// 정답률(%) = 공개 없이 맞힌 단어 ÷ 전체 단어.
  int get accuracyPercent => total == 0 ? 0 : (correct * 100 / total).round();

  /// 예: 6분 52초
  String get durationLabel {
    final h = durationSec ~/ 3600, m = durationSec % 3600 ~/ 60, s = durationSec % 60;
    return [if (h > 0) '$h시간', if (m > 0) '$m분', if (h == 0) '$s초'].join(' ');
  }

  /// 시계 모양. 예: 11:42, 1:05:09
  String get durationClock {
    final h = durationSec ~/ 3600, m = durationSec % 3600 ~/ 60, s = durationSec % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
  }

  /// 쓴 글자 힌트 수.
  int get letterHints => words.fold(0, (sum, w) => sum + w.letterHints);

  /// 오답 노트에 들어간 단어. 정답 공개 → 못 끝냄 → 많이 틀린 순.
  List<WordResult> get wrongWords {
    int rank(WordResult w) => w.revealed ? 0 : (!w.solved ? 1 : 2);
    return [...words.where((w) => w.toWrongNote)]..sort((a, b) {
        final r = rank(a) - rank(b);
        if (r != 0) return r;
        final t = b.wrongTries - a.wrongTries;
        return t != 0 ? t : a.clueId - b.clueId;
      });
  }

  /// 맞힌 단어 (공개하지 않고). 단서 순서 그대로.
  List<WordResult> get solvedWords => [...words.where((w) => w.solved && !w.revealed)];
}

/// 확인 요청마다 붙이는 고유 번호(UUID v4). 같은 번호로 다시 보내면 서버가 한 번만 처리한다.
String newRequestId([Random? random]) {
  final rnd = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = [for (final x in b) x.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
