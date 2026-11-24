import 'package:material_ui/material_ui.dart';

import '../../../app/v3_theme.dart';
import '../play_state.dart';
import '../puzzle.dart';

/// 격자 위 힌트 바 (Figma v3 3-1).
///
/// 왼쪽: 단어 번호·방향 배지. 가운데: 글자 수·힌트 종류와 힌트.
/// 오른쪽: 힌트 전환(한국어 뜻 → 영어 정의 → 예문 빈칸), 이전·다음 단어.
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

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: v3Box(radius: 18),
      child: Row(
        children: [
          if (clue != null) _Badge(clue: clue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  [
                    if (clue != null) '${clue.length}글자',
                    if (kind != null) kind.label,
                    if (clue != null) ?_status(clue),
                  ].join(' · '),
                  style: V3Text.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  hint ?? '이 단어는 아직 힌트가 없어요.',
                  key: const ValueKey('hint-text'),
                  style: V3Text.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (next != null)
            _TapTarget(
              key: const ValueKey('hint-toggle'),
              tooltip: '${next.label} 보기',
              onTap: onCycleHint,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swap_horiz, size: 18, color: V3Colors.cocoa),
                  Text(next.shortLabel, style: V3Text.caption.copyWith(color: V3Colors.cocoa)),
                ],
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
