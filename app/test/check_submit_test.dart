import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wordcross/app/app.dart';
import 'package:wordcross/app/router.dart';
import 'package:wordcross/app/theme.dart';
import 'package:wordcross/features/auth/auth_providers.dart';
import 'package:wordcross/features/auth/fake_auth_repository.dart';
import 'package:wordcross/features/play/attempt.dart';
import 'package:wordcross/features/play/attempt_repository.dart';
import 'package:wordcross/features/play/fake_attempt_repository.dart';
import 'package:wordcross/features/play/fake_puzzle_repository.dart';
import 'package:wordcross/features/play/play_providers.dart';
import 'package:wordcross/features/play/widgets/letter_keyboard.dart';
import 'package:wordcross/features/play/widgets/puzzle_grid.dart';
import 'package:wordcross/features/puzzles/puzzle_list_screen.dart';

import 'fixtures/test_puzzles.dart';

/// 다음 요청 하나를 실패시키거나, 서버에는 닿았지만 응답을 잃은 상황을 만든다.
class FlakyAttempts implements AttemptRepository {
  FlakyAttempts(this.inner);

  final FakeAttemptRepository inner;
  AttemptError? failStart, failCheck, failFinish;

  /// true면 서버가 처리한 뒤 응답만 잃어버린다.
  bool loseResponse = false;
  final requestIds = <String>[];

  @override
  Future<AttemptStart> start(String puzzleId) async {
    if (failStart case final e?) {
      failStart = null;
      throw AttemptFailure(e);
    }
    return inner.start(puzzleId);
  }

  @override
  Future<CheckResult> check({
    required int attemptId,
    required int clueId,
    required String guess,
    required String requestId,
  }) async {
    requestIds.add(requestId);
    if (failCheck case final e?) {
      failCheck = null;
      if (loseResponse) await inner.check(attemptId: attemptId, clueId: clueId, guess: guess, requestId: requestId);
      throw AttemptFailure(e);
    }
    return inner.check(attemptId: attemptId, clueId: clueId, guess: guess, requestId: requestId);
  }

  @override
  Future<AttemptResult> finish(int attemptId) async {
    if (failFinish case final e?) {
      failFinish = null;
      throw AttemptFailure(e);
    }
    return inner.finish(attemptId);
  }
}

FlakyAttempts newAttempts() =>
    FlakyAttempts(FakeAttemptRepository(
      FakePuzzleRepository(puzzles: testPuzzles),
      isCorrect: testIsCorrect,
      answerOf: (puzzleId, clueId) => testAnswers[clueId],
    ));

/// 로그인한 상태로 beg-001 풀이 화면을 연다.
Future<FlakyAttempts> openPlay(WidgetTester tester, {FlakyAttempts? attempts}) async {
  final repo = attempts ?? newAttempts();
  final auth = FakeAuthRepository();
  addTearDown(auth.dispose);
  await auth.signUp(email: 'user@example.com', password: 'password1', nickname: '태웅');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        puzzleRepositoryProvider.overrideWithValue(FakePuzzleRepository(puzzles: testPuzzles)),
        attemptRepositoryProvider.overrideWithValue(repo),
      ],
      child: const WordCrossApp(),
    ),
  );
  await tester.pumpAndSettle();
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(routerProvider).go(Routes.playPath('beg-001'));
  await tester.pumpAndSettle();
  return repo;
}

Finder cell(int r, int c) => find.byKey(PuzzleGrid.cellKey(r, c));
Finder cellText(int r, int c, String text) => find.descendant(of: cell(r, c), matching: find.text(text));

Color cellColor(WidgetTester tester, int r, int c) {
  final box = tester.widget<DecoratedBox>(find.descendant(of: cell(r, c), matching: find.byType(DecoratedBox)).first);
  return (box.decoration as BoxDecoration).color!;
}

Future<void> type(WidgetTester tester, String word) async {
  for (final ch in word.split('')) {
    await tester.tap(find.byKey(LetterKeyboard.letterKey(ch)));
    await tester.pump();
  }
}

Future<void> clearWord(WidgetTester tester, int length) async {
  for (var i = 0; i < length; i++) {
    await tester.tap(find.byKey(LetterKeyboard.backspaceKey));
    await tester.pump();
  }
}

Future<void> tapCheck(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('play-check')));
  await tester.pumpAndSettle();
}

Future<void> tapSubmit(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('play-submit')));
  await tester.pumpAndSettle();
}

/// 결과 화면의 큰 점수.
String? scoreText(WidgetTester tester) => tester.widget<Text>(find.byKey(const ValueKey('result-score'))).data;

