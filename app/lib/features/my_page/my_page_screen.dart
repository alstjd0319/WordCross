import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../auth/auth_providers.dart';

/// Figma 5-1 마이페이지. 1주차에는 계정 정보와 로그아웃만 있다.
/// 학습 통계, 알림 설정, 출처, 계정 삭제는 5주차에 더한다.
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Icons.person_outline, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Figma 5-1: 닉네임을 크게, 이메일을 작게. 닉네임이 없으면 이메일만.
                      Text(user?.displayName ?? user?.email ?? '', style: text.titleMedium, overflow: TextOverflow.ellipsis),
                      if (user?.displayName != null)
                        Text(
                          user!.email,
                          style: text.bodySmall!.copyWith(color: context.wcColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('로그아웃'),
          ),
          const SizedBox(height: 12),
          Text(
            '학습 통계, 알림 설정, 출처, 계정 삭제는 5주차에 더해요.',
            style: text.bodySmall!.copyWith(color: context.wcColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
