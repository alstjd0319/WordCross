import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wordcross/app/app.dart';
import 'package:wordcross/app/main_shell.dart';
import 'package:wordcross/app/router.dart';
import 'package:wordcross/features/auth/auth_providers.dart';
import 'package:wordcross/features/auth/fake_auth_repository.dart';
import 'package:wordcross/features/play/fake_attempt_repository.dart';
import 'package:wordcross/features/play/fake_puzzle_repository.dart';
import 'package:wordcross/features/play/play_providers.dart';
import 'package:wordcross/features/play/play_screen.dart';
import 'package:wordcross/features/play/play_state.dart';
import 'package:wordcross/features/play/widgets/hint_bubble.dart';
import 'package:wordcross/features/play/widgets/letter_keyboard.dart';
import 'package:wordcross/features/play/widgets/puzzle_grid.dart';
import 'package:wordcross/features/play/widgets/zoomable_grid.dart';
import 'package:wordcross/features/puzzles/puzzle_list_screen.dart';

import 'fixtures/test_puzzles.dart';

/// 로그인한 상태로 앱을 띄운다.
Future<GoRouter> pumpLoggedIn(WidgetTester tester) async {
  final auth = FakeAuthRepository();
  final puzzles = FakePuzzleRepository(puzzles: testPuzzles);
  addTearDown(auth.dispose);
  await auth.signUp(email: 'user@example.com', password: 'password1', nickname: '태웅');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        puzzleRepositoryProvider.overrideWithValue(puzzles),
        attemptRepositoryProvider.overrideWithValue(FakeAttemptRepository(puzzles, isCorrect: testIsCorrect)),
      ],
      child: const WordCrossApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  return container.read(routerProvider);
}

Finder cell(int r, int c) => find.byKey(PuzzleGrid.cellKey(r, c));
Finder cellText(int r, int c, String text) => find.descendant(of: cell(r, c), matching: find.text(text));
Finder hintText(String text) =>
    find.byWidgetPredicate((w) => w is Text && w.key == const ValueKey('hint-text') && w.data == text);

