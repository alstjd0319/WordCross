import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../shared/widgets.dart';
import '../play/play_providers.dart';
import '../play/puzzle.dart';
import '../play/puzzle_repository.dart';
import 'grid_preview.dart';

/// Figma v3 2-3 퍼즐 상세 (3주차).
///
/// 격자 미리보기, 크기·단어 수·예상 시간, 풀이 규칙, 시작하기.
/// "다 풀면 찾아올 고양이"(고양이 수집 확률)는 5주차 고양이 도감과 함께 더한다.
class PuzzleDetailScreen extends ConsumerWidget {
  const PuzzleDetailScreen({super.key, required this.puzzleId});

  final String puzzleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final puzzle = ref.watch(puzzleProvider(puzzleId));
    return Scaffold(
      appBar: AppBar(
        leading: V3IconButton(
          icon: Icons.chevron_left,
          tooltip: '뒤로',
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.puzzles),
        ),
        leadingWidth: 64,
        titleSpacing: 4,
        title: Text('퍼즐 상세', style: text.titleMedium),
      ),
      body: SafeArea(
        top: false,
        child: switch (puzzle) {
          AsyncData(:final value) => _Detail(puzzle: value),
          AsyncError(:final error) => LoadErrorView(
              message: error is PuzzleFailure ? error.message : '퍼즐을 불러오지 못했어요.',
              onRetry: () => ref.invalidate(puzzleProvider(puzzleId)),
            ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.puzzle});

  final PuzzleData puzzle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final summary = PuzzleSummary.of(puzzle);
    final minutes = summary.estimatedMinutes;
    final across = puzzle.clues.where((c) => c.dir == Direction.across).length;
    final down = puzzle.clues.length - across;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              // 격자 미리보기 카드. 오른쪽 위에 고양이가 엎드려 있다.
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: V3Card(
                      padding: const EdgeInsets.all(18),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                          child: GridPreview(puzzle: puzzle),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(right: 14, top: 0, child: CatImage('loaf_siam', height: 34)),
                ],
              ),
              const SizedBox(height: 18),
              Text(puzzle.title, style: text.titleLarge!.copyWith(fontSize: 28)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Stat(value: summary.sizeLabel, label: '크기')),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(value: '${summary.wordCount}개', label: '단어')),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(value: minutes == null ? '-' : '약 $minutes분', label: '예상 시간')),
                ],
              ),
              const SizedBox(height: 14),
              // 풀이 규칙 (기획서 8장). 확인은 3주차, 글자 힌트·정답 공개는 4주차에 실제로 동작한다.
              V3Card(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    const _Rule(icon: Icons.lightbulb_outline, text: '힌트: 한국어 뜻 · 영어 정의 · 예문'),
                    const DashedDivider(),
                    const _Rule(icon: Icons.check, text: '단어마다 5번까지 확인할 수 있어요'),
                    const DashedDivider(),
                    const _Rule(icon: Icons.visibility_outlined, text: '글자 힌트는 단어당 2번, 막히면 정답 공개'),
                    const DashedDivider(),
                    _Rule(icon: Icons.menu_book_outlined, text: '가로 $across개 · 세로 $down개 단어가 들어 있어요'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: PrimaryButton(
            onPressed: () => context.push(Routes.playPath(puzzle.id)),
            child: const Text('시작하기'),
          ),
        ),
      ],
    );
  }
}

/// 크기·단어·예상 시간 상자.
class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: v3Box(radius: 16),
      child: Column(
        children: [
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.wcColors.textMuted)),
        ],
      ),
    );
  }
}

/// 규칙 한 줄: 살구색 아이콘 상자 + 설명.
class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: v3Box(color: V3Colors.apricot, radius: 9, borderWidth: 1.6, shadow: false),
            child: Icon(icon, size: 18, color: V3Colors.cocoa),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.labelLarge)),
        ],
      ),
    );
  }
}
