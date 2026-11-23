import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../play/puzzle.dart';

/// 난이도 색 (Figma v3 규칙: 민트 = 초급, 버터 = 중급, 라벤더 = 고급).
Color levelColor(PuzzleLevel? level) => switch (level) {
      PuzzleLevel.beginner => V3Colors.mint,
      PuzzleLevel.intermediate => V3Colors.butter,
      PuzzleLevel.advanced => V3Colors.lavender,
      null => V3Colors.paper,
    };

/// Figma v3/LevelBadge: 난이도 색 둥근 네모 안에 난이도 이름.
class LevelBadge extends StatelessWidget {
  const LevelBadge({super.key, required this.level, this.size = 48});

  /// DB 값 (beginner / intermediate / advanced)
  final String level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: v3Box(color: levelColor(PuzzleLevel.parse(level)), radius: size * 0.25, shadow: false),
      child: Text(PuzzleLevel.labelOf(level), style: Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: size * 0.3)),
    );
  }
}