/// 초급 #001을 연다. [showHint]면 지금 칸(1가로 첫 칸)을 눌러 힌트 말풍선을 띄운다 (처음에는 닫혀 있다).
Future<void> openSample(WidgetTester tester, {bool showHint = true}) async {
  await tester.tap(find.text('퍼즐').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('초급 #001'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('시작하기'));
  await tester.pumpAndSettle();
  if (showHint) {
    await tester.tap(cell(0, 0));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('목록 → 상세 → 시작하기로 열면 하단 메뉴 없이 격자·힌트·키보드가 나오고, 닫으면 상세로 돌아간다', (tester) async {
    await pumpLoggedIn(tester);
    await openSample(tester);

    expect(find.text('초급 #001'), findsOneWidget);
    expect(find.text('0 / 24 단어'), findsOneWidget);
    expect(find.byType(MainNavBar), findsNothing);
    expect(find.byType(PuzzleGrid), findsOneWidget);
    expect(find.byType(LetterKeyboard), findsOneWidget);
    expect(hintText('나뭇가지, 가지'), findsOneWidget);
    expect(find.text('6글자 · 한국어 뜻'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play-close')));
    await tester.pumpAndSettle();
    expect(find.text('시작하기'), findsOneWidget);
    expect(find.byType(MainNavBar), findsNothing);

    await tester.tap(find.byTooltip('뒤로'));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleCard), findsOneWidget);
    expect(find.byType(MainNavBar), findsOneWidget);
  });

  testWidgets('전용 키보드로 넣은 글자가 칸에 보이고, 지우기로 지운다', (tester) async {
    await pumpLoggedIn(tester);
    await openSample(tester);

    for (final ch in 'BRA'.split('')) {
      await tester.tap(find.byKey(LetterKeyboard.letterKey(ch)));
      await tester.pump();
    }
    expect(cellText(0, 0, 'B'), findsOneWidget);
    expect(cellText(0, 1, 'R'), findsOneWidget);
    expect(cellText(0, 2, 'A'), findsOneWidget);

    // 지금 칸(0,3)은 비어 있으므로 앞 칸 A를 지운다.
    await tester.tap(find.byKey(LetterKeyboard.backspaceKey));
    await tester.pump();
    expect(cellText(0, 2, 'A'), findsNothing);
    expect(cellText(0, 1, 'R'), findsOneWidget);

    await tester.tap(find.byKey(LetterKeyboard.backspaceKey));
    await tester.pump();
    expect(cellText(0, 1, 'R'), findsNothing);
    expect(cellText(0, 0, 'B'), findsOneWidget);
  });

  testWidgets('칸을 누르면 그 단어 힌트로, 같은 칸을 다시 누르면 세로 단어 힌트로 바뀐다', (tester) async {
    await pumpLoggedIn(tester);
    await openSample(tester);

    // 0행 7열: 4가로 MALL 의 첫 칸
    await tester.tap(cell(0, 7));
    await tester.pump();
    expect(hintText('쇼핑 센터'), findsOneWidget);

    // 0행 0열은 1가로·1세로가 겹치는 칸. 지금 칸이 아니므로 한 번 누르면 가로 그대로.
    await tester.tap(cell(0, 0));
    await tester.pump();
    expect(hintText('나뭇가지, 가지'), findsOneWidget);
    await tester.tap(cell(0, 0));
    await tester.pump();
    // 1세로 BAGGAGE 는 한국어 뜻이 없어 영어 정의를 보여 준다.
    expect(hintText('travel bags'), findsOneWidget);
    expect(find.text('7글자 · 영어 정의'), findsOneWidget);
  });

  testWidgets('힌트 전환 버튼과 이전·다음 단어 버튼', (tester) async {
    await pumpLoggedIn(tester);
    await openSample(tester);

    await tester.tap(find.byKey(const ValueKey('hint-toggle')));
    await tester.pump();
    expect(find.text('6글자 · 영어 정의'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clue-next')));
    await tester.pump();
    // 4가로 MALL: 고른 영어 정의를 계속 보여 준다.
    expect(hintText('very large building containing lots of stores and restaurants'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clue-prev')));
    await tester.tap(find.byKey(const ValueKey('clue-prev')));
    await tester.pump();
    // 1가로의 앞은 마지막 세로 단어(18세로).
    expect(find.text('3글자 · 영어 정의'), findsOneWidget);
  });

  testWidgets('실제 키보드로도 입력한다', (tester) async {
    await pumpLoggedIn(tester);
    await openSample(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(cellText(0, 0, 'B'), findsOneWidget);
    expect(cellText(0, 1, 'R'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(cellText(0, 1, 'R'), findsNothing);
  });

  testWidgets('입력 소스가 한글이어도 실제 키보드의 알파벳 키로 입력한다', (tester) async {
    await pumpLoggedIn(tester);
    await openSample(tester);

    // 한글 두벌식에서 B·R 키는 'ㅠ'·'ㄱ' 글자로 들어온다.
    await simulateKeyDownEvent(LogicalKeyboardKey.keyB, physicalKey: PhysicalKeyboardKey.keyB, character: 'ㅠ');
    await simulateKeyUpEvent(LogicalKeyboardKey.keyB, physicalKey: PhysicalKeyboardKey.keyB);
    await simulateKeyDownEvent(LogicalKeyboardKey.keyR, physicalKey: PhysicalKeyboardKey.keyR, character: 'ㄱ');
    await simulateKeyUpEvent(LogicalKeyboardKey.keyR, physicalKey: PhysicalKeyboardKey.keyR);
    await tester.pump();
    expect(cellText(0, 0, 'B'), findsOneWidget);
    expect(cellText(0, 1, 'R'), findsOneWidget);
  });

  test('letterFromKeyEvent: 알파벳 키만 글자로 바꾼다', () {
    KeyDownEvent down(PhysicalKeyboardKey p, LogicalKeyboardKey l, String? ch) =>
        KeyDownEvent(physicalKey: p, logicalKey: l, character: ch, timeStamp: Duration.zero);
    expect(letterFromKeyEvent(down(PhysicalKeyboardKey.keyQ, LogicalKeyboardKey.keyQ, 'q')), 'Q');
    expect(letterFromKeyEvent(down(PhysicalKeyboardKey.keyQ, LogicalKeyboardKey.keyQ, 'ㅂ')), 'Q');
    expect(letterFromKeyEvent(down(PhysicalKeyboardKey.keyZ, LogicalKeyboardKey.keyZ, 'ㅋ')), 'Z');
    expect(letterFromKeyEvent(down(PhysicalKeyboardKey.digit1, LogicalKeyboardKey.digit1, '1')), isNull);
    expect(letterFromKeyEvent(down(PhysicalKeyboardKey.space, LogicalKeyboardKey.space, ' ')), isNull);
  });

  testWidgets('없는 퍼즐이면 오류 문구를 보여 준다', (tester) async {
    final router = await pumpLoggedIn(tester);
    router.go(Routes.playPath('nope-999'));
    await tester.pumpAndSettle();
    expect(find.text('퍼즐을 찾을 수 없어요.'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(320, 568)]) {
    testWidgets('작은 화면(${size.width.toInt()}×${size.height.toInt()})에서도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpLoggedIn(tester);
      await openSample(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(PuzzleGrid), findsOneWidget);
    });
  }

  group('확대·이동', () {
    ZoomableGridState zoom(WidgetTester tester) => tester.state<ZoomableGridState>(find.byType(ZoomableGrid));
    Finder badge(String no) => find.descendant(of: find.byType(HintBubble), matching: find.text('$no 세로'));
    bool onScreen(WidgetTester tester, Finder target) {
      final viewport = tester.getRect(find.byType(InteractiveViewer));
      return viewport.contains(tester.getRect(target).center);
    }

    testWidgets('확대 버튼으로 확대하고, 전체 보기로 되돌린다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      expect(zoom(tester).scale, 1);
      expect(find.byTooltip('확대'), findsOneWidget);

      await tester.tap(find.byKey(ZoomableGrid.zoomButtonKey));
      await tester.pumpAndSettle();
      expect(zoom(tester).scale, greaterThan(1));
      expect(find.byTooltip('전체 보기'), findsOneWidget);
      // 1가로(왼쪽 위)를 중심으로 확대해서 맨 아래 줄은 화면 밖이다.
      expect(onScreen(tester, cell(0, 0)), isTrue);
      expect(onScreen(tester, cell(10, 0)), isFalse);

      await tester.tap(find.byKey(ZoomableGrid.zoomButtonKey));
      await tester.pumpAndSettle();
      expect(zoom(tester).scale, 1);
      expect(onScreen(tester, cell(10, 0)), isTrue);
    });

    testWidgets('확대한 채 다른 단어를 고르면 그 단어가 화면 안으로 온다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      await tester.tap(find.byKey(ZoomableGrid.zoomButtonKey));
      await tester.pumpAndSettle();
      expect(onScreen(tester, cell(10, 5)), isFalse);

      // 1가로의 앞 단어 = 마지막 세로 단어 18세로 (8,0)~(10,0), 왼쪽 아래.
      await tester.tap(find.byKey(const ValueKey('clue-prev')));
      await tester.pumpAndSettle();
      expect(badge('18'), findsOneWidget);
      expect(onScreen(tester, cell(8, 0)), isTrue);
      expect(onScreen(tester, cell(10, 0)), isTrue);
      expect(zoom(tester).scale, greaterThan(1)); // 배율은 그대로

      // 확대한 채로 보이는 칸을 누르면 평소처럼 단어가 골라진다.
      await tester.tap(cell(10, 0));
      await tester.pumpAndSettle();
      expect(badge('18'), findsOneWidget);
      expect(zoom(tester).scale, greaterThan(1));
    });

    testWidgets('확대한 채 글자를 넣어 지금 칸이 화면 밖으로 나가면 따라간다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      await tester.tap(find.byKey(ZoomableGrid.zoomButtonKey));
      await tester.pumpAndSettle();

      // 21가로 BROKER (10,5)~(10,10)를 전체 보기에서 고른 뒤 확대한다.
      await tester.tap(find.byKey(ZoomableGrid.zoomButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(cell(10, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZoomableGrid.zoomButtonKey));
      await tester.pumpAndSettle();
      expect(onScreen(tester, cell(10, 5)), isTrue);

      for (final ch in 'BROKE'.split('')) {
        await tester.tap(find.byKey(LetterKeyboard.letterKey(ch)));
        await tester.pumpAndSettle();
      }
      // 지금 칸은 단어 끝 (10,10). 화면 안에 있어야 한다.
      expect(onScreen(tester, cell(10, 10)), isTrue);
      expect(cellText(10, 9, 'E'), findsOneWidget);
    });
  });

  group('힌트 길이와 격자 크기 (교수님 피드백)', () {
    for (final size in const [Size(411, 914), Size(360, 640), Size(320, 568)]) {
      testWidgets('단어·힌트가 바뀌어도 격자가 움직이지 않는다 (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpLoggedIn(tester);
        await openSample(tester);
        final first = tester.getRect(cell(0, 0)), last = tester.getRect(cell(10, 10));
        final prev = tester.getRect(find.byKey(const ValueKey('clue-prev')));

        for (var i = 0; i < 24; i++) {
          for (var k = 0; k < 3; k++) {
            expect(tester.getRect(cell(0, 0)), first);
            expect(tester.getRect(cell(10, 10)), last);
            expect(tester.getRect(find.byKey(const ValueKey('clue-prev'))), prev);
            final toggle = find.byKey(const ValueKey('hint-toggle'));
            if (toggle.evaluate().isEmpty) break;
            await tester.tap(toggle);
            await tester.pump();
          }
          await tester.tap(find.byKey(const ValueKey('clue-next')));
          await tester.pump();
        }

        // 확인 결과 안내가 떠도 그대로다.
        for (final ch in 'AAAAAA'.split('')) {
          await tester.tap(find.byKey(LetterKeyboard.letterKey(ch)));
          await tester.pump();
        }
        await tester.tap(find.byKey(const ValueKey('play-check')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('play-notice')), findsOneWidget);
        expect(tester.getRect(cell(0, 0)), first);
        expect(tester.getRect(cell(10, 10)), last);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('시스템 글자 크기를 키워도 격자가 움직이지 않고 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(411, 914);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpLoggedIn(tester);
      await openSample(tester);
      final first = tester.getRect(cell(0, 0));
      await tester.tap(find.byKey(const ValueKey('hint-toggle')));
      await tester.pump();
      expect(tester.getRect(cell(0, 0)), first);
      expect(tester.takeException(), isNull);
    });

    testWidgets('긴 힌트는 잘리지 않고 밀어서 끝까지 읽으며, 다른 힌트로 가면 처음부터 보인다', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpLoggedIn(tester);
      await openSample(tester);
      await tester.tap(find.byKey(const ValueKey('hint-toggle')));
      await tester.pumpAndSettle();

      final text = find.byKey(const ValueKey('hint-text'));
      expect(tester.widget<Text>(text).overflow, isNull);
      expect(tester.widget<Text>(text).maxLines, isNull);
      final scrollable = find.descendant(of: find.byType(HintBubble), matching: find.byType(Scrollable));
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));
      await tester.drag(scrollable, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(position.pixels, position.maxScrollExtent);

      await tester.tap(find.byKey(const ValueKey('clue-next')));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(scrollable).position.pixels, 0);
    });
  });

  group('힌트 말풍선', () {
    final bubble = find.byKey(HintBubble.bodyKey);
    PlayState board(WidgetTester tester) => tester.widget<ZoomableGrid>(find.byType(ZoomableGrid)).state;

    testWidgets('처음에는 닫혀 있고, 지금 칸을 누르면 방향은 그대로 두고 뜬다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester, showHint: false);
      expect(bubble, findsNothing);
      await tester.tap(cell(0, 0));
      await tester.pump();
      expect(hintText('나뭇가지, 가지'), findsOneWidget);
    });

    testWidgets('✕로 닫으면 격자 전체가 보이고, 글자를 넣는 동안에는 닫힌 채로 있다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      expect(bubble, findsOneWidget);
      await tester.tap(find.byKey(HintBubble.closeKey));
      await tester.pump();
      expect(bubble, findsNothing);

      await tester.tap(find.byKey(LetterKeyboard.letterKey('B')));
      await tester.pump();
      expect(cellText(0, 0, 'B'), findsOneWidget);
      expect(bubble, findsNothing);
    });

    testWidgets('떠 있는 동안 글자를 넣어도 그대로 떠 있다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      await tester.tap(find.byKey(LetterKeyboard.letterKey('B')));
      await tester.pump();
      expect(hintText('나뭇가지, 가지'), findsOneWidget);
    });

    testWidgets('닫은 뒤 다른 칸이나 이전·다음 단어를 누르면 다시 뜬다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      await tester.tap(find.byKey(HintBubble.closeKey));
      await tester.pump();
      await tester.tap(cell(0, 7));
      await tester.pump();
      expect(hintText('쇼핑 센터'), findsOneWidget);

      await tester.tap(find.byKey(HintBubble.closeKey));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('clue-prev')));
      await tester.pump();
      expect(hintText('나뭇가지, 가지'), findsOneWidget);
    });

    testWidgets('닫은 뒤 지금 칸을 누르면 방향은 그대로 두고 다시 뜨고, 한 번 더 누르면 방향이 바뀐다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      await tester.tap(find.byKey(HintBubble.closeKey));
      await tester.pump();
      await tester.tap(cell(0, 0));
      await tester.pump();
      expect(hintText('나뭇가지, 가지'), findsOneWidget);
      await tester.tap(cell(0, 0));
      await tester.pump();
      expect(hintText('travel bags'), findsOneWidget);
    });

    testWidgets('같은 단어의 다른 칸을 눌러도 다시 뜨고, 검은 칸을 누르면 뜨지 않는다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      final block = board(tester).puzzle.blocks.first;
      await tester.tap(find.byKey(HintBubble.closeKey));
      await tester.pump();
      await tester.tap(cell(block.$1, block.$2));
      await tester.pump();
      expect(bubble, findsNothing);
      await tester.tap(cell(0, 1));
      await tester.pump();
      expect(hintText('나뭇가지, 가지'), findsOneWidget);
    });

    testWidgets('말풍선을 눌러도 그 아래 칸이 골라지지 않는다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      await tester.tapAt(tester.getRect(find.byKey(const ValueKey('hint-text'))).center);
      await tester.pump();
      expect((board(tester).row, board(tester).col), (0, 0));
      expect(hintText('나뭇가지, 가지'), findsOneWidget);
    });

    testWidgets('확대해서 지금 단어가 안 보이는 곳으로 끌어가면 숨고, 돌아오면 다시 보인다', (tester) async {
      await pumpLoggedIn(tester);
      await openSample(tester);
      await tester.tap(find.byKey(ZoomableGrid.zoomButtonKey));
      await tester.pumpAndSettle();
      expect(bubble, findsOneWidget);
      final viewer = tester.getRect(find.byType(InteractiveViewer));
      final from = viewer.bottomRight - const Offset(20, 10);
      await tester.dragFrom(from, const Offset(-600, -600));
      await tester.pumpAndSettle();
      await tester.dragFrom(from, const Offset(-600, -600));
      await tester.pumpAndSettle();
      expect(bubble, findsNothing);
      await tester.tap(find.byKey(ZoomableGrid.zoomButtonKey));
      await tester.pumpAndSettle();
      expect(bubble, findsOneWidget);
    });

    for (final size in const [Size(411, 914), Size(360, 800), Size(360, 640), Size(320, 568)]) {
      testWidgets('어느 단어·힌트에서도 지금 단어를 가리지 않고 격자 자리 안에 있다 (${size.width.toInt()}×${size.height.toInt()})',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpLoggedIn(tester);
        await openSample(tester);
        final area = tester.getRect(find.byType(InteractiveViewer));

        for (var i = 0; i < 24; i++) {
          for (var k = 0; k < 3; k++) {
            final box = tester.getRect(bubble);
            expect(area.contains(box.topLeft) && area.inflate(0.5).contains(box.bottomRight), isTrue, reason: '$box / $area');
            for (final (r, c) in board(tester).currentClue!.cells) {
              expect(box.overlaps(tester.getRect(cell(r, c))), isFalse, reason: '단어 $i 힌트 $k 칸 ($r, $c)');
            }
            final toggle = find.byKey(const ValueKey('hint-toggle'));
            if (toggle.evaluate().isEmpty) break;
            await tester.tap(toggle);
            await tester.pump();
          }
          await tester.tap(find.byKey(const ValueKey('clue-next')));
          await tester.pump();
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('글자 크기를 1.5배로 키워도 넘치지 않는다 (세로 단어·확인 횟수 포함)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpLoggedIn(tester);
      await openSample(tester);
      for (final ch in 'AAAAAA'.split('')) {
        await tester.tap(find.byKey(LetterKeyboard.letterKey(ch)));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('play-check')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 24; i++) {
        await tester.tap(find.byKey(const ValueKey('clue-next')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('말풍선 자리 (BubbleLayout)', () {
    const area = Size(328, 412);
    const bubble = Size(280, 90);

    test('가로 단어는 아래에, 아래에 자리가 없으면 위에', () {
      const top = BubbleLayout(area: area, word: Rect.fromLTWH(2, 44, 144, 36), down: false);
      expect(top.place(bubble).side, BubbleSide.below);
      expect(top.place(bubble).rect.top, 80 + BubbleLayout.tail);

      const bottom = BubbleLayout(area: area, word: Rect.fromLTWH(182, 332, 144, 36), down: false);
      expect(bottom.place(bubble).side, BubbleSide.above);
      expect(bottom.place(bubble).rect.bottom, 332 - BubbleLayout.tail);
    });

    test('세로 단어는 넓은 쪽 옆에', () {
      const left = BubbleLayout(area: area, word: Rect.fromLTWH(2, 44, 36, 200), down: true);
      expect(left.place(const Size(200, 90)).side, BubbleSide.right);
      const right = BubbleLayout(area: area, word: Rect.fromLTWH(290, 44, 36, 200), down: true);
      expect(right.place(Size(right.constraints.maxWidth, 90)).side, BubbleSide.left);
    });

    test('세로 단어의 양옆이 다 좁으면 아래·위에 띄운다', () {
      const narrow = BubbleLayout(area: Size(200, 400), word: Rect.fromLTWH(80, 20, 40, 120), down: true);
      expect(narrow.place(const Size(200, 90)).side, BubbleSide.below);
    });

    test('꼬리는 단어를 가리키되 말풍선의 둥근 모서리에는 달리지 않는다', () {
      const short = BubbleLayout(area: area, word: Rect.fromLTWH(0, 44, 30, 30), down: false);
      final p = short.place(bubble);
      expect(p.tip.dx, greaterThanOrEqualTo(p.rect.left + BubbleLayout.radius));
    });
  });
}
