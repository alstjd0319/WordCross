import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:wordcross/app/app.dart';
import 'package:wordcross/app/router.dart';
import 'package:wordcross/core/supabase_errors.dart';
import 'package:wordcross/features/auth/auth_providers.dart';
import 'package:wordcross/features/auth/auth_repository.dart';
import 'package:wordcross/features/auth/fake_auth_repository.dart';
import 'package:wordcross/features/auth/login_expired.dart';
import 'package:wordcross/features/play/attempt.dart';
import 'package:wordcross/features/play/attempt_repository.dart';
import 'package:wordcross/features/play/fake_attempt_repository.dart';
import 'package:wordcross/features/play/fake_puzzle_repository.dart';
import 'package:wordcross/features/play/play_providers.dart';
import 'package:wordcross/features/play/puzzle.dart';
import 'package:wordcross/features/play/supabase_puzzle_repository.dart';
import 'package:wordcross/features/puzzles/puzzle_list_screen.dart';

import 'fixtures/test_puzzles.dart';

class CountingAuth extends FakeAuthRepository {
  int signOuts = 0;
  bool signOutThrows = false;
  AuthFailure? deleteFailure;

  @override
  Future<void> signOut() async {
    signOuts++;
    await super.signOut();
    if (signOutThrows) throw Exception('server unreachable');
  }

  @override
  Future<void> deleteAccount() async {
    if (deleteFailure case final f?) throw f;
    await super.deleteAccount();
  }
}

/// 세션이 풀린 서버: [expired]가 true인 동안 모든 요청을 거절한다.
class ExpiringPuzzles extends FakePuzzleRepository {
  ExpiringPuzzles() : super(puzzles: testPuzzles);

  bool expired = false;

  void _check() {
    if (!expired) return;
    throw SupabasePuzzleRepository.failureOf(const PostgrestException(message: 'JWT expired', code: 'PGRST303'), '연결');
  }

  @override
  Future<List<PuzzleSummary>> listPuzzles() async {
    _check();
    return super.listPuzzles();
  }

  @override
  Future<PuzzleData> fetchPuzzle(String puzzleId) async {
    _check();
    return super.fetchPuzzle(puzzleId);
  }
}

class ExpiringAttempts extends FakeAttemptRepository {
  ExpiringAttempts() : super(FakePuzzleRepository(puzzles: testPuzzles), isCorrect: testIsCorrect);

  bool expired = false;

  @override
  Future<AttemptStart> start(String puzzleId) async {
    if (expired) throw AttemptFailure(AttemptError.notAuthenticated);
    return super.start(puzzleId);
  }
}

typedef Env = ({CountingAuth auth, ExpiringPuzzles puzzles, ExpiringAttempts attempts});

Future<Env> pump(WidgetTester tester) async {
  final env = (auth: CountingAuth(), puzzles: ExpiringPuzzles(), attempts: ExpiringAttempts());
  addTearDown(env.auth.dispose);
  await env.auth.signUp(email: 'user@example.com', password: 'password1', nickname: '태웅');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(env.auth),
        puzzleRepositoryProvider.overrideWithValue(env.puzzles),
        attemptRepositoryProvider.overrideWithValue(env.attempts),
      ],
      child: const WordCrossApp(),
    ),
  );
  await tester.pumpAndSettle();
  return env;
}

Future<void> go(WidgetTester tester, String path) async {
  ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

void expectLoginScreen(Env env) {
  expect(find.text('십자말풀이로 익히는 토익 단어'), findsOneWidget);
  expect(find.text(loginExpiredMessage), findsOneWidget);
  expect(env.auth.currentUser, isNull);
  expect(env.auth.signOuts, 1);
}

void main() {
  test('서버가 로그인 때문에 거절한 오류만 골라낸다', () {
    for (final code in ['42501', 'PGRST301', 'PGRST303']) {
      expect(isLoginExpired(PostgrestException(message: 'x', code: code)), isTrue, reason: code);
    }
    expect(isLoginExpired(const PostgrestException(message: 'not_authenticated', code: 'P0001')), isTrue);
    expect(isLoginExpired(const PostgrestException(message: 'not authenticated', code: 'P0001')), isTrue);
    expect(isLoginExpired(const PostgrestException(message: 'puzzle_not_found', code: 'P0001')), isFalse);
    expect(isLoginExpired(Exception('socket')), isFalse);

    final denied = SupabasePuzzleRepository.failureOf(const PostgrestException(message: 'x', code: '42501'), '연결');
    expect((denied.loginExpired, denied.message), (true, loginExpiredMessage));
    final network = SupabasePuzzleRepository.failureOf(Exception('socket'), '연결');
    expect((network.loginExpired, network.message), (false, '연결'));
  });

  testWidgets('퍼즐 목록을 열 때 로그인이 풀려 있으면 로그인 화면으로 간다', (tester) async {
    final env = await pump(tester);
    env.puzzles.expired = true;
    await go(tester, Routes.puzzles);
    expectLoginScreen(env);
  });

  testWidgets('다시 로그인하면 목록에 예전 오류가 남지 않는다', (tester) async {
    final env = await pump(tester);
    env.puzzles.expired = true;
    await go(tester, Routes.puzzles);
    expectLoginScreen(env);

    env.puzzles.expired = false;
    await env.auth.signIn(email: 'user@example.com', password: 'password1');
    await tester.pumpAndSettle();
    await go(tester, Routes.puzzles);
    expect(find.byType(PuzzleCard), findsOneWidget);
    expect(find.text('다시 시도'), findsNothing);
  });

  testWidgets('퍼즐 상세를 열 때', (tester) async {
    final env = await pump(tester);
    env.puzzles.expired = true;
    await go(tester, Routes.puzzleDetailPath('beg-001'));
    expectLoginScreen(env);
  });

  testWidgets('풀이를 시작할 때 (start_attempt not_authenticated)', (tester) async {
    final env = await pump(tester);
    env.attempts.expired = true;
    await go(tester, Routes.playPath('beg-001'));
    expectLoginScreen(env);
  });

  testWidgets('퍼즐과 풀이 요청이 함께 실패해도 한 번만 처리한다', (tester) async {
    final env = await pump(tester);
    env.puzzles.expired = true;
    env.attempts.expired = true;
    await go(tester, Routes.playPath('beg-001'));
    expectLoginScreen(env);
  });

  testWidgets('서버 쪽 로그아웃이 실패해도 로그인 화면으로 간다', (tester) async {
    final env = await pump(tester);
    env.auth.signOutThrows = true;
    env.attempts.expired = true;
    await go(tester, Routes.playPath('beg-001'));
    expectLoginScreen(env);
  });

  testWidgets('계정을 삭제할 때', (tester) async {
    final env = await pump(tester);
    env.auth.deleteFailure = const AuthFailure(loginExpiredMessage, loginExpired: true);
    await go(tester, Routes.myPage);
    await tester.tap(find.text('계정 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expectLoginScreen(env);
  });

  testWidgets('그냥 로그아웃하면 안내를 띄우지 않는다', (tester) async {
    final env = await pump(tester);
    await go(tester, Routes.puzzles);
    await env.auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('십자말풀이로 익히는 토익 단어'), findsOneWidget);
    expect(find.text(loginExpiredMessage), findsNothing);
  });
}
