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
import 'package:wordcross/features/play/fake_puzzle_repository.dart';
import 'package:wordcross/features/play/play_providers.dart';
import 'package:wordcross/features/play/play_screen.dart';
import 'package:wordcross/features/play/widgets/hint_bar.dart';
import 'package:wordcross/features/play/widgets/letter_keyboard.dart';
import 'package:wordcross/features/play/widgets/puzzle_grid.dart';
import 'package:wordcross/features/play/widgets/zoomable_grid.dart';
import 'package:wordcross/features/puzzles/puzzle_list_screen.dart';

import 'fixtures/test_puzzles.dart';

/// 로그인한 상태로 앱을 띄운다.
Future<GoRouter> pumpLoggedIn(WidgetTester tester) async {
  final auth = FakeAuthRepository();
  addTearDown(auth.dispose);
  await auth.signUp(email: 'user@example.com', password: 'password1', nickname: '태웅');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        puzzleRepositoryProvider.overrideWithValue(FakePuzzleRepository(puzzles: testPuzzles)),
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

Future<void> openSample(WidgetTester tester) async {
  await tester.tap(find.text('퍼즐').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('초급 #001'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('시작하기'));
  await tester.pumpAndSettle();
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

  testWidgets('6글자를 다 채우면 채운 단어 수가 올라간다', (tester) async {
    await pumpLoggedIn(tester);
    await openSample(tester);

    for (final ch in 'BRANCH'.split('')) {
      await tester.tap(find.byKey(LetterKeyboard.letterKey(ch)));
      await tester.pump();
    }
    expect(find.text('1 / 24 단어'), findsOneWidget);
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
    Finder badge(String no) => find.descendant(of: find.byType(HintBar), matching: find.text(no));
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
}
