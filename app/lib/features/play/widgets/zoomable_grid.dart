import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../play_session.dart';
import '../play_state.dart';
import 'hint_bubble.dart';
import 'puzzle_grid.dart';

/// 퍼즐 격자의 확대·이동 (설계서 8장 "모바일에서 큰 격자 보여 주기", 3주차).
///
/// - 두 손가락으로 확대·축소, 한 손가락으로 끌어 이동 ([InteractiveViewer]).
/// - 확대한 상태에서 다른 단어를 고르면(칸을 누르거나 이전·다음 단어, Tab) 그 단어가 화면 가운데로 온다.
///   같은 단어 안에서 글자를 넣어 칸이 움직이면, 지금 칸이 화면 밖으로 나갈 때만 따라간다.
/// - 오른쪽 위 버튼: 전체가 보일 때는 "확대"(지금 단어 쪽으로), 확대했을 때는 "전체 보기".
///   두 손가락 확대가 어려운 사람·에뮬레이터를 위해서도 둔다.
/// 두 번 탭해서 되돌리기는 칸 한 번 탭이 늦게 먹히게 만들어서 쓰지 않는다.
///
/// 지금 단어의 힌트는 격자 위에 말풍선([HintBubble])으로 겹쳐 띄운다. ✕로 닫으면 격자 전체가 보이고,
/// 칸을 누르거나 다른 단어로 옮기면 다시 뜬다. 글자를 넣는 동안에는 열림·닫힘이 그대로다.
class ZoomableGrid extends StatefulWidget {
  const ZoomableGrid({
    super.key,
    required this.state,
    required this.onTapCell,
    required this.onCycleHint,
    required this.onPrevious,
    required this.onNext,
    this.notice,
    this.onRetry,
  });

  final PlayState state;
  final void Function(int row, int col) onTapCell;
  final VoidCallback onCycleHint;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// 있으면 격자 아래 사용법 안내 대신 보여 준다 (확인 결과, 연결 실패 등).
  final PlayNotice? notice;
  final VoidCallback? onRetry;

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

  /// 격자 아래 줄의 높이. 이전·다음 단어 버튼, 안내 두 줄, 확대 버튼이 들어간다.
  static const _captionHeight = 40.0;

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
    final clueChanged = before.currentClue != now.currentClue;
    if (clueChanged) _bubbleOpen = true;
    if (!isZoomed) return;
    final cursorMoved = before.row != now.row || before.col != now.col;
    if (clueChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrent(center: true));
    } else if (cursorMoved) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusCurrent(center: false));
    }
  }

  /// 힌트 말풍선이 떠 있는지. 화면을 열면 첫 단어의 힌트가 바로 보인다.
  bool _bubbleOpen = true;

  void _openBubble() {
    if (!_bubbleOpen) setState(() => _bubbleOpen = true);
  }

  /// 말풍선을 닫은 채 지금 칸을 누르면 방향은 그대로 두고 말풍선만 다시 띄운다.
  void _tapCell(int r, int c) {
    if (widget.state.puzzle.isBlock(r, c)) return;
    final reopenOnly = !_bubbleOpen && widget.state.isCursor(r, c);
    _openBubble();
    if (!reopenOnly) widget.onTapCell(r, c);
  }

  /// 지금 단어에서 화면에 보이는 부분. 확대해서 다른 곳으로 끌어가 보이지 않으면 null.
  Rect? _visibleWord() {
    final word = MatrixUtils.transformRect(_controller.value, _wordRect()).intersect(Offset.zero & _viewport);
    return word.width < 1 || word.height < 1 ? null : word;
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
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(
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
                          child: PuzzleGrid(state: widget.state, onTapCell: _tapCell),
                        ),
                      ),
                    ),
                  ),
                  // 확대·이동하는 동안에도 말풍선이 단어를 따라간다.
                  if (_bubbleOpen && widget.state.currentClue != null)
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final word = _visibleWord();
                        if (word == null) return const SizedBox.shrink();
                        return HintBubble(
                          state: widget.state,
                          word: word,
                          onCycleHint: widget.onCycleHint,
                          onClose: () => setState(() => _bubbleOpen = false),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        // 격자 아래 줄: 이전·다음 단어, 사용법 안내, 확대/전체 보기. 버튼이 격자 칸을 가리지 않게 격자 밖에 둔다.
        // 안내가 길거나 다시 시도 버튼이 나와도 격자 크기가 바뀌지 않게 높이를 고정한다.
        SizedBox(
          height: _captionHeight,
          child: Row(
            children: [
              // 말풍선과 달리 늘 같은 자리라 연달아 누르기 쉽다.
              _RowButton(
                key: const ValueKey('clue-prev'),
                tooltip: '이전 단어',
                icon: Icons.chevron_left,
                onTap: () {
                  _openBubble();
                  widget.onPrevious();
                },
              ),
              const SizedBox(width: 6),
              _RowButton(
                key: const ValueKey('clue-next'),
                tooltip: '다음 단어',
                icon: Icons.chevron_right,
                onTap: () {
                  _openBubble();
                  widget.onNext();
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Caption(
                  notice: widget.notice,
                  usage: isZoomed ? '끌어서 이동\n다른 단어를 고르면 그 단어로' : '두 손가락으로 확대\n한 번 더 누르면 방향 전환',
                ),
              ),
              if (widget.notice?.canRetry ?? false)
                TextButton(
                  onPressed: widget.onRetry,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('다시 시도'),
                ),
              const SizedBox(width: 8),
              _RowButton(
                key: ZoomableGrid.zoomButtonKey,
                width: 36,
                iconSize: 20,
                tooltip: isZoomed ? '전체 보기' : '확대',
                icon: isZoomed ? Icons.zoom_out_map : Icons.zoom_in,
                onTap: toggleZoom,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 격자 아래 한 줄: 평소에는 사용법, 안내가 있으면 안내.
class _Caption extends StatelessWidget {
  const _Caption({required this.notice, required this.usage});

  final PlayNotice? notice;
  final String usage;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    if (n == null) return _fit(Text(usage, style: V3Text.caption, textAlign: TextAlign.center));
    final color = switch (n.tone) {
      NoticeTone.info => V3Colors.cocoa,
      NoticeTone.success => AppColors.success,
      NoticeTone.error => AppColors.error,
    };
    return Semantics(
      liveRegion: true,
      child: _fit(
        Text(
          n.text,
          key: const ValueKey('play-notice'),
          style: V3Text.caption.copyWith(color: color, fontSize: 14, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// 주어진 폭에서 줄을 바꾸고, 그래도 높이를 넘으면 조금 줄인다.
  static Widget _fit(Widget text) => LayoutBuilder(
        builder: (context, box) => FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth), child: text),
        ),
      );
}

/// 격자 아래 줄의 네모 버튼.
class _RowButton extends StatelessWidget {
  const _RowButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.width = 44,
    this.iconSize = 24,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final double width;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: width,
        height: 36,
        decoration: v3Box(radius: 10, borderWidth: 1.8),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Icon(icon, size: iconSize, color: V3Colors.cocoa),
          ),
        ),
      ),
    );
  }
}
