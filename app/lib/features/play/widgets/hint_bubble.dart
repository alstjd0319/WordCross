import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/v3_theme.dart';
import '../play_state.dart';
import '../puzzle.dart';

/// 격자 위에 겹쳐 뜨는 힌트 말풍선 (교수님 제안, Figma "힌트 말풍선 시안" B안).
///
/// 단어 번호·방향, 글자 수·힌트 종류, 힌트, 힌트 전환(한국어 뜻 → 영어 정의 → 예문 빈칸), 닫기(✕).
/// 이전·다음 단어 버튼은 자리가 움직이면 연달아 누르기 어려워 격자 아래 줄에 둔다.
///
/// 격자와 같은 크기의 자리를 차지하지만 말풍선만 터치를 받는다. 겹쳐 뜨므로 힌트 길이가 달라도
/// 격자 크기는 바뀌지 않는다. 위치는 [BubbleLayout]이 정하고, 지금 단어의 칸은 되도록 가리지 않는다.
class HintBubble extends StatelessWidget {
  const HintBubble({
    super.key,
    required this.state,
    required this.word,
    required this.onCycleHint,
    required this.onClose,
  });

  final PlayState state;

  /// 지금 단어에서 화면에 보이는 부분 (격자 자리 기준 좌표).
  final Rect word;
  final VoidCallback onCycleHint;
  final VoidCallback onClose;

  static const bodyKey = ValueKey('hint-bubble');
  static const closeKey = ValueKey('hint-close');

  /// 이보다 좁으면(세로 단어 옆) 글자 수 줄과 전환 버튼을 따로 한 줄씩 쓴다.
  static const _narrowWidth = 220.0;

  /// 맞힌 단어는 점수, 틀린 적이 있는 단어는 남은 확인 횟수.
  String? _status(Clue clue) {
    final p = state.progressOf(clue);
    if (p.solved) return '맞힘 ${p.score}점';
    if (p.tries > 0) return '확인 ${p.triesLeft}번 남음';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final clue = state.currentClue;
    if (clue == null) return const SizedBox.shrink();
    final kind = state.shownHintKind;
    final next = state.nextHintKind;
    final caption = Text(
      ['${clue.length}글자', if (kind != null) kind.label, ?_status(clue)].join(' · '),
      style: V3Text.caption,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final hint = (kind == null ? null : clue.hint(kind)) ?? '이 단어는 아직 힌트가 없어요.';
    final toggle = next == null ? null : _ToggleButton(next: next, onTap: onCycleHint);

    return _BubbleBox(
      word: word,
      down: clue.dir == Direction.down,
      // 말풍선을 누를 때 아래 칸이 눌리지 않게 막는다.
      child: GestureDetector(
        key: bodyKey,
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 5, 5, 10),
            child: LayoutBuilder(
              builder: (context, box) {
                final narrow = box.maxWidth < _narrowWidth;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (narrow)
                          Expanded(child: Align(alignment: Alignment.centerLeft, child: _Badge(clue: clue)))
                        else ...[
                          _Badge(clue: clue),
                          const SizedBox(width: 8),
                          Expanded(child: caption),
                        ],
                        _CloseButton(onTap: onClose),
                      ],
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: narrow
                            ? _HintText(hint, leading: caption)
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(child: _HintText(hint)),
                                  if (toggle != null) ...[const SizedBox(width: 8), toggle],
                                ],
                              ),
                      ),
                    ),
                    if (narrow && toggle != null) ...[const SizedBox(height: 4), toggle],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 힌트 전체를 보여 준다. 자리가 모자라면 잘라내지 않고 위아래로 밀어서 읽는다.
class _HintText extends StatefulWidget {
  const _HintText(this.text, {this.leading});

  final String text;

  /// 힌트와 함께 밀리는 윗줄 (폭이 좁을 때의 글자 수 줄).
  final Widget? leading;

  @override
  State<_HintText> createState() => _HintTextState();
}

class _HintTextState extends State<_HintText> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(_HintText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다른 힌트로 바뀌면 처음부터 보여 준다.
    if (oldWidget.text != widget.text && _scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.only(top: 2, right: 6, bottom: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.leading case final leading?) Padding(padding: const EdgeInsets.only(bottom: 2), child: leading),
            Text(
              widget.text,
              key: const ValueKey('hint-text'),
              style: V3Text.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.clue});

  final Clue clue;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: v3Box(color: V3Colors.apricot, radius: 8, borderWidth: 1.5, shadow: false),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('${clue.no} ${clue.dir.label}', style: V3Text.button.copyWith(fontSize: 13)),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({required this.next, required this.onTap});

  final HintKind next;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${next.label} 보기',
      child: Container(
        key: const ValueKey('hint-toggle'),
        width: 66,
        height: 34,
        decoration: v3Box(color: V3Colors.cream, radius: 10, borderWidth: 1.5, shadow: false),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, size: 18, color: V3Colors.cocoa),
                  const SizedBox(width: 3),
                  Text(next.shortLabel, style: V3Text.caption.copyWith(color: V3Colors.cocoa)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '힌트 닫기',
      child: InkResponse(
        key: HintBubble.closeKey,
        onTap: onTap,
        radius: 20,
        child: const SizedBox(width: 40, height: 36, child: Icon(Icons.close, size: 18, color: V3Colors.cocoa)),
      ),
    );
  }
}

enum BubbleSide { below, above, right, left }

