import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/v3_theme.dart';
import '../play_state.dart';
import 'puzzle_grid.dart';

/// 퍼즐 격자의 확대·이동 (설계서 8장 "모바일에서 큰 격자 보여 주기", 3주차).
///
/// - 두 손가락으로 확대·축소, 한 손가락으로 끌어 이동 ([InteractiveViewer]).
/// - 확대한 상태에서 다른 단어를 고르면(칸을 누르거나 이전·다음 단어, Tab) 그 단어가 화면 가운데로 온다.
///   같은 단어 안에서 글자를 넣어 칸이 움직이면, 지금 칸이 화면 밖으로 나갈 때만 따라간다.
/// - 오른쪽 위 버튼: 전체가 보일 때는 "확대"(지금 단어 쪽으로), 확대했을 때는 "전체 보기".
///   두 손가락 확대가 어려운 사람·에뮬레이터를 위해서도 둔다.
/// 두 번 탭해서 되돌리기는 칸 한 번 탭이 늦게 먹히게 만들어서 쓰지 않는다.
class ZoomableGrid extends StatefulWidget {
  const ZoomableGrid({super.key, required this.state, required this.onTapCell});

  final PlayState state;
  final void Function(int row, int col) onTapCell;

  static const zoomButtonKey = ValueKey('grid-zoom');

  @override
  State<ZoomableGrid> createState() => ZoomableGridState();
}

