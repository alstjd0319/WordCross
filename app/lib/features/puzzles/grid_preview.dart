import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../app/theme.dart';
import '../play/puzzle.dart';

/// 퍼즐 상세의 격자 미리보기 (Figma v3 2-3): 검은 칸 배치만 작게 보여 준다. 번호·힌트는 없다.
/// 15×15 격자도 위젯 225개 대신 한 번에 그리도록 CustomPainter를 쓴다.
class GridPreview extends StatelessWidget {
  const GridPreview({super.key, required this.puzzle});

  final PuzzleData puzzle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${puzzle.rows}×${puzzle.cols} 격자 미리보기',
      child: AspectRatio(
        aspectRatio: puzzle.cols / puzzle.rows,
        child: CustomPaint(painter: _GridPainter(puzzle)),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.puzzle);

  final PuzzleData puzzle;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width / puzzle.cols, size.height / puzzle.rows);
    final gap = math.max(1.0, cell * 0.08);
    final radius = Radius.circular(cell * 0.2);
    final white = Paint()..color = V3Colors.paper;
    final block = Paint()..color = V3Colors.chocolate;
    final line = Paint()
      ..color = V3Colors.cocoa
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, cell * 0.06);
    for (var r = 0; r < puzzle.rows; r++) {
      for (var c = 0; c < puzzle.cols; c++) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(c * cell + gap / 2, r * cell + gap / 2, cell - gap, cell - gap),
          radius,
        );
        if (puzzle.isBlock(r, c)) {
          canvas.drawRRect(rect, block);
        } else {
          canvas.drawRRect(rect, white);
          canvas.drawRRect(rect, line);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.puzzle != puzzle;
}
