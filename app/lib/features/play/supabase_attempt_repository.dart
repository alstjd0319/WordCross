import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'attempt.dart';
import 'attempt_repository.dart';

/// `client.rpc` 모양의 함수. 테스트에서는 가짜 응답을 넣는다.
typedef RpcCall = Future<Object?> Function(String function, Map<String, dynamic> params);

/// start_attempt · check_word · finish_attempt RPC (`supabase/README.md`).
class SupabaseAttemptRepository implements AttemptRepository {
  SupabaseAttemptRepository(this._rpc, {this.timeout = const Duration(seconds: 15)});

  final RpcCall _rpc;

  /// 이 시간 안에 응답이 없으면 연결 실패로 본다. 요청 번호가 있어 다시 보내도 안전하다.
  final Duration timeout;

  @override
  Future<AttemptStart> start(String puzzleId) =>
      _call('start_attempt', {'p_puzzle_id': puzzleId}, AttemptStart.fromJson);

  @override
  Future<CheckResult> check({
    required int attemptId,
    required int clueId,
    required String guess,
    required String requestId,
  }) =>
      _call(
        'check_word',
        {'p_attempt_id': attemptId, 'p_clue_id': clueId, 'p_guess': guess, 'p_request_id': requestId},
        CheckResult.fromJson,
      );

  @override
  Future<AttemptResult> finish(int attemptId) =>
      _call('finish_attempt', {'p_attempt_id': attemptId}, AttemptResult.fromJson);

  Future<T> _call<T>(String function, Map<String, dynamic> params, T Function(Map<String, dynamic>) parse) async {
    final Object? res;
    try {
      res = await _rpc(function, params).timeout(timeout);
    } on PostgrestException catch (e) {
      throw AttemptFailure(_errorOf(e));
    } catch (_) {
      throw AttemptFailure(AttemptError.network);
    }
    try {
      return parse((res as Map).cast<String, dynamic>());
    } catch (_) {
      throw AttemptFailure(AttemptError.unknown);
    }
  }

  static AttemptError _errorOf(PostgrestException e) {
    // 비로그인 호출은 함수 권한(42501)에서, 만료된 토큰은 PostgREST(PGRST301·303)에서 막힌다.
    if (const {'42501', 'PGRST301', 'PGRST303'}.contains(e.code)) return AttemptError.notAuthenticated;
    return switch (e.message) {
      'not_authenticated' => AttemptError.notAuthenticated,
      'puzzle_not_found' => AttemptError.puzzleNotFound,
      'attempt_not_found' || 'attempt_closed' => AttemptError.attemptEnded,
      'invalid_guess' => AttemptError.invalidGuess,
      'no_tries_left' => AttemptError.noTriesLeft,
      _ => AttemptError.unknown,
    };
  }
}
