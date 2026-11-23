import 'package:supabase_flutter/supabase_flutter.dart';

import 'puzzle.dart';
import 'puzzle_repository.dart';

/// 목록은 `puzzles` 테이블(RLS: 로그인한 사용자는 공개된 퍼즐만), 퍼즐 하나는
/// `get_puzzle(p_puzzle_id)` RPC로 받는다. 정답 철자는 어느 쪽에서도 오지 않는다.
class SupabasePuzzleRepository implements PuzzleRepository {
  SupabasePuzzleRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<PuzzleSummary>> listPuzzles() async {
    final List<Map<String, dynamic>> rows;
    try {
      // published 는 RLS 정책이 걸러 주지만, 뜻을 분명히 하려고 조건도 같이 건다.
      rows = await _client.from('puzzles').select('id, level, rows, cols, word_count').eq('published', true);
    } catch (_) {
      throw const PuzzleFailure('퍼즐 목록을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.');
    }
    try {
      return rows.map(PuzzleSummary.fromJson).toList()..sort(PuzzleSummary.compare);
    } catch (_) {
      throw const PuzzleFailure('퍼즐 목록 데이터가 올바르지 않아요.');
    }
  }

  @override
  Future<PuzzleData> fetchPuzzle(String puzzleId) async {
    final Object? res;
    try {
      res = await _client.rpc('get_puzzle', params: {'p_puzzle_id': puzzleId});
    } catch (_) {
      throw const PuzzleFailure('퍼즐을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.');
    }
    // 없는 퍼즐, 공개 안 된 퍼즐, 로그인 안 한 경우 RPC가 null을 돌려준다.
    if (res is! Map) throw const PuzzleFailure('퍼즐을 찾을 수 없어요.');
    try {
      return PuzzleData.fromJson(res.cast<String, dynamic>());
    } catch (_) {
      throw const PuzzleFailure('퍼즐 데이터가 올바르지 않아요.');
    }
  }
}
