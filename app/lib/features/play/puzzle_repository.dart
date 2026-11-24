import 'puzzle.dart';

/// 화면에 그대로 보여 줄 수 있는 한국어 오류 문구를 담은 퍼즐 불러오기 실패.
class PuzzleFailure implements Exception {
  const PuzzleFailure(this.message, {this.loginExpired = false});

  final String message;

  /// 로그인이 풀려서 실패함. 화면은 오류 대신 로그인 화면으로 보낸다.
  final bool loginExpired;

  @override
  String toString() => 'PuzzleFailure($message)';
}

/// 화면은 이 인터페이스만 알고, 실제 구현(Supabase 또는 로컬 샘플)은 main에서 고른다.
abstract interface class PuzzleRepository {
  /// 공개된 퍼즐 목록 (초급 → 중급 → 고급, 같은 난이도는 id 순). 실패하면 [PuzzleFailure]를 던진다.
  Future<List<PuzzleSummary>> listPuzzles();

  /// 퍼즐 틀과 힌트. 실패하면 [PuzzleFailure]를 던진다.
  Future<PuzzleData> fetchPuzzle(String puzzleId);
}
