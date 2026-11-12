import 'package:material_ui/material_ui.dart';

import '../../shared/widgets.dart';

/// Figma 2-2 퍼즐 목록. 3주차에 만든다.
class PuzzleListScreen extends StatelessWidget {
  const PuzzleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('퍼즐')),
      body: const ComingSoon(
        icon: Icons.grid_on,
        title: '퍼즐 목록',
        description: '난이도별 퍼즐 목록과 상세 화면은\n3주차에 만들어요.',
      ),
    );
  }
}
