import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../../shared/widgets.dart';

/// 로그인 화면 로고 (Figma v3 1-1): 가로 WORD와 세로 CROSS가 R에서 만나는 손그림 격자.
/// R 칸은 버터색, 왼쪽 아래에 앉은 삼색 고양이, S 옆에 웅크린 까만 고양이.
class WordCrossLogo extends StatelessWidget {
  const WordCrossLogo({super.key, this.cell = 30});

  final double cell;

  // (줄, 칸, 글자)
  static const _cells = [
    (1, 0, 'W'),
    (1, 1, 'O'),
    (1, 2, 'R'),
    (1, 3, 'D'),
    (0, 2, 'C'),
    (2, 2, 'O'),
    (3, 2, 'S'),
    (4, 2, 'S'),
  ];

  @override
  Widget build(BuildContext context) {
    final step = cell + 4; // 칸 사이 틈
    return Semantics(
      label: 'WordCross 로고',
      child: SizedBox(
        width: step * 4 + cell * 0.6,
        height: step * 5,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (row, col, letter) in _cells)
              Positioned(
                left: col * step,
                top: row * step,
                child: Container(
                  width: cell,
                  height: cell,
                  alignment: Alignment.center,
                  decoration: v3Box(
                    color: letter == 'R' && row == 1 ? V3Colors.butter : V3Colors.paper,
                    radius: cell * 0.22,
                    borderWidth: 1.8,
                  ),
                  child: Text(letter, style: V3Text.word(cell * 0.5)),
                ),
              ),
            // 왼쪽 아래 빈 자리(W·O 아래)에 앉은 고양이. 오른쪽 끝이 세로줄(CROSS)에 닿지 않게 둔다.
            // 그림 비율 80×92 → 폭 = 높이 × 0.87
            Positioned(
              left: step * 2 - step * 1.9 * 0.87 - 6,
              top: step * 5 - 4 - step * 1.9,
              child: CatImage('sit_calico', height: step * 1.9),
            ),
            // 마지막 S 옆에 웅크린 고양이
            Positioned(left: step * 3 - 2, top: step * 4 + cell * 0.1, child: CatImage('curl_black', height: cell * 0.85)),
          ],
        ),
      ),
    );
  }
}
