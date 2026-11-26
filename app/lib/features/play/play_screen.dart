import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../shared/widgets.dart';
import '../auth/login_expired.dart';
import 'attempt.dart';
import 'play_providers.dart';
import 'play_session.dart';
import 'play_state.dart';
import 'puzzle_repository.dart';
import 'result_screen.dart';
import 'widgets/letter_keyboard.dart';
import 'widgets/zoomable_grid.dart';

/// Figma v3 3-1 퍼즐 풀이. 하단 메뉴 없이 root navigator에 올린다.
///
/// 격자, 칸 선택, 전용 키보드, 힌트(2주차), 확대·이동, 확인·제출, 격자 위 힌트 말풍선(3주차).
/// 제출하면 결과 화면(4주차)으로 간다. 글자 힌트·정답 공개는 4주차라 아직 자리만 있다.
class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key, required this.puzzleId});

  final String puzzleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 퍼즐 틀과 풀이 기록을 함께 받는다 (supabase/README.md "풀이 흐름").
    final puzzle = ref.watch(puzzleProvider(puzzleId));
    final attempt = ref.watch(attemptProvider(puzzleId));
    ref.listen(puzzleProvider(puzzleId), (_, next) => _onLoad(context, ref, next));
    ref.listen(attemptProvider(puzzleId), (_, next) => _onLoad(context, ref, next));
    return Scaffold(
      backgroundColor: V3Colors.cream,
      body: SafeArea(
        child: switch ((puzzle, attempt)) {
          (AsyncData(), AsyncData()) => _PlayView(puzzleId: puzzleId),
          (AsyncError(:final error), _) || (_, AsyncError(:final error)) => _LoadError(
              message: error is PuzzleFailure ? error.message : '퍼즐을 불러오지 못했어요.',
              onRetry: () {
                if (puzzle.hasError) ref.invalidate(puzzleProvider(puzzleId));
                if (attempt.hasError) ref.invalidate(attemptProvider(puzzleId));
              },
            ),
          _ => const Center(child: CircularProgressIndicator(color: V3Colors.peach)),
        },
      ),
    );
  }
}

void _onLoad(BuildContext context, WidgetRef ref, AsyncValue<Object?> value) {
  if (value.error case PuzzleFailure(loginExpired: true)) expireLogin(context, ref);
}

/// 실제 키보드에서 누른 알파벳. 맥·PC 입력 소스가 한글이면 Q 키가 'ㅂ'으로 들어오므로,
/// 글자가 A~Z가 아니면 눌린 키의 위치(physical key)로 알파벳을 정한다.
String? letterFromKeyEvent(KeyEvent event) {
  final ch = event.character;
  if (ch != null && RegExp(r'^[a-zA-Z]$').hasMatch(ch)) return ch.toUpperCase();
  // USB HID 키 코드: A(0x04) ~ Z(0x1D)
  final usage = event.physicalKey.usbHidUsage;
  const keyA = 0x00070004, keyZ = 0x0007001d;
  if (usage < keyA || usage > keyZ) return null;
  if (HardwareKeyboard.instance.isControlPressed ||
      HardwareKeyboard.instance.isMetaPressed ||
      HardwareKeyboard.instance.isAltPressed) {
    return null; // Cmd+C 같은 단축키는 글자로 넣지 않는다
  }
  return String.fromCharCode('A'.codeUnitAt(0) + usage - keyA);
}

void _close(BuildContext context) => context.canPop() ? context.pop() : context.go(Routes.puzzles);

class _PlayView extends ConsumerWidget {
  const _PlayView({required this.puzzleId});

