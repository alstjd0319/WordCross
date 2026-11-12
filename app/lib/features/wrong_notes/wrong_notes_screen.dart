import 'package:material_ui/material_ui.dart';

import '../../shared/widgets.dart';

/// Figma 4-1 오답 노트. 4주차에 만든다.
class WrongNotesScreen extends StatelessWidget {
  const WrongNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('오답 노트')),
      body: const ComingSoon(
        icon: Icons.menu_book_outlined,
        title: '오답 노트',
        description: '틀린 단어와 복습 카드는\n4~5주차에 만들어요.',
      ),
    );
  }
}
