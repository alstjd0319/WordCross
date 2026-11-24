import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:wordcross/app/app.dart';
import 'package:wordcross/features/auth/auth_providers.dart';
import 'package:wordcross/features/auth/auth_repository.dart';
import 'package:wordcross/features/auth/fake_auth_repository.dart';
import 'package:wordcross/features/auth/supabase_auth_repository.dart';

/// 삭제 요청을 세고, 응답을 늦추거나 실패시킨다.
class SlowAuth extends FakeAuthRepository {
  int deletes = 0;
  Completer<void>? gate;
  AuthFailure? failure;

  @override
  Future<void> deleteAccount() async {
    deletes++;
    await gate?.future;
    if (failure case final f?) throw f;
    await super.deleteAccount();
  }
}

Future<SlowAuth> openMyPage(WidgetTester tester) async {
  final auth = SlowAuth();
  addTearDown(auth.dispose);
  await auth.signUp(email: 'user@example.com', password: 'password1', nickname: '태웅');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const WordCrossApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('마이페이지').last);
  await tester.pumpAndSettle();
  return auth;
}

Future<void> openDialog(WidgetTester tester) async {
  await tester.tap(find.text('계정 삭제'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('계정 삭제는 되돌릴 수 없다고 묻고, 취소하면 아무 일도 없다', (tester) async {
    final auth = await openMyPage(tester);
    await openDialog(tester);
    expect(find.text('계정을 삭제할까요?'), findsOneWidget);
    expect(find.textContaining('되돌릴 수 없어요'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(auth.deletes, 0);

    // 바깥을 눌러 닫아도 지우지 않는다.
    await openDialog(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(auth.deletes, 0);
    expect(auth.currentUser, isNotNull);
  });

  testWidgets('삭제하면 로그인 화면으로 가고, 같은 계정으로 다시 로그인할 수 없다', (tester) async {
    final auth = await openMyPage(tester);
    await openDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(auth.deletes, 1);
    expect(find.text('십자말풀이로 익히는 토익 단어'), findsOneWidget);
    expect(find.text('계정을 삭제했어요.'), findsOneWidget);
    await expectLater(auth.signIn(email: 'user@example.com', password: 'password1'), throwsA(isA<AuthFailure>()));
  });

  testWidgets('삭제하는 동안 다시 누르거나 로그아웃할 수 없다', (tester) async {
    final auth = await openMyPage(tester);
    auth.gate = Completer<void>();
    await openDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(find.text('삭제하는 중'), findsOneWidget);
    await tester.tap(find.text('삭제하는 중'));
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(auth.deletes, 1);
    expect(auth.currentUser, isNotNull);
    auth.gate!.complete();
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
  });

  testWidgets('실패하면 오류를 보여 주고 로그인 상태로 남으며, 다시 시도할 수 있다', (tester) async {
    final auth = await openMyPage(tester);
    auth.failure = const AuthFailure('서버에 연결하지 못했어요. 네트워크를 확인해 주세요.');
    await openDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(find.text('서버에 연결하지 못했어요. 네트워크를 확인해 주세요.'), findsOneWidget);
    expect(auth.currentUser, isNotNull);

    auth.failure = null;
    await openDialog(tester);
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
  });

  testWidgets('작은 화면(320×568)에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openMyPage(tester);
    await openDialog(tester);
    expect(tester.takeException(), isNull);
  });

  group('SupabaseAuthRepository.deleteAccount', () {
    sb.GoTrueClient client() => sb.GoTrueClient(url: 'http://localhost', autoRefreshToken: false);
    Future<void> run(Future<void> Function() rpc) => SupabaseAuthRepository(client(), deleteAccountRpc: rpc).deleteAccount();
    Matcher fails(String text) => throwsA(isA<AuthFailure>().having((e) => e.message, 'message', contains(text)));

    test('성공하면 예외 없이 끝난다', () async {
      var calls = 0;
      await run(() async => calls++);
      expect(calls, 1);
    });

    test('오류를 화면 문구로 바꾼다', () async {
      await expectLater(run(() async => throw const sb.PostgrestException(message: 'permission denied', code: '42501')), fails('로그인이 풀렸어요'));
      await expectLater(run(() async => throw const sb.PostgrestException(message: 'not authenticated', code: 'P0001')), fails('로그인이 풀렸어요'));
      await expectLater(run(() async => throw const sb.PostgrestException(message: 'boom', code: 'XX000')), fails('삭제하지 못했어요'));
      await expectLater(run(() async => throw Exception('socket')), fails('서버에 연결하지 못했어요'));
    });
  });
}