class ZoomableGridState extends State<ZoomableGrid> with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  Animation<Matrix4>? _tween;

  /// 마지막 레이아웃의 화면 크기와 칸 크기. 칸 위치를 계산할 때 쓴다.
  Size _viewport = Size.zero;
  double _cell = 0;

  /// 확대 버튼으로 맞출 칸 크기(논리 픽셀). 손가락으로 누르기 편한 크기.
  static const _comfortableCell = 40.0;

  /// 확대했을 때 칸이 이보다 커지지 않게 한다.
  static const _maxCell = 72.0;

  /// 지금 배율 (1 = 전체 보기). 테스트에서도 읽는다.
  double get scale => _controller.value.getMaxScaleOnAxis();
  bool get isZoomed => scale > 1.01;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_tween != null) _controller.value = _tween!.value;
    });
    // 배율이 1을 넘나들 때 버튼 모양을 바꾼다.
    _controller.addListener(_onTransform);
  }

  bool _wasZoomed = false;
  void _onTransform() {
    if (isZoomed != _wasZoomed) setState(() => _wasZoomed = isZoomed);
  }

  @override
  void didUpdateWidget(ZoomableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.state, now = widget.state;
    if (!isZoomed) return;
    final clueChanged = before.currentClue != now.currentClue;
    final cursorMoved = before.row != now.row || before.col != now.col;
    if (clueChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrent(center: true));
    } else if (cursorMoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrent(center: false));
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  double get _maxScale => _cell <= 0 ? 3 : math.max(1.5, _maxCell / _cell);

  /// 격자 왼쪽 위 (화면 가운데 정렬이라 남는 여백만큼 밀려 있다).
  Offset get _gridOrigin {
    final p = widget.state.puzzle;
    return Offset((_viewport.width - _cell * p.cols) / 2, (_viewport.height - _cell * p.rows) / 2);
  }

  Rect _cellRect(int r, int c) => _gridOrigin + Offset(c * _cell, r * _cell) & Size.square(_cell);

  /// 지금 단어 전체가 들어가는 사각형. 단어가 없으면 지금 칸.
  Rect _wordRect() {
    final s = widget.state;
    final clue = s.currentClue;
    if (clue == null) return _cellRect(s.row, s.col);
    final (r0, c0) = clue.cells.first;
    final (r1, c1) = clue.cells.last;
    return _cellRect(r0, c0).expandToInclude(_cellRect(r1, c1));
  }

  /// 배율 [s]에서 내용 좌표 [focus]가 화면 가운데에 오는 변환. 격자 밖 빈 곳이 보이지 않게 가장자리에서 멈춘다.
  Matrix4 _matrixCentering(Offset focus, double s) {
    final w = _viewport.width, h = _viewport.height;
    final tx = (w / 2 - s * focus.dx).clamp(w - s * w, 0.0);
    final ty = (h / 2 - s * focus.dy).clamp(h - s * h, 0.0);
    return Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
  }

  void _animateTo(Matrix4 target) {
    _tween = Matrix4Tween(begin: _controller.value.clone(), end: target).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim
      ..reset()
      ..forward();
  }

  /// [center]: 단어를 화면 가운데로. 아니면 지금 칸이 화면 밖일 때만 칸 쪽으로 옮긴다.
  void _focusCurrent({required bool center}) {
    if (!mounted || !isZoomed || _cell <= 0) return;
    final s = scale;
    final visible = MatrixUtils.inverseTransformRect(_controller.value, Offset.zero & _viewport);
    final cursor = _cellRect(widget.state.row, widget.state.col);
    if (center) {
      final word = _wordRect();
      // 단어가 화면보다 길면 단어 대신 지금 칸을 가운데로.
      final fits = word.width * s <= _viewport.width && word.height * s <= _viewport.height;
      _animateTo(_matrixCentering(fits ? word.center : cursor.center, s));
    } else if (!visible.contains(cursor.topLeft) || !visible.contains(cursor.bottomRight)) {
      _animateTo(_matrixCentering(cursor.center, s));
    }
  }

  /// 확대 버튼: 지금 단어 쪽으로 손가락 크기만큼 확대. 확대 중이면 전체 보기로.
  void toggleZoom() {
    if (isZoomed) {
      _animateTo(Matrix4.identity());
    } else {
      final target = (_comfortableCell / _cell).clamp(1.5, _maxScale);
      final word = _wordRect();
      final fits = word.width * target <= _viewport.width && word.height * target <= _viewport.height;
      final cursor = _cellRect(widget.state.row, widget.state.col);
      _animateTo(_matrixCentering(fits ? word.center : cursor.center, target));
    }
  }

  @override
  Widget build(BuildContext context) {
    final puzzle = widget.state.puzzle;
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              _viewport = box.biggest;
              _cell = PuzzleGrid.cellSizeFor(_viewport, puzzle.rows, puzzle.cols);
              return ClipRect(
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: _maxScale,
                  // 확대하지 않았을 때 끌어도 격자가 밀리지 않게 한다.
                  panEnabled: isZoomed,
                  onInteractionStart: (_) => _anim.stop(),
                  child: Center(
                    child: SizedBox(
                      width: _cell * puzzle.cols,
                      height: _cell * puzzle.rows,
                      child: PuzzleGrid(state: widget.state, onTapCell: widget.onTapCell),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // 격자 아래 줄: 사용법 안내와 확대/전체 보기 버튼. 버튼이 격자 칸을 가리지 않게 격자 밖에 둔다.
        Row(
          children: [
            const SizedBox(width: 44), // 버튼만큼 왼쪽도 비워 안내 문구를 가운데에 둔다
            Expanded(
              child: Text(
                isZoomed ? '끌어서 이동 · 다른 단어를 고르면 그 단어로 이동' : '두 손가락으로 확대 · 한 번 더 누르면 방향 전환',
                style: V3Text.caption,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),
            _ZoomButton(zoomed: isZoomed, onTap: toggleZoom),
          ],
        ),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.zoomed, required this.onTap});

  final bool zoomed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = zoomed ? '전체 보기' : '확대';
    return Tooltip(
      message: label,
      child: Container(
        key: ZoomableGrid.zoomButtonKey,
        width: 36,
        height: 36,
        decoration: v3Box(radius: 10, borderWidth: 1.8),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Icon(zoomed ? Icons.zoom_out_map : Icons.zoom_in, size: 20, color: V3Colors.cocoa),
          ),
        ),
      ),
    );
  }
}
