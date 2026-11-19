import 'package:supabase_flutter/supabase_flutter.dart';

import 'puzzle.dart';
import 'puzzle_repository.dart';

/// `get_puzzle(p_puzzle_id)` RPC로 퍼즐 틀과 힌트를 받는다. 정답 철자는 오지 않는다.
class SupabasePuzzleRepository implements PuzzleRepository {
  SupabasePuzzleRepository(this._client);

  final SupabaseClient _client;

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
