import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wordcross/app/router.dart';
import 'package:wordcross/features/play/attempt.dart';
import 'package:wordcross/features/puzzles/puzzle_list_screen.dart';
import 'package:wordcross/features/wrong_notes/wrong_notes_screen.dart';

import 'check_submit_test.dart' show newAttempts, openPlay, scoreText, tapCheck, tapSubmit, type, cell, clearWord;
import 'fixtures/test_puzzles.dart';

WordResult word(int id, {bool solved = false, bool revealed = false, int tries = 0, int hints = 0}) =>
    WordResult(clueId: id, no: id, dir: 'across', word: 'W$id', solved: solved, revealed: revealed, tries: tries, letterHints: hints);

/// 맞힌 단어 2개를 만들고 제출한다: 1가로 BRANCH(한 번에), 2가로 MALL(두 번 틀린 뒤). 2세로는 5번 다 틀린다.
Future<void> solveSomeAndSubmit(WidgetTester tester) async {
  await type(tester, 'BRANCH');
  await tapCheck(tester);
  await tester.tap(cell(0, 7));
  await tester.pump();
  for (final guess in ['GATE', 'MAIL']) {
    await type(tester, guess);
    await tapCheck(tester);
    await clearWord(tester, 4);
  }
  await type(tester, 'MALL');
  await tapCheck(tester);
  await tapSubmit(tester);
  await tester.tap(find.widgetWithText(FilledButton, '제출'));
  await tester.pumpAndSettle();
}