String? notice(WidgetTester tester) {
  final f = find.byKey(const ValueKey('play-notice'));
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

void main() {
  testWidgets('단어 칸이 다 차야 확인할 수 있고, 맞히면 민트색으로 잠기고 점수·진행률이 바뀐다', (tester) async {
    final repo = await openPlay(tester);
    await type(tester, 'BRANC');
    await tapCheck(tester);
    expect(repo.requestIds, isEmpty); // 빈칸이 있으면 서버로 보내지 않는다

    await type(tester, 'H');
    expect(find.text('0 / 24 단어'), findsOneWidget); // 채우기만 해서는 올라가지 않는다
    await tapCheck(tester);
    expect(notice(tester), '정답이에요! +100점');
    expect(find.text('1 / 24 단어'), findsOneWidget);
    expect(find.text('6글자 · 한국어 뜻 · 맞힘 100점'), findsOneWidget);
    expect(cellColor(tester, 0, 1), V3Colors.mint);

    // 맞힌 단어는 다시 확인하거나 지울 수 없다.
    await tapCheck(tester);
    expect(repo.requestIds, hasLength(1));
    await clearWord(tester, 6);
    expect(cellText(0, 0, 'B'), findsOneWidget);
    expect(cellText(0, 5, 'H'), findsOneWidget);
  });

  testWidgets('틀리면 남은 횟수를 알려 주고, 같은 답은 줄지 않으며, 5번 틀리면 확인할 수 없다', (tester) async {
    final repo = await openPlay(tester);
    await type(tester, 'AAAAAA');
    await tapCheck(tester);
    expect(notice(tester), '아직 아니에요. 확인이 4번 남았어요.');
    expect(find.text('6글자 · 한국어 뜻 · 확인 4번 남음'), findsOneWidget);
    expect(cellColor(tester, 0, 1), V3Colors.apricot);

    await tapCheck(tester);
    expect(notice(tester), '방금과 같은 답이에요. 횟수는 줄지 않았어요.');

    for (final (i, ch) in ['C', 'D', 'E', 'F'].indexed) {
      await clearWord(tester, 1);
      await type(tester, ch);
      expect(notice(tester), isNull); // 다시 입력하면 안내가 사라진다
      await tapCheck(tester);
      if (i < 3) expect(notice(tester), '아직 아니에요. 확인이 ${3 - i}번 남았어요.');
    }
    expect(notice(tester), '확인 5번을 다 썼어요. 정답 공개만 할 수 있어요.');
    expect(find.text('6글자 · 한국어 뜻 · 확인 0번 남음'), findsOneWidget);

    final sent = repo.requestIds.length;
    await clearWord(tester, 1);
    await type(tester, 'H');
    await tapCheck(tester);
    expect(repo.requestIds, hasLength(sent));
  });

  testWidgets('맞힌 글자는 교차하는 단어에서도 바뀌지 않고, 단어를 처음부터 쳐도 된다', (tester) async {
    await openPlay(tester);
    await type(tester, 'BRANCH');
    await tapCheck(tester);

    // 1세로 BAGGAGE: 첫 칸 B가 잠겨 있다.
    await tester.tap(cell(0, 0));
    await tester.pump();
    await tester.tap(cell(0, 0));
    await tester.pump();
    await type(tester, 'BAGGAGE');
    expect(cellText(0, 0, 'B'), findsOneWidget);
    expect(cellText(6, 0, 'E'), findsOneWidget);
    await tapCheck(tester);
    expect(notice(tester), '정답이에요! +100점');
  });

  testWidgets('연결이 끊기면 글자를 두고 다시 시도하며, 같은 요청 번호로 보내 횟수를 한 번만 센다', (tester) async {
    final repo = newAttempts()
      ..failCheck = AttemptError.network
      ..loseResponse = true;
    await openPlay(tester, attempts: repo);
    await type(tester, 'AAAAAA');
    await tapCheck(tester);
    expect(notice(tester), '연결을 확인해 주세요.');
    expect(cellText(0, 0, 'A'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(repo.requestIds, hasLength(2));
    expect(repo.requestIds.toSet(), hasLength(1));
    expect(notice(tester), '아직 아니에요. 확인이 4번 남았어요.');
  });

  testWidgets('연결 실패 뒤 답을 고쳐 확인하면 새 요청 번호를 쓴다', (tester) async {
    final repo = newAttempts()..failCheck = AttemptError.network;
    await openPlay(tester, attempts: repo);
    await type(tester, 'AAAAAA');
    await tapCheck(tester);
    await clearWord(tester, 6);
    await type(tester, 'BRANCH');
    await tapCheck(tester);
    expect(notice(tester), '정답이에요! +100점');
    expect(repo.requestIds.toSet(), hasLength(2));
  });

  testWidgets('Enter 키로도 확인한다', (tester) async {
    await openPlay(tester);
    await type(tester, 'BRANCH');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(notice(tester), '정답이에요! +100점');
  });

  testWidgets('남은 단어가 있으면 제출 확인 창을 거치고, 계속 풀기를 누르면 이어진다', (tester) async {
    await openPlay(tester);
    await type(tester, 'BRANCH');
    await tapCheck(tester);

    await tapSubmit(tester);
    expect(find.text('아직 23단어 남았어요. 제출할까요?'), findsOneWidget);
    await tester.tap(find.text('계속 풀기'));
    await tester.pumpAndSettle();
    expect(find.text('퍼즐 완료!'), findsNothing);
    expect(find.text('1 / 24 단어'), findsOneWidget);

    await tapSubmit(tester);
    await tester.tap(find.widgetWithText(FilledButton, '제출'));
    await tester.pumpAndSettle();
    expect(find.text('퍼즐 완료!'), findsOneWidget);
    expect(scoreText(tester), '100');
    expect(find.text('/ 2,400점'), findsOneWidget);
    expect(find.text('정답률 1/24'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('result-close')));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleCard), findsOneWidget);
  });

  testWidgets('모든 단어를 맞히면 확인 창 없이 제출한다', (tester) async {
    final attempts = newAttempts();
    final start = await attempts.inner.start('beg-001');
    // 1가로만 남기고 다른 단어는 미리 맞혀 둔다.
    for (final MapEntry(key: id, value: word) in testAnswers.entries) {
      if (id != 1) await attempts.inner.check(attemptId: start.attemptId, clueId: id, guess: word, requestId: 'p$id');
    }
    await openPlay(tester, attempts: attempts);
    expect(notice(tester), '이어서 풀어요. 맞힌 단어 23개를 불러왔어요.');
    // 교차하는 B·A·C가 채워져 있어 나머지만 쳐도 된다.
    await type(tester, 'BRANCH');
    await tapCheck(tester);
    expect(notice(tester), '모든 단어를 맞혔어요! 제출해 주세요.');
    await tapSubmit(tester);
    expect(find.text('퍼즐 완료!'), findsOneWidget);
    expect(scoreText(tester), '2,400');
  });

  testWidgets('다시 열면 맞힌 단어와 남은 횟수를 서버 기록대로 이어 푼다', (tester) async {
    final repo = await openPlay(tester);
    await type(tester, 'BRANCH');
    await tapCheck(tester);
    await tester.tap(cell(0, 7));
    await tester.pump();
    await type(tester, 'GATE');
    await tapCheck(tester);

    await tester.tap(find.byKey(const ValueKey('play-close')));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await openPlay(tester, attempts: repo);
    expect(notice(tester), '이어서 풀어요. 맞힌 단어 1개를 불러왔어요.');
    expect(cellText(0, 5, 'H'), findsOneWidget);
    expect(find.text('1 / 24 단어'), findsOneWidget);
    await tester.tap(cell(0, 7));
    await tester.pump();
    expect(find.textContaining('확인 4번 남음'), findsOneWidget);
  });

  testWidgets('다른 기기에서 먼저 맞힌 단어를 확인하면 이미 풀었다고 알려 준다', (tester) async {
    final repo = await openPlay(tester);
    await repo.inner.check(attemptId: 1, clueId: 1, guess: 'BRANCH', requestId: 'other-device');
    await type(tester, 'AAAAAA');
    await tapCheck(tester);
    expect(notice(tester), '이미 풀었어요.');
    expect(cellText(0, 0, 'B'), findsOneWidget);
  });

  testWidgets('끝난 풀이면 다시 시작할 수 있다', (tester) async {
    final repo = await openPlay(tester);
    await repo.inner.finish(1);
    await type(tester, 'BRANCH');
    await tapCheck(tester);
    expect(find.text('이 풀이는 끝났어요.'), findsOneWidget);

    await tester.tap(find.text('다시 시작'));
    await tester.pumpAndSettle();
    expect(cellText(0, 0, 'B'), findsNothing);
    await type(tester, 'BRANCH');
    await tapCheck(tester);
    expect(notice(tester), '정답이에요! +100점');
  });

  testWidgets('제출 중 연결이 끊기면 다시 시도할 수 있다', (tester) async {
    final repo = newAttempts()..failFinish = AttemptError.network;
    await openPlay(tester, attempts: repo);
    await tapSubmit(tester);
    await tester.tap(find.widgetWithText(FilledButton, '제출'));
    await tester.pumpAndSettle();
    expect(notice(tester), '연결을 확인해 주세요.');
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('퍼즐 완료!'), findsOneWidget);
  });

  testWidgets('로그인이 풀리면 로그인 화면으로 보낸다', (tester) async {
    final repo = newAttempts()..failCheck = AttemptError.notAuthenticated;
    await openPlay(tester, attempts: repo);
    await type(tester, 'BRANCH');
    await tapCheck(tester);
    expect(find.text('십자말풀이로 익히는 토익 단어'), findsOneWidget);
    expect(find.text('로그인이 풀렸어요. 다시 로그인해 주세요.'), findsOneWidget);
  });

  testWidgets('풀이를 시작하지 못하면 오류를 보여 주고 다시 시도한다', (tester) async {
    final repo = newAttempts()..failStart = AttemptError.network;
    await openPlay(tester, attempts: repo);
    expect(find.text('연결을 확인해 주세요.'), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleGrid), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(320, 568)]) {
    testWidgets('작은 화면(${size.width.toInt()}×${size.height.toInt()})에서 안내·대화 상자가 넘치지 않는다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = newAttempts()..failCheck = AttemptError.network;
      await openPlay(tester, attempts: repo);
      await type(tester, 'AAAAAA');
      await tapCheck(tester);
      expect(find.text('다시 시도'), findsOneWidget);
      await tapSubmit(tester);
      expect(find.text('계속 풀기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
