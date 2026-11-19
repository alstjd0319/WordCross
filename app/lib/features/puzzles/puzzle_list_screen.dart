import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../shared/widgets.dart';

/// 개발용 샘플 퍼즐. 로컬 모드 샘플과 Supabase 개발용 공개 퍼즐에 모두 있다.
const samplePuzzleId = 'beg-001';

/// Figma 2-2 퍼즐 목록. 3주차에 만든다.
/// 그 전까지는 퍼즐 풀이 화면(2주차)을 열어 볼 수 있게 샘플 퍼즐 버튼을 둔다.
class PuzzleListScreen extends StatelessWidget {
  const PuzzleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('퍼즐')),
      body: Column(
        children: [
          const Expanded(
            child: ComingSoon(
              cat: 'loaf_tabby',
              title: '퍼즐 목록',
              description: '난이도별 퍼즐 목록과 상세 화면은\n3주차에 만들어요.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: PrimaryButton(
              onPressed: () => context.push(Routes.playPath(samplePuzzleId)),
              child: const Text('샘플 퍼즐 풀어 보기'),
            ),
          ),
        ],
      ),
    );
  }
}