  final String puzzleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(playProvider(puzzleId));
    final state = session.board;
    final play = ref.read(playProvider(puzzleId).notifier);
    ref.listen(playProvider(puzzleId), (prev, next) {
      if (prev?.result == null && next.result != null) _showResult(context, state, next.result!);
      if (prev?.end == null && next.end != null) _onEnd(context, ref, next.end!);
    });

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _onKey(event, play),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              session: session,
              onClose: () => _close(context),
              onSubmit: session.canSubmit ? () => _submit(context, state, play) : null,
            ),
            const SizedBox(height: 10),
            _Progress(value: state.puzzle.clues.isEmpty ? 0 : state.doneWordCount / state.puzzle.clues.length),
            const SizedBox(height: 10),
            // 격자 + 힌트 말풍선 + 아래 줄(이전·다음 단어, 안내, 확대).
            // 확대하면 고른 단어가 화면 가운데로 따라온다. 확인 결과 같은 안내는 아래 줄의 안내 문구 자리에 보인다.
            Expanded(
              child: ZoomableGrid(
                state: state,
                onTapCell: play.tapCell,
                onCycleHint: play.cycleHint,
                onPrevious: play.previousClue,
                onNext: play.nextClue,
                notice: session.notice,
                onRetry: play.retry,
              ),
            ),
            const SizedBox(height: 10),
            _ActionRow(checking: session.checking, onCheck: session.canCheck ? play.checkWord : null),
            const SizedBox(height: 14),
            LetterKeyboard(onLetter: play.typeLetter, onBackspace: play.backspace),
          ],
        ),
      ),
    );
  }

  /// 못 푼 단어가 있으면 먼저 확인 창을 띄운다 (기획서 4장).
  Future<void> _submit(BuildContext context, PlayState state, PlayController play) async {
    final remaining = state.remainingWordCount;
    if (remaining > 0) {
      final ok = await showV3Dialog<bool>(
        context,
        title: '아직 $remaining단어 남았어요. 제출할까요?',
        message: '확인하지 않은 단어와\n맞히지 못한 단어는 0점이 돼요.',
        cancelLabel: '계속 풀기',
        confirmLabel: '제출',
        confirmValue: true,
      );
      if (ok != true || !context.mounted) return;
    }
    await play.submit();
  }

  /// 결과 화면으로. 풀이 화면은 닫히고, 결과에서 뒤로 가면 퍼즐 목록으로 간다.
  void _showResult(BuildContext context, PlayState state, AttemptResult r) {
    context.go(
      Routes.resultPath(state.puzzle.id),
      extra: ResultArgs(puzzleId: state.puzzle.id, level: state.puzzle.level, result: r),
    );
  }

  Future<void> _onEnd(BuildContext context, WidgetRef ref, SessionEnd end) async {
    switch (end) {
      case SessionEnd.authExpired:
        await expireLogin(context, ref);
      case SessionEnd.attemptEnded:
        final restart = await showV3Dialog<bool>(
          context,
          title: '이 풀이는 끝났어요.',
          message: '다른 기기에서 제출했거나, 시작한 지 24시간이 지났어요.',
          cancelLabel: '닫기',
          confirmLabel: '다시 시작',
          confirmValue: true,
          dismissible: false,
        );
        if (!context.mounted) return;
        restart == true ? ref.invalidate(attemptProvider(puzzleId)) : _close(context);
    }
  }

  /// 실제 키보드(에뮬레이터·데스크톱·테스트): 글자, 지우기, 화살표, Tab(다음 단어), 스페이스(방향 바꾸기), Enter(확인).
  KeyEventResult _onKey(KeyEvent event, PlayController play) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final letter = letterFromKeyEvent(event);
    if (letter != null) {
      play.typeLetter(letter);
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
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) play.checkWord();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session, required this.onClose, required this.onSubmit});

  final PlaySession session;
  final VoidCallback onClose;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final state = session.board;
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
              // 맞힌 단어 / 전체 단어
              Text('${state.doneWordCount} / ${state.puzzle.clues.length} 단어', style: V3Text.caption),
            ],
          ),
        ),
        _V3Button(
          key: const ValueKey('play-submit'),
          label: session.submitting ? '제출 중' : '제출',
          color: V3Colors.apricot,
          onPressed: onSubmit,
          width: 64,
        ),
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

/// 확인(3주차)과 글자 힌트·정답 공개(4주차, 지금은 자리만).
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.checking, required this.onCheck});

  final bool checking;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _V3Button(label: '글자 힌트', icon: Icons.lightbulb_outline, onPressed: null)),
        const SizedBox(width: 8),
        const Expanded(child: _V3Button(label: '정답 공개', icon: Icons.visibility_outlined, onPressed: null)),
        const SizedBox(width: 8),
        Expanded(
          child: _V3Button(
            key: const ValueKey('play-check'),
            label: checking ? '확인 중' : '확인',
            color: V3Colors.peach,
            onPressed: onCheck,
          ),
        ),
      ],
    );
  }
}

class _V3Button extends StatelessWidget {
  const _V3Button({super.key, required this.label, required this.onPressed, this.icon, this.color = V3Colors.paper, this.width});

  final String label;
  final IconData? icon;
  final Color color;
  final double? width;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // 지금 누를 수 없는 버튼은 투명하게 하지 않고, 바탕을 옅게·선과 글자를 보조색으로 바꿔
    // 글자는 또렷하게 읽히면서 누를 수 없다는 것이 보이게 한다.
    final enabled = onPressed != null;
    final fg = enabled ? V3Colors.cocoa : V3Colors.cocoaMuted;
    return Semantics(
      button: true,
      enabled: enabled,
      child: Container(
        width: width,
        height: 44,
        decoration: enabled
            ? v3Box(color: color, radius: 14)
            : v3Box(color: Color.lerp(color, V3Colors.cream, 0.55)!, radius: 14, borderColor: V3Colors.cocoaMuted, shadow: false),
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
                      if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 4)],
                      Text(label, style: V3Text.button.copyWith(color: fg)),
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
