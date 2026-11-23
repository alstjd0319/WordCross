import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../shared/widgets.dart';
import '../play/play_providers.dart';
import '../play/puzzle.dart';
import '../play/puzzle_repository.dart';
import 'level_badge.dart';

/// Figma v3 2-2 퍼즐 목록 (3주차).
///
/// 공개된 퍼즐을 난이도별로 걸러 보여 준다. 카드를 누르면 퍼즐 풀이로 간다.
/// 퍼즐 상세(2-3)가 생기면 카드는 상세로 가게 바꾼다.
/// "안 푼 퍼즐 먼저", "완료·점수" 표시는 풀이 기록이 생기는 4주차에 더한다.
class PuzzleListScreen extends ConsumerStatefulWidget {
  const PuzzleListScreen({super.key});

  @override
  ConsumerState<PuzzleListScreen> createState() => _PuzzleListScreenState();
}

class _PuzzleListScreenState extends ConsumerState<PuzzleListScreen> {
  /// null 이면 전체.
  PuzzleLevel? _filter;

  /// 카드 모서리에 고개를 내미는 고양이. 카드마다 돌아가며 쓴다.
  static const _peekCats = ['peek_calico', 'peek_tux', 'peek_ginger', 'peek_siam', 'peek_tabby', 'peek_cream'];

  Future<void> _refresh() => ref.refresh(puzzleListProvider.future).catchError((_) => <PuzzleSummary>[]);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final list = ref.watch(puzzleListProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text('퍼즐', style: text.titleLarge),
            ),
            _FilterChips(selected: _filter, onSelected: (l) => setState(() => _filter = l)),
            const SizedBox(height: 8),
            Expanded(
              child: switch (list) {
                AsyncData(:final value) => _buildList(value),
                AsyncError(:final error) => _LoadError(
                    message: error is PuzzleFailure ? error.message : '퍼즐 목록을 불러오지 못했어요.',
                    onRetry: () => ref.invalidate(puzzleListProvider),
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<PuzzleSummary> all) {
    final shown = _filter == null ? all : all.where((p) => p.puzzleLevel == _filter).toList();
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refresh,
      child: shown.isEmpty
          // 비어 있어도 당겨서 새로고침이 되도록 스크롤되는 목록 안에 안내를 넣는다.
          ? LayoutBuilder(
              builder: (context, box) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: box.maxHeight,
                    child: ComingSoon(
                      cat: 'curl_cream',
                      title: _filter == null ? '아직 공개된 퍼즐이 없어요' : '${_filter!.label} 퍼즐이 아직 없어요',
                      description: '퍼즐이 등록되면 여기에 보여요.',
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, i) => PuzzleCard(
                puzzle: shown[i],
                cat: _peekCats[i % _peekCats.length],
                onTap: () => context.push(Routes.playPath(shown[i].id)),
              ),
            ),
    );
  }
}

/// Figma v3/Chip: 전체·초급·중급·고급. 고른 것은 버터색.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final PuzzleLevel? selected;
  final ValueChanged<PuzzleLevel?> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = <(PuzzleLevel?, String)>[(null, '전체'), for (final l in PuzzleLevel.values) (l, l.label)];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          for (final (level, label) in options) ...[
            _Chip(label: label, selected: level == selected, onTap: () => onSelected(level)),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Container(
        height: 36,
        decoration: v3Box(color: selected ? V3Colors.butter : V3Colors.paper, radius: 18, borderWidth: 1.8),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text(label, style: Theme.of(context).textTheme.labelLarge)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 퍼즐 카드: 난이도 배지, 제목, 크기·단어 수·예상 시간, 오른쪽 화살표, 모서리의 고양이.
class PuzzleCard extends StatelessWidget {
  const PuzzleCard({super.key, required this.puzzle, required this.onTap, this.cat});

  final PuzzleSummary puzzle;
  final VoidCallback onTap;
  final String? cat;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final minutes = puzzle.estimatedMinutes;
    final details = [puzzle.sizeLabel, '단어 ${puzzle.wordCount}개', if (minutes != null) '약 $minutes분'].join(' · ');
    return Semantics(
      button: true,
      label: '${puzzle.title}, $details',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: v3Box(radius: 18),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    children: [
                      LevelBadge(level: puzzle.level),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(puzzle.title, style: text.titleMedium),
                            const SizedBox(height: 2),
                            Text(details, style: text.bodySmall!.copyWith(color: context.wcColors.textMuted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: V3Colors.cocoa),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (cat != null)
            Positioned(
              right: 36,
              bottom: -4,
              child: IgnorePointer(child: CatImage(cat!, height: 26)),
            ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CatImage('sit_tabby', height: 64),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SizedBox(width: 160, child: PrimaryButton(onPressed: onRetry, child: const Text('다시 시도'))),
          ],
        ),
      ),
    );
  }
}
