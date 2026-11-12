import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/auth_providers.dart';
import 'router.dart';
import 'theme.dart';

class WordCrossApp extends ConsumerWidget {
  const WordCrossApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localMode = ref.watch(localModeProvider);
    return MaterialApp.router(
      title: 'WordCross',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
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