void main() {
  group('결과 계산', () {
    test('finish_attempt 의 단어별 결과를 읽는다', () {
      final r = AttemptResult.fromJson(jsonDecode('''
        {"score": 180, "max_score": 300, "correct": 2, "total": 3, "duration_sec": 702,
         "words": [
          {"clue_id": 1, "no": 1, "dir": "across", "word": "NOTE", "meaning_ko": "메모", "solved": true, "tries": 1, "score": 100},
          {"clue_id": 2, "no": 2, "dir": "down", "word": "LEASE", "meaning_ko": " ", "solved": false, "revealed": true, "tries": 2},
          {"clue_id": 3, "no": 3, "dir": "across", "word": "VENDOR", "solved": true, "tries": 3, "letter_hints": 1, "score": 60}
         ]}''') as Map<String, dynamic>);
      expect(r.words.length, 3);
      expect((r.words[0].word, r.words[0].meaningKo, r.words[0].wrongTries), ('NOTE', '메모', 0));
      expect(r.words[1].meaningKo, isNull);
      expect(r.durationClock, '11:42');
      expect(r.letterHints, 1);
      expect([for (final w in r.wrongWords) w.word], ['LEASE', 'VENDOR']);
      expect([for (final w in r.solvedWords) w.word], ['NOTE', 'VENDOR']);
    });

    test('오답 노트 순서: 정답 공개 → 못 끝냄 → 많이 틀린 순', () {
      final r = AttemptResult(score: 0, maxScore: 0, correct: 0, total: 0, durationSec: 0, words: [
        word(1, solved: true, tries: 1),
        word(2, solved: true, tries: 2),
        word(3),
        word(4, solved: true, tries: 4),
        word(5, revealed: true, tries: 1),
      ]);
      expect([for (final w in r.wrongWords) w.clueId], [5, 3, 4, 2]);
      expect(r.wrongWords.map((w) => w.wrongTries), [1, 0, 3, 1]);
    });

    test('시계 모양 소요 시간', () {
      String clock(int sec) => AttemptResult(score: 0, maxScore: 0, correct: 0, total: 0, durationSec: sec).durationClock;
      expect(clock(5), '0:05');
      expect(clock(702), '11:42');
      expect(clock(3725), '1:02:05');
    });

    test('로컬 모드처럼 철자를 모르면 글자 수만큼 물음표', () {
      expect(const WordResult(clueId: 1, no: 1, dir: 'across', length: 4).display, '????');
    });
  });

  group('결과 화면', () {
    testWidgets('점수·정답률·시간과 오답 노트 단어를 보여 준다', (tester) async {
      final repo = newAttempts();
      // 1세로 BAGGAGE 를 5번 다 틀려 둔다 (단서 id 13).
      final start = await repo.inner.start('beg-001');
      for (final (i, guess) in ['AAAAAAA', 'CCCCCCC', 'DDDDDDD', 'EEEEEEE', 'FFFFFFF'].indexed) {
        await repo.inner.check(attemptId: start.attemptId, clueId: 13, guess: guess, requestId: 'w$i');
      }
      await openPlay(tester, attempts: repo);
      await solveSomeAndSubmit(tester);

      expect(find.text('퍼즐 완료!'), findsOneWidget);
      expect(find.text('초급 #001'), findsOneWidget);
      expect(scoreText(tester), '180');
      expect(find.text('/ 2,400점'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('result-accuracy'))).data, '8%');
      expect(find.text('정답률 2/24'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('result-hints'))).data, '0번');

      // 맞힌 BRANCH 는 빠지고, 두 번 틀린 MALL·못 푼 단어는 들어간다.
      expect(find.text('오답 노트에 추가된 단어 23개'), findsOneWidget);
      final wrong = find.byKey(const ValueKey('result-wrong'));
      expect(find.descendant(of: wrong, matching: find.text('BRANCH')), findsNothing);
      expect(find.descendant(of: wrong, matching: find.text('BAGGAGE')), findsOneWidget);
      expect(find.descendant(of: wrong, matching: find.text('5번 틀림')), findsOneWidget);
      expect(find.descendant(of: wrong, matching: find.text('미완료')), findsNWidgets(21));
      await tester.scrollUntilVisible(find.text('MALL'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: wrong, matching: find.text('2번 틀림')), findsOneWidget);
    });

    testWidgets('맞힌 단어를 펼쳐 볼 수 있다', (tester) async {
      await openPlay(tester);
      await solveSomeAndSubmit(tester);
      final toggle = find.byKey(const ValueKey('result-toggle-solved'));
      await tester.scrollUntilVisible(toggle, 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('맞힌 단어 2개 보기'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final solved = find.byKey(const ValueKey('result-solved'));
      expect(find.descendant(of: solved, matching: find.text('BRANCH')), findsOneWidget);
      expect(find.descendant(of: solved, matching: find.text('+100')), findsOneWidget);
      expect(find.descendant(of: solved, matching: find.text('+80')), findsOneWidget);
      expect(find.text('맞힌 단어 2개 접기'), findsOneWidget);
    });

    testWidgets('하나도 틀리지 않으면 완벽하다고 알려 준다', (tester) async {
      final attempts = newAttempts();
      final start = await attempts.inner.start('beg-001');
      for (final MapEntry(key: id, value: w) in testAnswers.entries) {
        await attempts.inner.check(attemptId: start.attemptId, clueId: id, guess: w, requestId: 'p$id');
      }
      await openPlay(tester, attempts: attempts);
      await tapSubmit(tester);
      expect(find.text('오답 노트에 추가된 단어가 없어요'), findsOneWidget);
      expect(find.text('한 번도 틀리지 않았어요.\n완벽해요!'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('result-accuracy'))).data, '100%');
    });

    testWidgets('오답 노트로 가기', (tester) async {
      await openPlay(tester);
      await solveSomeAndSubmit(tester);
      final button = find.byKey(const ValueKey('result-wrong-notes'));
      await tester.scrollUntilVisible(button, 400, scrollable: find.byType(Scrollable).first);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(WrongNotesScreen), findsOneWidget);
    });

    testWidgets('마지막 퍼즐이면 다음 퍼즐 대신 퍼즐 목록으로 간다', (tester) async {
      await openPlay(tester);
      await solveSomeAndSubmit(tester);
      final button = find.byKey(const ValueKey('result-next'));
      await tester.scrollUntilVisible(button, 400, scrollable: find.byType(Scrollable).first);
      expect(find.descendant(of: button, matching: find.text('퍼즐 목록')), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleCard), findsOneWidget);
    });

    testWidgets('뒤로 가기는 끝난 풀이가 아니라 퍼즐 목록으로', (tester) async {
      await openPlay(tester);
      await solveSomeAndSubmit(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleCard), findsOneWidget);
      expect(find.text('퍼즐 완료!'), findsNothing);
    });

    testWidgets('결과 값 없이 주소로만 들어오면 퍼즐 목록으로 보낸다', (tester) async {
      await openPlay(tester);
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(routerProvider).go(Routes.resultPath('beg-001'));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleCard), findsOneWidget);
    });
  });
}
