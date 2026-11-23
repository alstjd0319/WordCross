import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wordcross/app/app.dart';
import 'package:wordcross/app/main_shell.dart';
import 'package:wordcross/features/auth/auth_providers.dart';
import 'package:wordcross/features/auth/fake_auth_repository.dart';
import 'package:wordcross/features/play/fake_puzzle_repository.dart';
import 'package:wordcross/features/play/play_providers.dart';
import 'package:wordcross/features/play/puzzle.dart';
import 'package:wordcross/features/play/puzzle_repository.dart';
import 'package:wordcross/features/puzzles/puzzle_list_screen.dart';

/// 로그인한 상태로 퍼즐 탭을 연다.
Future<void> openPuzzleTab(WidgetTester tester, PuzzleRepository puzzles) async {
  final auth = FakeAuthRepository();
  addTearDown(auth.dispose);
  await auth.signUp(email: 'user@example.com', password: 'password1', nickname: '태웅');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        puzzleRepositoryProvider.overrideWithValue(puzzles),
      ],
      child: const WordCrossApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('퍼즐').last);
  await tester.pumpAndSettle();
}

Finder chip(String label) => find.descendant(of: find.byType(SingleChildScrollView), matching: find.text(label));

/// 실패하는 저장소: 오류 화면과 다시 시도를 확인한다.
class _FailingRepository implements PuzzleRepository {
  int calls = 0;

  @override
  Future<List<PuzzleSummary>> listPuzzles() async {
    calls++;
    throw const PuzzleFailure('퍼즐 목록을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.');
  }

  @override
  Future<PuzzleData> fetchPuzzle(String puzzleId) => throw UnimplementedError();
}

void main() {
  group('PuzzleLevel·PuzzleSummary', () {
    test('예상 시간은 난이도별 단어당 시간으로 어림한다 (Figma v3 2-2 예시와 같게)', () {
      expect(PuzzleLevel.beginner.estimatedMinutes(18), 6);
      expect(PuzzleLevel.intermediate.estimatedMinutes(28), 12);
      expect(PuzzleLevel.advanced.estimatedMinutes(32), 20);
      expect(PuzzleLevel.beginner.estimatedMinutes(0), 1);
    });

    test('목록은 초급 → 중급 → 고급, 같은 난이도는 id 순', () {
      PuzzleSummary p(String id, String level) => PuzzleSummary(id: id, level: level, rows: 9, cols: 9, wordCount: 10);
      final list = [p('adv-001', 'advanced'), p('beg-002', 'beginner'), p('mid-001', 'intermediate'), p('beg-001', 'beginner')]
        ..sort(PuzzleSummary.compare);
      expect(list.map((e) => e.id), ['beg-001', 'beg-002', 'mid-001', 'adv-001']);
      expect(list.first.title, '초급 #001');
      expect(list.first.sizeLabel, '9×9');
    });

    test('puzzles 테이블 행을 읽는다', () {
      final s = PuzzleSummary.fromJson({'id': 'mid-012', 'level': 'intermediate', 'rows': 13, 'cols': 13, 'word_count': 28});
      expect(s.title, '중급 #012');
      expect(s.wordCount, 28);
      expect(s.estimatedMinutes, 12);
    });
  });

  testWidgets('샘플 퍼즐이 난이도 순으로 카드로 나오고, 필터로 거른다', (tester) async {
    await openPuzzleTab(tester, FakePuzzleRepository());

    expect(find.byType(MainNavBar), findsOneWidget);
    expect(find.text('초급 #001'), findsOneWidget);
    expect(find.text('중급 #001'), findsOneWidget);
    // 고급 카드는 화면 아래쪽이라 스크롤해서 확인한다.
    await tester.scrollUntilVisible(find.text('고급 #002'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('고급 #002'), findsOneWidget);

    await tester.tap(chip('중급'));
    await tester.pumpAndSettle();
    expect(find.byType(PuzzleCard), findsNWidgets(2));
    expect(find.text('초급 #001'), findsNothing);
    expect(find.text('중급 #002'), findsOneWidget);

    await tester.tap(chip('전체'));
    await tester.pumpAndSettle();
    expect(find.text('초급 #001'), findsOneWidget);
  });

  testWidgets('카드에 크기·단어 수·예상 시간이 나오고, 누르면 퍼즐 풀이가 열린다', (tester) async {
    final repo = FakePuzzleRepository();
    await openPuzzleTab(tester, repo);
    final first = (await repo.listPuzzles()).first;
    final minutes = first.estimatedMinutes;

    expect(find.text('${first.sizeLabel} · 단어 ${first.wordCount}개 · 약 $minutes분'), findsOneWidget);

    await tester.tap(find.text(first.title));
    await tester.pumpAndSettle();
    expect(find.byType(MainNavBar), findsNothing);
    expect(find.text('0 / ${first.wordCount} 단어'), findsOneWidget);
  });

  testWidgets('공개된 퍼즐이 없으면 안내를 보여 준다', (tester) async {
    await openPuzzleTab(tester, FakePuzzleRepository(puzzles: const {}));
    expect(find.text('아직 공개된 퍼즐이 없어요'), findsOneWidget);
  });

  testWidgets('불러오지 못하면 오류와 다시 시도 버튼을 보여 준다', (tester) async {
    final repo = _FailingRepository();
    await openPuzzleTab(tester, repo);
    expect(find.text('퍼즐 목록을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
  });
}
