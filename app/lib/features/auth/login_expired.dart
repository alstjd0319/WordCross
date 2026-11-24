import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'auth_providers.dart';

const loginExpiredMessage = '로그인이 풀렸어요. 다시 로그인해 주세요.';

/// 로그인이 풀렸다고 알리고 기기의 세션을 지운다. 세션이 지워지면 라우터가 로그인 화면으로 보낸다.
Future<void> expireLogin(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authRepositoryProvider);
  // 여러 요청이 함께 실패해도 한 번만 처리한다.
  if (auth.currentUser == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text(loginExpiredMessage)));
  try {
    await auth.signOut();
  } catch (_) {
    // 기기의 세션은 먼저 지워지므로 서버 쪽 로그아웃 실패는 무시한다.
  }
}
