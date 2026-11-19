import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/v3_theme.dart';
import 'play_providers.dart';
import 'play_state.dart';
import 'puzzle_repository.dart';
import 'widgets/hint_bar.dart';
import 'widgets/letter_keyboard.dart';
import 'widgets/puzzle_grid.dart';

/// Figma v3 3-1 퍼즐 풀이. 하단 메뉴 없이 root navigator에 올린다.
///
/// 2주차: 격자, 칸 선택, 전용 키보드, 힌트 표시.
/// 제출·확인(3주차), 글자 힌트·정답 공개(4주차), 타이머(4주차 풀이 기록)는 자리만 둔다.
class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key, required this.puzzleId});

  final String puzzleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final puzzle = ref.watch(puzzleProvider(puzzleId));
    return Scaffold(
      backgroundColor: V3Colors.cream,
      body: SafeArea(
        child: switch (puzzle) {
          AsyncData() => _PlayView(puzzleId: puzzleId),
          AsyncError(:final error) => _LoadError(
              message: error is PuzzleFailure ? error.message : '퍼즐을 불러오지 못했어요.',
              onRetry: () => ref.invalidate(puzzleProvider(puzzleId)),
            ),
          _ => const Center(child: CircularProgressIndicator(color: V3Colors.peach)),
        },
      ),
    );
  }
}

void _close(BuildContext context) => context.canPop() ? context.pop() : context.go(Routes.puzzles);

class _PlayView extends ConsumerWidget {
  const _PlayView({required this.puzzleId});

  final String puzzleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playProvider(puzzleId));
    final play = ref.read(playProvider(puzzleId).notifier);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _onKey(event, play),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(state: state, onClose: () => _close(context)),
            const SizedBox(height: 10),
            _Progress(value: state.puzzle.clues.isEmpty ? 0 : state.filledWordCount / state.puzzle.clues.length),
            const SizedBox(height: 12),
            HintBar(
              state: state,
              onCycleHint: play.cycleHint,
              onPrevious: play.previousClue,
              onNext: play.nextClue,
            ),
            const SizedBox(height: 12),
            Expanded(child: Center(child: PuzzleGrid(state: state, onTapCell: play.tapCell))),
            const SizedBox(height: 6),
            const Text(
              '칸을 누르면 단어 선택 · 한 번 더 누르면 가로·세로 전환',
              style: V3Text.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const _ActionRow(),
            const SizedBox(height: 14),
            LetterKeyboard(onLetter: play.typeLetter, onBackspace: play.backspace),
          ],
        ),
      ),
    );
  }

  /// 실제 키보드(에뮬레이터·데스크톱·테스트): 글자, 지우기, 화살표, Tab(다음 단어), 스페이스(방향 바꾸기).
  KeyEventResult _onKey(KeyEvent event, PlayController play) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final ch = event.character;
    if (ch != null && RegExp(r'^[a-zA-Z]$').hasMatch(ch)) {
      play.typeLetter(ch);
    } else if (key == LogicalKeyboardKey.backspace) {
      play.backspace();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      play.moveCursor(0, -1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      play.moveCursor(0, 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      play.moveCursor(-1, 0);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      play.moveCursor(1, 0);
    } else if (key == LogicalKeyboardKey.tab) {
      HardwareKeyboard.instance.isShiftPressed ? play.previousClue() : play.nextClue();
    } else if (key == LogicalKeyboardKey.space) {
      play.toggleDirection();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.onClose});

  final PlayState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: '닫기',
          child: Container(
            width: 44,
            height: 44,
            decoration: v3Box(radius: 14),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: const ValueKey('play-close'),
                borderRadius: BorderRadius.circular(14),
                onTap: onClose,
                child: const Icon(Icons.close, color: V3Colors.cocoa),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(state.puzzle.title, style: V3Text.title),
              Text('${state.filledWordCount} / ${state.puzzle.clues.length} 단어', style: V3Text.caption),
            ],
          ),
        ),
        // 제출은 3주차 정답 확인 RPC와 함께 붙인다.
        const _V3Button(label: '제출', color: V3Colors.apricot, onPressed: null, width: 64),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      decoration: v3Box(radius: 6, borderWidth: 1.5, shadow: false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0, 1),
            child: const ColoredBox(color: V3Colors.mint, child: SizedBox.expand()),
          ),
        ),
      ),
    );
  }
}

/// 글자 힌트·정답 공개(4주차), 확인(3주차). 지금은 자리만 보여 준다.
class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _V3Button(label: '글자 힌트', icon: Icons.lightbulb_outline, onPressed: null)),
        SizedBox(width: 8),
        Expanded(child: _V3Button(label: '정답 공개', icon: Icons.visibility_outlined, onPressed: null)),
        SizedBox(width: 8),
        Expanded(child: _V3Button(label: '확인', color: V3Colors.peach, onPressed: null)),
      ],
    );
  }
}

class _V3Button extends StatelessWidget {
  const _V3Button({required this.label, required this.onPressed, this.icon, this.color = V3Colors.paper, this.width});

  final String label;
  final IconData? icon;
  final Color color;
  final double? width;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        width: width,
        height: 44,
        decoration: v3Box(color: color, radius: 14),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[Icon(icon, size: 18, color: V3Colors.cocoa), const SizedBox(width: 4)],
                      Text(label, style: V3Text.button),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: V3Text.body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 120, child: _V3Button(label: '다시 시도', color: V3Colors.peach, onPressed: onRetry)),
                const SizedBox(width: 8),
                SizedBox(width: 120, child: _V3Button(label: '닫기', onPressed: () => _close(context))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
