import 'dart:convert';

import 'puzzle.dart';
import 'puzzle_repository.dart';
import 'sample_puzzles.dart';

/// Supabase 접속 정보가 없을 때 쓰는 로컬 모드 퍼즐 저장소. 위젯 테스트에서도 쓴다.
class FakePuzzleRepository implements PuzzleRepository {
  FakePuzzleRepository({Map<String, String>? puzzles}) : _puzzles = puzzles ?? samplePuzzles;

  final Map<String, String> _puzzles;

  @override
  Future<PuzzleData> fetchPuzzle(String puzzleId) async {
    final json = _puzzles[puzzleId];
    if (json == null) throw const PuzzleFailure('퍼즐을 찾을 수 없어요.');
    return PuzzleData.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
}
