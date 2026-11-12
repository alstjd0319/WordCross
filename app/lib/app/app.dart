import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/auth_repository.dart';
import 'router.dart';
import 'theme.dart';

class WordCrossApp extends ConsumerStatefulWidget {
  const WordCrossApp({super.key});

  @override
  ConsumerState<WordCrossApp> createState() => _WordCrossAppState();
}

class _WordCrossAppState extends ConsumerState<WordCrossApp> {
  /// 화면이 바뀌어도(로그인 → 홈) 안내 문구가 이어서 보이도록 앱 전체에 하나 둔다.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<AuthNotice>? _notices;

  static const emailConfirmedMessage = '이메일 인증이 완료됐어요. 환영해요!';
  static const confirmLinkFailedMessage = '인증 링크가 만료됐거나 이미 사용됐어요. 로그인해 보시고, 안 되면 다시 가입해 주세요.';

  @override
  void initState() {
    super.initState();
    _notices = ref.read(authRepositoryProvider).notices().listen(_showNotice);
  }

  @override
  void dispose() {
    _notices?.cancel();
    super.dispose();
  }

  void _showNotice(AuthNotice notice) {
    // 이미 로그인한 상태에서 예전 인증 링크를 다시 누른 경우는 알릴 필요가 없다.
    if (notice == AuthNotice.confirmLinkFailed && ref.read(authRepositoryProvider).currentUser != null) return;
    final message = switch (notice) {
      AuthNotice.emailConfirmed => emailConfirmedMessage,
      AuthNotice.confirmLinkFailed => confirmLinkFailedMessage,
    };
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    final localMode = ref.watch(localModeProvider);
    return MaterialApp.router(
      title: 'WordCross',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        if (!localMode) return child!;
        // Supabase 없이 실행 중임을 화면 모서리에 표시한다.
        return Banner(
          message: '로컬 모드',
          location: BannerLocation.topEnd,
          color: AppColors.accent,
          child: child!,
        );
      },
    );
  }
}
