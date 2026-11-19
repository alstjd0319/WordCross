import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'play_state.dart';
import 'puzzle.dart';
import 'puzzle_repository.dart';

/// main(또는 테스트)에서 실제 구현으로 덮어쓴다.
final puzzleRepositoryProvider = Provider<PuzzleRepository>(
  (ref) => throw UnimplementedError('puzzleRepositoryProvider를 main에서 override 해야 합니다.'),
);

/// 퍼즐 id → 퍼즐 틀과 힌트. 화면을 떠나면 버린다.
final puzzleProvider = FutureProvider.autoDispose.family<PuzzleData, String>(
  (ref, puzzleId) => ref.watch(puzzleRepositoryProvider).fetchPuzzle(puzzleId),
);

/// 퍼즐 id → 풀이 상태. [puzzleProvider]가 데이터를 받은 뒤에만 읽는다.
final playProvider = NotifierProvider.autoDispose.family<PlayController, PlayState, String>(PlayController.new);

class PlayController extends Notifier<PlayState> {
  PlayController(this.puzzleId);

  final String puzzleId;

  @override
  PlayState build() => PlayState.start(ref.watch(puzzleProvider(puzzleId)).requireValue);

  void tapCell(int row, int col) => state = state.tapCell(row, col);
  void typeLetter(String letter) => state = state.typeLetter(letter);
  void backspace() => state = state.backspace();
  void toggleDirection() => state = state.toggleDirection();
  void nextClue() => state = state.nextClue();
  void previousClue() => state = state.previousClue();
  void moveCursor(int dRow, int dCol) => state = state.moveCursor(dRow, dCol);
  void cycleHint() => state = state.cycleHint();
}
