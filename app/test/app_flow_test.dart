import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wordcross/app/app.dart';
import 'package:wordcross/app/router.dart';
import 'package:wordcross/features/auth/auth_providers.dart';
import 'package:wordcross/features/auth/fake_auth_repository.dart';

Future<FakeAuthRepository> pumpApp(WidgetTester tester) async {
  final auth = FakeAuthRepository();
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const WordCrossApp(),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

Finder field(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextFormField),
    );

void main() {
  testWidgets('로그인하지 않으면 로그인 화면이 먼저 나온다', (tester) async {
    await pumpApp(tester);
    expect(find.text('십자말풀이로 익히는 토익 단어'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('회원가입하면 홈과 하단 메뉴가 나오고, 탭 이동과 로그아웃이 된다', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();
    expect(find.text('이메일로 가입하기'), findsOneWidget);

    await tester.enterText(field('닉네임'), '민성');
    await tester.enterText(field('이메일'), 'user@example.com');
    await tester.enterText(field('비밀번호'), 'password1');
    await tester.enterText(field('비밀번호 확인'), 'password1');
    await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
    await tester.pumpAndSettle();

    expect(find.text('오늘도 한 판 풀어 볼까요?'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.text('퍼즐').last);
    await tester.pumpAndSettle();
    expect(find.text('퍼즐 목록'), findsOneWidget);

    await tester.tap(find.text('마이페이지').last);
    await tester.pumpAndSettle();
    expect(find.text('user@example.com'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '로그아웃'));
    await tester.pumpAndSettle();
    expect(find.text('십자말풀이로 익히는 토익 단어'), findsOneWidget);
  });

  testWidgets('회원가입 입력이 잘못되면 오류 문구를 보여 주고 넘어가지 않는다', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('회원가입'));
    await tester.pumpAndSettle();

    await tester.enterText(field('이메일'), 'wrong-email');
    await tester.enterText(field('비밀번호'), 'short');
    await tester.enterText(field('비밀번호 확인'), 'different');
    await tester.tap(find.widgetWithText(FilledButton, '가입하기'));
    await tester.pumpAndSettle();

    expect(find.text('이메일 형식이 맞지 않아요.'), findsOneWidget);
    expect(find.text('닉네임을 입력해 주세요.'), findsOneWidget);
    expect(find.text('비밀번호는 8자 이상이어야 해요.'), findsOneWidget);
    expect(find.text('비밀번호가 서로 달라요.'), findsOneWidget);
    expect(find.text('이메일로 가입하기'), findsOneWidget);
  });

  testWidgets('비밀번호가 틀리면 로그인 화면에 오류를 보여 준다', (tester) async {
    final auth = await pumpApp(tester);
    await auth.signUp(email: 'user@example.com', password: 'password1', nickname: '민성');
    await auth.signOut();
    await tester.pumpAndSettle();

    await tester.enterText(field('이메일'), 'user@example.com');
    await tester.enterText(field('비밀번호'), 'wrong-pass');
    await tester.tap(find.widgetWithText(FilledButton, '로그인'));
    await tester.pumpAndSettle();

    expect(find.text('이메일 또는 비밀번호가 맞지 않아요.'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('인증 메일 링크로 열리면 Page Not Found 없이 로그인 화면으로 간다', (tester) async {
    await pumpApp(tester);
    final router = ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(routerProvider);

    for (final link in ['com.wordcross.wordcross://login-callback/?code=abc', '/login-callback?code=abc']) {
      router.go(link);
      await tester.pumpAndSettle();
      expect(find.text('Page Not Found'), findsNothing, reason: link);
      expect(find.text('십자말풀이로 익히는 토익 단어'), findsOneWidget, reason: link);
    }
  });

  testWidgets('인증 메일 링크로 로그인되면 홈으로 가고 인증 완료 문구를 보여 준다', (tester) async {
    final auth = await pumpApp(tester);
    auth.simulateEmailLink(email: 'user@example.com');
    await tester.pumpAndSettle();

    expect(find.text('이메일 인증이 완료됐어요. 환영해요!'), findsOneWidget);
    expect(find.text('오늘도 한 판 풀어 볼까요?'), findsOneWidget);
  });

  testWidgets('인증 링크가 만료됐으면 로그인 화면에 안내 문구를 보여 준다', (tester) async {
    final auth = await pumpApp(tester);
    auth.simulateEmailLink(email: 'user@example.com', success: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('인증 링크가 만료됐거나'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('이미 로그인한 상태에서 예전 인증 링크를 누르면 만료 문구를 띄우지 않는다', (tester) async {
    final auth = await pumpApp(tester);
    await auth.signUp(email: 'user@example.com', password: 'password1', nickname: '민성');
    await tester.pumpAndSettle();
    auth.simulateEmailLink(email: 'user@example.com', success: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('인증 링크가 만료됐거나'), findsNothing);
    expect(find.text('오늘도 한 판 풀어 볼까요?'), findsOneWidget);
  });
}