/// 말풍선 자리 계산 (화면 없이 단위 테스트한다).
///
/// - 가로 단어: 아래, 자리가 없으면 위.
/// - 세로 단어: 오른쪽, 자리가 없으면 왼쪽. 양옆이 다 좁으면 가로 단어처럼 아래·위.
class BubbleLayout {
  const BubbleLayout({required this.area, required this.word, required this.down});

  /// 격자가 놓인 자리의 크기.
  final Size area;

  /// 지금 단어에서 보이는 부분.
  final Rect word;

  /// 세로 단어인지.
  final bool down;

  static const maxWidth = 280.0;
  static const minSideWidth = 96.0;

  /// 자리가 아무리 좁아도 힌트 한 줄과 버튼은 보이게 한다.
  static const minHeight = 110.0;

  /// 단어 가장자리에서 말풍선까지의 거리(꼬리 길이).
  static const tail = 11.0;
  static const tailHalfWidth = 9.0;
  static const radius = 16.0;

  double get _right => area.width - word.right - tail;
  double get _left => word.left - tail;
  double get _below => area.height - word.bottom - tail;
  double get _above => word.top - tail;
  bool get _beside => down && math.max(_right, _left) >= minSideWidth;

  /// 말풍선에 줄 수 있는 크기. 폭은 힌트 길이와 상관없이 정해진다.
  BoxConstraints get constraints {
    final width = math.min(maxWidth, _beside ? math.max(_right, _left) : area.width);
    final height = _beside ? area.height : math.min(area.height, math.max(minHeight, math.max(_below, _above)));
    return BoxConstraints(minWidth: width, maxWidth: width, maxHeight: height);
  }

  static double _clamp(double v, double lo, double hi) => hi < lo ? lo : v.clamp(lo, hi);

  ({Rect rect, BubbleSide side, Offset tip}) place(Size bubble) {
    const edge = radius + tailHalfWidth;
    if (_beside) {
      final side = _right >= bubble.width ? BubbleSide.right : BubbleSide.left;
      final left = side == BubbleSide.right ? word.right + tail : word.left - tail - bubble.width;
      final rect = Offset(left, _clamp(word.top + 2, 0, area.height - bubble.height)) & bubble;
      final y = _clamp(word.top + word.width / 2, rect.top + edge, rect.bottom - edge);
      return (rect: rect, side: side, tip: Offset(side == BubbleSide.right ? word.right + 1 : word.left - 1, y));
    }
    final below = _below >= bubble.height || (_above < bubble.height && _below >= _above);
    final top = below ? word.bottom + tail : word.top - tail - bubble.height;
    final left = _clamp(word.center.dx - bubble.width / 2, 0, area.width - bubble.width);
    final rect = Offset(left, _clamp(top, 0, area.height - bubble.height)) & bubble;
    final x = _clamp(word.center.dx, rect.left + edge, rect.right - edge);
    return below
        ? (rect: rect, side: BubbleSide.below, tip: Offset(x, word.bottom + 1))
        : (rect: rect, side: BubbleSide.above, tip: Offset(x, word.top - 1));
  }
}

/// 말풍선을 [BubbleLayout] 자리에 놓고 모양(바탕·선·꼬리·그림자)을 그린다.
class _BubbleBox extends SingleChildRenderObjectWidget {
  const _BubbleBox({required this.word, required this.down, required super.child});

  final Rect word;
  final bool down;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBubbleBox(word, down);

  @override
  void updateRenderObject(BuildContext context, _RenderBubbleBox renderObject) => renderObject.update(word, down);
}

class _RenderBubbleBox extends RenderShiftedBox {
  _RenderBubbleBox(this._word, this._down) : super(null);

  Rect _word;
  bool _down;
  ({Rect rect, BubbleSide side, Offset tip})? _placed;

  void update(Rect word, bool down) {
    if (word == _word && down == _down) return;
    _word = word;
    _down = down;
    markNeedsLayout();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) return;
    final layout = BubbleLayout(area: size, word: _word, down: _down);
    child.layout(layout.constraints, parentUsesSize: true);
    final placed = layout.place(child.size);
    _placed = placed;
    (child.parentData! as BoxParentData).offset = placed.rect.topLeft;
  }

  Path _shape(({Rect rect, BubbleSide side, Offset tip}) p) {
    const h = BubbleLayout.tailHalfWidth;
    final r = p.rect.deflate(1), t = p.tip;
    // 꼬리 밑동을 말풍선 안쪽까지 넣어 이음매 선이 생기지 않게 한다.
    final (a, b) = switch (p.side) {
      BubbleSide.below => (Offset(t.dx - h, r.top + 1), Offset(t.dx + h, r.top + 1)),
      BubbleSide.above => (Offset(t.dx - h, r.bottom - 1), Offset(t.dx + h, r.bottom - 1)),
      BubbleSide.right => (Offset(r.left + 1, t.dy - h), Offset(r.left + 1, t.dy + h)),
      BubbleSide.left => (Offset(r.right - 1, t.dy - h), Offset(r.right - 1, t.dy + h)),
    };
    return Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(BubbleLayout.radius))),
      Path()..addPolygon([a, t, b], true),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final placed = _placed;
    if (placed != null) {
      final path = _shape(placed).shift(offset);
      context.canvas
        ..drawPath(path.shift(const Offset(0, 3)), Paint()..color = V3Colors.cocoa.withValues(alpha: 0.22))
        ..drawPath(path, Paint()..color = V3Colors.paper)
        ..drawPath(
          path,
          Paint()
            ..color = V3Colors.cocoa
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round,
        );
    }
    super.paint(context, offset);
  }
}
