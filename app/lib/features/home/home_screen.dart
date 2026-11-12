import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../shared/widgets.dart';

/// Figma 2-1 홈. 오늘의 퍼즐·연속 학습 일수·최근 기록은 4주차에 채운다.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('안녕하세요', style: text.labelLarge!.copyWith(color: context.wcColors.textMuted)),
              const SizedBox(height: 4),
              Text('오늘도 한 판 풀어 볼까요?', style: text.titleLarge),
              const Expanded(
                child: ComingSoon(
                  icon: Icons.today_outlined,
                  title: '오늘의 퍼즐',
                  description: '오늘의 퍼즐, 난이도별 시작, 연속 학습 일수가\n4주차에 이곳에 들어가요.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
