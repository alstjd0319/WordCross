import 'attempt.dart';
import 'puzzle_repository.dart';

/// 풀이 RPC가 실패한 까닭. 서버 예외 메시지(`supabase/README.md` 오류 표)와 짝을 이룬다.
enum AttemptError {
  /// 서버에 닿지 못했거나 응답을 받지 못함. 같은 요청 번호로 다시 보내도 된다.
  network('연결을 확인해 주세요.'),
  notAuthenticated('로그인이 풀렸어요. 다시 로그인해 주세요.'),
  puzzleNotFound('퍼즐을 찾을 수 없어요.'),

  /// 없는 기록이거나, 제출했거나, 24시간이 지나 포기 처리된 기록.
  attemptEnded('이 풀이는 끝났어요.'),
  invalidGuess('단어의 칸을 모두 채워 주세요.'),
  noTriesLeft('확인 5번을 다 썼어요. 정답 공개만 할 수 있어요.'),
  unknown('요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.');

  const AttemptError(this.message);

  final String message;
}

/// [PuzzleFailure]를 이어받아 불러오기 오류 화면과 자동 재시도 규칙을 그대로 쓴다.
class AttemptFailure extends PuzzleFailure {
  AttemptFailure(this.error) : super(error.message);

  final AttemptError error;
}

/// 풀이 시작·확인·제출. 채점은 서버가 하고 앱은 정답 철자를 미리 알 수 없다.
/// 모든 함수는 실패하면 [AttemptFailure]를 던진다.
abstract interface class AttemptRepository {
  /// 풀이를 시작한다. 진행 중인 기록이 있으면 그것을 이어 푼다.
  Future<AttemptStart> start(String puzzleId);

  /// 단어 하나를 채점한다. [requestId]가 같으면 서버가 한 번만 처리한다.
  Future<CheckResult> check({
    required int attemptId,
    required int clueId,
    required String guess,
    required String requestId,
  });

  /// 퍼즐을 끝낸다. 이미 끝낸 기록이면 같은 결과를 돌려준다.
  Future<AttemptResult> finish(int attemptId);
}
