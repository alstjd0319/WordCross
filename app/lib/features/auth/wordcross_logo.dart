import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';

/// 로그인 화면 로고: 가로 WORD와 세로 CROSS가 R에서 만나는 작은 격자.
class WordCrossLogo extends StatelessWidget {
  const WordCrossLogo({super.key, this.cell = 26});

  final double cell;

  // (줄, 칸, 글자, 종류)
  static const _cells = [
    (1, 0, 'W', _Kind.locked),
    (1, 1, 'O', _Kind.locked),
    (1, 2, 'R', _Kind.cross),
    (1, 3, 'D', _Kind.locked),
    (0, 2, 'C', _Kind.word),
    (2, 2, 'O', _Kind.word),
    (3, 2, 'S', _Kind.word),
    (4, 2, 'S', _Kind.word),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'WordCross 로고',
      child: SizedBox(
        width: cell * 4,
        height: cell * 5,
        child: Stack(
          children: [
            for (final (row, col, letter, kind) in _cells)
              Positioned(
                left: col * cell,
                top: row * cell,
                child: Container(
                  width: cell,
                  height: cell,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: switch (kind) {
                      _Kind.locked => AppColors.surface,
                      _Kind.word => AppColors.accentContainer,
                      _Kind.cross => AppColors.accentStrong,
                    },
                    border: Border.all(color: AppColors.outline, width: 0.5),
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: cell * 0.56,
                      fontWeight: FontWeight.w700,
                      color: kind == _Kind.locked ? AppColors.primary : AppColors.text,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _Kind { locked, word, cross }
