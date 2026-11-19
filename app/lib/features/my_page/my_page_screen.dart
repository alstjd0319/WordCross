import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../shared/widgets.dart';
import '../auth/auth_providers.dart';

/// Figma v3 5-1 마이페이지. 지금은 계정 정보와 로그아웃만 있다.
/// 고양이 도감, 학습 통계, 난이도별 현황, 알림, 출처, 계정 삭제는 5주차에 더한다.
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final user = ref.watch(currentUserProvider).value;
    final name = user?.displayName ?? user?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text('마이페이지', style: text.titleLarge),
            const SizedBox(height: 14),
            V3Card(
              child: Row(
                children: [
                  // 닉네임 첫 글자를 넣은 라벤더 상자
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: v3Box(color: V3Colors.lavender, radius: 12, shadow: false),
                    child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: text.titleLarge),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 닉네임을 크게, 이메일을 작게. 닉네임이 없으면 이메일만.
                        Text(name, style: text.titleMedium, overflow: TextOverflow.ellipsis),
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
            const SizedBox(height: 16),
            V3Card(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: _MenuRow(label: '로그아웃', onTap: () => ref.read(authRepositoryProvider).signOut()),
            ),
            const SizedBox(height: 20),
            const Center(child: CatImage('loaf_cream', height: 44)),
            const SizedBox(height: 6),
            Text(
              '고양이 도감, 학습 통계, 알림 설정, 출처, 계정 삭제는 5주차에 더해요.',
              style: text.bodySmall!.copyWith(color: context.wcColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 카드 안의 한 줄 메뉴: 이름과 오른쪽 화살표 (Figma v3 5-1 "출처 및 라이선스", "로그아웃").
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
              const Icon(Icons.chevron_right, color: V3Colors.cocoa),
            ],
          ),
        ),
      ),
    );
  }
}
