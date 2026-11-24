import 'package:material_ui/material_ui.dart';

import '../../../app/v3_theme.dart';
import '../play_state.dart';
import '../puzzle.dart';

/// 격자 위 힌트 바 (Figma v3 3-1).
///
/// 왼쪽: 단어 번호·방향 배지. 가운데: 글자 수·힌트 종류와 힌트.
/// 오른쪽: 힌트 전환(한국어 뜻 → 영어 정의 → 예문 빈칸), 이전·다음 단어.
///
/// 힌트 길이가 달라도 높이가 늘 같다. 바가 커지고 작아지면 아래 격자 크기가 바뀌기 때문이다 (교수님 피드백).
class HintBar extends StatelessWidget {
  const HintBar({
    super.key,
    required this.state,
    required this.onCycleHint,
    required this.onPrevious,
    required this.onNext,
  });

  final PlayState state;
  final VoidCallback onCycleHint;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

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
    final kind = state.shownHintKind;
    final next = state.nextHintKind;
    final hint = (clue != null && kind != null) ? clue.hint(kind) : null;
    final hintHeight = _HintText.heightOf(context);
    final captionHeight = MediaQuery.textScalerOf(context).scale(V3Text.caption.fontSize!) * V3Text.caption.height!;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      decoration: v3Box(radius: 18),
      child: SizedBox(
        height: (captionHeight + 2 + hintHeight).ceilToDouble(),
        child: Row(
          children: [
            if (clue != null) _Badge(clue: clue),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    [
                      if (clue != null) '${clue.length}글자',
                      if (kind != null) kind.label,
                      if (clue != null) ?_status(clue),
                    ].join(' · '),
                    style: V3Text.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Flexible(child: _HintText(hint ?? '이 단어는 아직 힌트가 없어요.')),
                ],
              ),
            ),
            if (next != null)
              _TapTarget(
                key: const ValueKey('hint-toggle'),
                tooltip: '${next.label} 보기',
                onTap: onCycleHint,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz, size: 18, color: V3Colors.cocoa),
                      Text(next.shortLabel, style: V3Text.caption.copyWith(color: V3Colors.cocoa)),
                    ],
                  ),
                ),
              ),
            _TapTarget(
              key: const ValueKey('clue-prev'),
              tooltip: '이전 단어',
              onTap: onPrevious,
              child: const Icon(Icons.chevron_left, color: V3Colors.cocoa),
            ),
            _TapTarget(
              key: const ValueKey('clue-next'),
              tooltip: '다음 단어',
              onTap: onNext,
              child: const Icon(Icons.chevron_right, color: V3Colors.cocoa),
            ),
          ],
        ),
      ),
    );
  }
}

/// 세 줄 높이 안에 힌트 전체를 보여 준다. 길면 글자를 조금 줄이고(15 → 13), 그래도 넘치면 위아래로 밀어서 읽는다.
class _HintText extends StatefulWidget {
  const _HintText(this.text);

  final String text;

  static const _lines = 3;
  static const _sizes = [15.0, 14.0, 13.0];
  static TextStyle _style(double size) => V3Text.body.copyWith(fontSize: size, fontWeight: FontWeight.w600);

  /// 힌트가 쓰는 높이. 시스템 글자 크기를 키우면 같이 커진다.
  static double heightOf(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_sizes.first) * V3Text.body.height! * _lines;

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

  Widget _text(double size) =>
      Text(widget.text, key: const ValueKey('hint-text'), style: _HintText._style(size));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        for (final size in _HintText._sizes) {
          final painter = TextPainter(
            text: TextSpan(text: widget.text, style: DefaultTextStyle.of(context).style.merge(_HintText._style(size))),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
          )..layout(maxWidth: box.maxWidth);
          final fits = painter.height <= box.maxHeight + 0.5;
          painter.dispose();
          if (fits) return _text(size);
        }
        return Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.only(right: 8),
            child: _text(_HintText._sizes.last),
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.clue});

  final Clue clue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: v3Box(color: V3Colors.apricot, radius: 12, shadow: false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${clue.no}', style: V3Text.word(20)),
          const SizedBox(height: 2),
          Text(clue.dir.label, style: V3Text.caption.copyWith(color: V3Colors.cocoa, fontSize: 12)),
        ],
      ),
    );
  }
}

class _TapTarget extends StatelessWidget {
  const _TapTarget({super.key, required this.tooltip, required this.onTap, required this.child});

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(width: 36, height: 44, child: Center(child: child)),
      ),
    );
  }
}
