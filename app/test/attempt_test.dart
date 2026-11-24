import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:wordcross/features/play/attempt.dart';
import 'package:wordcross/features/play/attempt_repository.dart';
import 'package:wordcross/features/play/fake_attempt_repository.dart';
import 'package:wordcross/features/play/fake_puzzle_repository.dart';
import 'package:wordcross/features/play/puzzle.dart';
import 'package:wordcross/features/play/sample_puzzles.dart';
import 'package:wordcross/features/play/supabase_attempt_repository.dart';

import 'fixtures/test_puzzles.dart';

Map<String, dynamic> json(String s) => jsonDecode(s) as Map<String, dynamic>;

Matcher failsWith(AttemptError error) => throwsA(isA<AttemptFailure>().having((e) => e.error, 'error', error));

void main() {
  group('supabase/README.md 응답 예시를 읽는다', () {
    test('start_attempt', () {
      final a = AttemptStart.fromJson(json('''
        {"attempt_id": 12, "puzzle_id": "beg-001", "started_at": "2026-11-23T06:00:54Z", "resumed": false,
         "words": [{"clue_id": 33, "no": 1, "dir": "across", "solved": false, "revealed": false,
                    "tries": 0, "tries_left": 5, "letter_hints": 0, "score": 0, "answer": null}]}'''));
      expect(a.attemptId, 12);
      expect(a.resumed, isFalse);
      expect(a.words.single.clueId, 33);
      expect(a.words.single.triesLeft, 5);
      expect(a.words.single.answer, isNull);
    });

    test('check_word: 맞힘, 그리고 answer가 없는 오답', () {
      final ok = CheckResult.fromJson(json('''
        {"correct": true, "solved": true, "revealed": false, "tries": 3, "tries_left": 2,
         "score": 80, "answer": "NOTE", "counted": true}'''));
      expect((ok.correct, ok.triesLeft, ok.score, ok.answer, ok.counted), (true, 2, 80, 'NOTE', true));

      final wrong = CheckResult.fromJson(json('''
        {"correct": false, "solved": false, "revealed": false, "tries": 1, "tries_left": 4, "score": 0, "counted": false}'''));
      expect((wrong.correct, wrong.answer, wrong.counted), (false, null, false));
    });

    test('finish_attempt', () {
      final r = AttemptResult.fromJson(json('''
        {"attempt_id": 12, "puzzle_id": "beg-001", "score": 1580, "max_score": 1900,
         "correct": 17, "total": 19, "accuracy": 0.895, "duration_sec": 412,
         "words": [{"clue_id": 33, "word": "NOTE", "solved": true, "score": 100}]}'''));
      expect((r.score, r.maxScore, r.correct, r.total), (1580, 1900, 17, 19));
      expect(r.accuracyPercent, 89);
      expect(r.durationLabel, '6분 52초');
    });
  });

  test('소요 시간 표시', () {
    String label(int sec) => AttemptResult(score: 0, maxScore: 0, correct: 0, total: 0, durationSec: sec).durationLabel;
    expect(label(0), '0초');
    expect(label(59), '59초');
    expect(label(60), '1분 0초');
    expect(label(3600), '1시간');
    expect(label(3600 + 5 * 60 + 7), '1시간 5분');
  });

  test('요청 번호는 UUID v4 모양이고 매번 다르다', () {
    final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    final ids = {for (var i = 0; i < 100; i++) newRequestId(Random(i))};
    expect(ids, hasLength(100));
    expect(ids.every(pattern.hasMatch), isTrue);
  });

  group('SupabaseAttemptRepository', () {
    test('함수 이름과 매개변수가 서버 약속과 같다', () async {
      final calls = <List<Object>>[];
      final repo = SupabaseAttemptRepository((f, p) async {
        calls.add([f, p]);
        return switch (f) {
          'start_attempt' => {'attempt_id': 1, 'resumed': true, 'words': <Object>[]},
          'check_word' => {'correct': false, 'tries': 1, 'tries_left': 4, 'score': 0},
          _ => {'score': 0, 'max_score': 100, 'correct': 0, 'total': 1, 'duration_sec': 3},
        };
      });
      expect((await repo.start('beg-001')).resumed, isTrue);
      await repo.check(attemptId: 1, clueId: 33, guess: 'NOTE', requestId: 'id-1');
      await repo.finish(1);
      expect(calls, [
        ['start_attempt', {'p_puzzle_id': 'beg-001'}],
        ['check_word', {'p_attempt_id': 1, 'p_clue_id': 33, 'p_guess': 'NOTE', 'p_request_id': 'id-1'}],
        ['finish_attempt', {'p_attempt_id': 1}],
      ]);
    });

    test('서버 예외를 앱 오류로 바꾼다', () async {
      Future<void> check(String message, String? code, AttemptError expected) => expectLater(
            SupabaseAttemptRepository((_, _) async => throw PostgrestException(message: message, code: code)).finish(1),
            failsWith(expected),
            reason: message,
          );
      await check('not_authenticated', 'P0001', AttemptError.notAuthenticated);
      await check('permission denied for function finish_attempt', '42501', AttemptError.notAuthenticated);
      await check('JWT expired', 'PGRST303', AttemptError.notAuthenticated);
      await check('puzzle_not_found', 'P0001', AttemptError.puzzleNotFound);
      await check('attempt_not_found', 'P0001', AttemptError.attemptEnded);
      await check('attempt_closed', 'P0001', AttemptError.attemptEnded);
      await check('invalid_guess', 'P0001', AttemptError.invalidGuess);
      await check('no_tries_left', 'P0001', AttemptError.noTriesLeft);
      await check('clue_not_in_puzzle', 'P0001', AttemptError.unknown);
    });

    test('연결 실패·시간 초과는 network, 이상한 응답은 unknown', () async {
      await expectLater(SupabaseAttemptRepository((_, _) async => throw Exception('socket')).finish(1), failsWith(AttemptError.network));
      await expectLater(
        SupabaseAttemptRepository((_, _) => Completer<Object?>().future, timeout: const Duration(milliseconds: 10)).finish(1),
        failsWith(AttemptError.network),
      );
      await expectLater(SupabaseAttemptRepository((_, _) async => null).finish(1), failsWith(AttemptError.unknown));
      await expectLater(SupabaseAttemptRepository((_, _) async => {'x': 1}).start('a'), failsWith(AttemptError.unknown));
    });
  });

  group('FakeAttemptRepository (서버와 같은 규칙)', () {
    late FakeAttemptRepository repo;
    late int attempt;
    var seq = 0;
    Future<CheckResult> check(String guess, {int clue = 1, String? id}) =>
        repo.check(attemptId: attempt, clueId: clue, guess: guess, requestId: id ?? 'r${seq++}');

    setUp(() async {
      repo = FakeAttemptRepository(FakePuzzleRepository(puzzles: testPuzzles), isCorrect: testIsCorrect);
      attempt = (await repo.start('beg-001')).attemptId;
    });

    test('점수는 틀린 확인마다 10점 깎인다', () async {
      expect((await check('BRANCH')).score, 100);
      expect((await check('GATE', clue: 2)).triesLeft, 4);
      expect((await check('MELL', clue: 2)).triesLeft, 3);
      final r = await check('mall', clue: 2);
      expect((r.correct, r.score, r.answer, r.tries), (true, 80, 'MALL', 3));
    });

    test('바로 앞과 같은 오답은 세지 않고, 5번 다 틀리면 거부한다', () async {
      expect((await check('AAAAAA')).counted, isTrue);
      final again = await check('AAAAAA');
      expect((again.counted, again.triesLeft), (false, 4));
      for (final g in ['BBBBBB', 'CCCCCC', 'DDDDDD', 'EEEEEE']) {
        await check(g);
      }
      await expectLater(check('BRANCH'), failsWith(AttemptError.noTriesLeft));
    });

    test('같은 요청 번호는 한 번만 처리하고, 글자 수가 다르면 세지 않는다', () async {
      final a = await check('AAAAAA', id: 'same');
      final b = await check('AAAAAA', id: 'same');
      expect((a.triesLeft, b.triesLeft, b.counted), (4, 4, true));
      await expectLater(check('AB'), failsWith(AttemptError.invalidGuess));
      expect((await repo.start('beg-001')).words.first.triesLeft, 4);
    });

    test('이어 풀기: 맞힌 단어를 그대로 돌려주고, 제출하면 새 기록이 된다', () async {
      await check('BRANCH');
      final resumed = await repo.start('beg-001');
      expect((resumed.resumed, resumed.attemptId), (true, attempt));
      expect(resumed.words.first.answer, 'BRANCH');

      final r = await repo.finish(attempt);
      expect((r.score, r.maxScore, r.correct, r.total), (100, 2400, 1, 24));
      expect(identical(await repo.finish(attempt), r), isTrue);
      await expectLater(check('MALL', clue: 2), failsWith(AttemptError.attemptEnded));
      final fresh = await repo.start('beg-001');
      expect((fresh.resumed, fresh.words.first.solved), (false, false));
    });
  });

  test('로컬 샘플: 단서마다 정답 해시가 있고, 정답 필드는 없다', () {
    expect(sampleAnswerHashes.keys, samplePuzzles.keys);
    for (final MapEntry(key: id, value: source) in samplePuzzles.entries) {
      final p = PuzzleData.fromJson(jsonDecode(source) as Map<String, dynamic>);
      expect(sampleAnswerHashes[id]!.keys.toSet(), p.clues.map((c) => c.id).toSet(), reason: id);
      final clues = ((jsonDecode(source) as Map)['clues'] as List).cast<Map<String, dynamic>>();
      expect(clues.any((c) => c.containsKey('word') || c.containsKey('answer')), isFalse, reason: id);
    }
    expect(sampleIsCorrect('beg-001', 1, 'NOTE'), isTrue);
    expect(sampleIsCorrect('beg-001', 1, 'TONE'), isFalse);
    expect(sampleIsCorrect('beg-001', 2, 'NOTE'), isFalse);
    expect(sampleIsCorrect('nope', 1, 'NOTE'), isFalse);
  });
}
