import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/v3_theme.dart';
import '../play_state.dart';

/// 퍼즐 격자 (Figma v3 GridCell).
///
/// 칸 상태: 흰 칸, 검은 칸(초콜릿), 지금 단어(살구), 지금 칸(버터).
/// 맞힘(민트)·글자 힌트(라벤더)는 정답 확인이 생기는 3·4주차에 더한다.
/// 주어진 공간에 격자 전체가 들어가게 칸 크기를 정한다. 두 손가락 확대·이동은 3주차.
class PuzzleGrid extends StatelessWidget {
  const PuzzleGrid({super.key, required this.state, required this.onTapCell});

  final PlayState state;
  final void Function(int row, int col) onTapCell;

  static Key cellKey(int row, int col) => ValueKey('cell-$row-$col');

  @override
  Widget build(BuildContext context) {
    final puzzle = state.puzzle;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = math.min(box.maxWidth / puzzle.cols, box.maxHeight / puzzle.rows).floorToDouble();
        return SizedBox(
          width: cell * puzzle.cols,
          height: cell * puzzle.rows,
          child: Column(
            children: [
              for (var r = 0; r < puzzle.rows; r++)
                Row(
                  children: [
                    for (var c = 0; c < puzzle.cols; c++) SizedBox.square(dimension: cell, child: _cell(r, c, cell)),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(int r, int c, double size) {
    final gap = math.max(1.0, size * 0.06);
    final radius = size * 0.2;
    final puzzle = state.puzzle;
    if (puzzle.isBlock(r, c)) {
      return Padding(
        key: cellKey(r, c),
        padding: EdgeInsets.all(gap),
        child: DecoratedBox(
          decoration: BoxDecoration(color: V3Colors.chocolate, borderRadius: BorderRadius.circular(radius)),
        ),
      );
    }

    final cursor = state.isCursor(r, c);
    final inWord = state.inCurrentWord(r, c);
    final color = cursor ? V3Colors.butter : (inWord ? V3Colors.apricot : V3Colors.paper);
    final number = puzzle.numberAt(r, c);
    final letter = state.letterAt(r, c);

    return Semantics(
      button: true,
      selected: cursor,
      label: '${r + 1}행 ${c + 1}열${letter == null ? ' 빈칸' : ' $letter'}',
      child: GestureDetector(
        key: cellKey(r, c),
        behavior: HitTestBehavior.opaque,
        onTap: () => onTapCell(r, c),
        child: Padding(
          padding: EdgeInsets.all(gap),
          child: DecoratedBox(
            decoration: v3Box(
              color: color,
              radius: radius,
              borderWidth: cursor ? 2 : 1.5,
              shadow: false,
            ),
            child: Stack(
              children: [
                if (number != null)
                  Positioned(
                    left: size * 0.1,
                    top: size * 0.07,
                    child: Text('$number', style: V3Text.word(size * 0.22, weight: FontWeight.w500)),
                  ),
                if (letter != null)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: size * 0.08),
                      child: Text(letter, style: V3Text.word(size * 0.48)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
