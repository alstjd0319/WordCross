import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../shared/widgets.dart';
import 'attempt.dart';
import 'play_providers.dart';
import 'puzzle.dart';

/// 결과 화면에 넘기는 값. 제출 직후 풀이 화면이 만든다.
class ResultArgs {
  const ResultArgs({required this.puzzleId, required this.level, required this.result});

  final String puzzleId;

  /// beginner / intermediate / advanced
  final String level;
  final AttemptResult result;
}

/// Figma v3 3-2 결과. 하단 메뉴 없이 root navigator에 올린다.
///
/// 점수, 정답률·소요 시간·글자 힌트, 오답 노트에 들어간 단어, 맞힌 단어, 오답 노트로 가기·다음 퍼즐.
/// 시안의 "고양이가 찾아왔어요" 카드는 고양이 수집이 정해지면 넣는다.
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.args});

  final ResultArgs args;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  bool _showSolved = false;

  void _close() => context.go(Routes.puzzles);

  /// 목록 순서(초급 → 중급 → 고급, 번호순)에서 바로 다음 퍼즐. 마지막이면 null.
  PuzzleSummary? _nextPuzzle(List<PuzzleSummary> all) {
    final sorted = [...all]..sort(PuzzleSummary.compare);
    final i = sorted.indexWhere((p) => p.id == widget.args.puzzleId);
    if (i < 0) {
      return sorted.where((p) => p.level == widget.args.level).firstOrNull;
    }
    return i + 1 < sorted.length ? sorted[i + 1] : null;
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final r = args.result;
    final wrong = r.wrongWords;
    final solved = r.solvedWords;
    final next = switch (ref.watch(puzzleListProvider)) {
      AsyncData(:final value) => _nextPuzzle(value),
      _ => null,
    };

    return PopScope(
      // 결과에서 뒤로 가면 끝난 풀이 화면이 아니라 퍼즐 목록으로 간다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: V3Colors.cream,
        body: SafeArea(
          child: ListView(
            key: const ValueKey('result-list'),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              _Header(onClose: _close),
              Text('퍼즐 완료!', textAlign: TextAlign.center, style: V3Text.title.copyWith(fontSize: 34)),
              const SizedBox(height: 6),
              Text(
                puzzleTitle(args.puzzleId, args.level),
                textAlign: TextAlign.center,
                style: V3Text.caption.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 10),
              _Score(score: r.score, maxScore: r.maxScore),
              const SizedBox(height: 14),
              _Stats(result: r),
              const SizedBox(height: 6),
              Text(
                '소요 시간은 중간에 멈춘 시간을 포함해요.',
                textAlign: TextAlign.center,
                style: V3Text.caption.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 18),
              Text(
                wrong.isEmpty ? '오답 노트에 추가된 단어가 없어요' : '오답 노트에 추가된 단어 ${wrong.length}개',
                style: V3Text.button.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 10),
              if (wrong.isEmpty)
                const _Perfect()
              else
                _WordList(key: const ValueKey('result-wrong'), words: wrong, chip: _wrongChip),
              const SizedBox(height: 14),
              if (solved.isNotEmpty) ...[
                _ToggleRow(
                  label: '맞힌 단어 ${solved.length}개 ${_showSolved ? '접기' : '보기'}',
                  open: _showSolved,
                  onTap: () => setState(() => _showSolved = !_showSolved),
                ),
                if (_showSolved) ...[
                  const SizedBox(height: 10),
                  _WordList(key: const ValueKey('result-solved'), words: solved, chip: _solvedChip),
                ],
                const SizedBox(height: 14),
              ],
              _BigButton(
                key: const ValueKey('result-wrong-notes'),
                label: '오답 노트에서 복습',
                color: V3Colors.peach,
                textColor: Colors.white,
                onTap: () => context.go(Routes.wrongNotes),
              ),
              const SizedBox(height: 10),
              _BigButton(
                key: const ValueKey('result-next'),
                label: next == null ? '퍼즐 목록' : '다음 퍼즐',
                color: V3Colors.paper,
                onTap: () => context.go(next == null ? Routes.puzzles : Routes.puzzleDetailPath(next.id)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          const Positioned(left: 0, bottom: 0, child: CatImage('long_calico', height: 40)),
          Positioned(
            right: 0,
            top: 4,
            child: Tooltip(
              message: '닫기',
              child: Container(
                width: 44,
                height: 44,
                decoration: v3Box(radius: 14),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    key: const ValueKey('result-close'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: onClose,
                    child: const Icon(Icons.close, color: V3Colors.cocoa),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 예: 2500 → 2,500
String _comma(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// 큰 점수: 복숭아색 글자 + 갈색 테두리 + 아래 그림자.
class _Score extends StatelessWidget {
  const _Score({required this.score, required this.maxScore});

  final int score;
  final int maxScore;

  @override
  Widget build(BuildContext context) {
    final big = V3Text.word(58, weight: FontWeight.w700);
    final label = _comma(score);
    return Semantics(
      label: '$score점 / $maxScore점',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Stack(
              children: [
                Transform.translate(
                  offset: const Offset(0, 3),
                  child: Text(label, style: big.copyWith(color: V3Colors.cocoa.withValues(alpha: 0.18))),
                ),
                Text(
                  label,
                  style: big.copyWith(
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 5
                      ..strokeJoin = StrokeJoin.round
                      ..color = V3Colors.cocoa,
                  ),
                ),
                Text(label, key: const ValueKey('result-score'), style: big.copyWith(color: V3Colors.peach)),
              ],
            ),
            const SizedBox(width: 8),
            Text('/ ${_comma(maxScore)}점', style: V3Text.button.copyWith(fontSize: 17, color: V3Colors.cocoaMuted)),
          ],
        ),
      ),
    );
  }
}

/// 정답률 · 소요 시간 · 글자 힌트
class _Stats extends StatelessWidget {
  const _Stats({required this.result});

  final AttemptResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    Widget cell(String value, String label, Key key) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Column(
              children: [
                FittedBox(fit: BoxFit.scaleDown, child: Text(value, key: key, style: V3Text.title.copyWith(fontSize: 24))),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: V3Text.caption.copyWith(fontFamily: V3Fonts.jua)),
                ),
              ],
            ),
          ),
        );
    const divider = VerticalDivider(width: 2, thickness: 2, color: Color(0xFFEFD9B8));
    return Container(
      decoration: v3Box(radius: 20, borderWidth: 2.5),
      child: IntrinsicHeight(
        child: Row(
          children: [
            cell('${r.accuracyPercent}%', '정답률 ${r.correct}/${r.total}', const ValueKey('result-accuracy')),
            divider,
            cell(r.durationClock, '소요 시간', const ValueKey('result-time')),
            divider,
            cell('${r.letterHints}번', '글자 힌트', const ValueKey('result-hints')),
          ],
        ),
      ),
    );
  }
}

/// 오답 단어 옆 표시. 정답 공개 > 못 끝냄(5번 다 틀림 / 미완료) > n번 틀림.
(String, Color) _wrongChip(WordResult w) => w.revealed
    ? ('정답 공개', V3Colors.apricot)
    : !w.solved
        ? (w.tries >= WordProgress.maxTries ? '${w.tries}번 틀림' : '미완료', V3Colors.apricot)
        : ('${w.wrongTries}번 틀림', V3Colors.butter);

(String, Color) _solvedChip(WordResult w) => ('+${w.score}', V3Colors.mint);

class _WordList extends StatelessWidget {
  const _WordList({super.key, required this.words, required this.chip});

  final List<WordResult> words;
  final (String, Color) Function(WordResult) chip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: v3Box(radius: 20, borderWidth: 2.5),
      child: Column(
        children: [
          for (final (i, w) in words.indexed) ...[
            if (i > 0) const DashedDivider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.display, style: V3Text.word(16)),
                        if (w.meaningKo != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            w.meaningKo!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: V3Text.caption.copyWith(fontSize: 13.5),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Chip(chip(w)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.value);

  final (String, Color) value;

  @override
  Widget build(BuildContext context) {
    final (label, color) = value;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: V3Colors.cocoa, width: 2),
      ),
      child: Text(label, style: V3Text.button.copyWith(fontSize: 12.5)),
    );
  }
}

class _Perfect extends StatelessWidget {
  const _Perfect();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: v3Box(radius: 20, borderWidth: 2.5),
      child: Row(
        children: [
          const CatImage('sit_star', height: 52),
          const SizedBox(width: 14),
          Expanded(child: Text('한 번도 틀리지 않았어요.\n완벽해요!', style: V3Text.body)),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.open, required this.onTap});

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: v3Box(radius: 20, borderWidth: 2.5),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('result-toggle-solved'),
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: Text(label, style: V3Text.button)),
                Icon(open ? Icons.keyboard_arrow_up : Icons.chevron_right, color: V3Colors.cocoa),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    super.key,
    required this.label,
    required this.color,
    required this.onTap,
    this.textColor = V3Colors.cocoa,
  });

  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: v3Box(color: color, radius: 18, borderWidth: 2.5),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(child: Text(label, style: V3Text.button.copyWith(fontSize: 17, color: textColor))),
        ),
      ),
    );
  }
}
