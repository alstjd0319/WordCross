import 'attempt.dart';
import 'play_state.dart';
import 'puzzle.dart';

enum NoticeTone { info, success, error }

/// 격자 아래에 잠깐 보여 주는 안내 (맞음·틀림·연결 실패 등). 다음 입력을 하면 사라진다.
class PlayNotice {
  const PlayNotice(this.text, {this.tone = NoticeTone.info, this.canRetry = false});

  final String text;
  final NoticeTone tone;

  /// "다시 시도" 버튼을 함께 보여 준다 (네트워크 실패).
  final bool canRetry;
}

/// 화면 밖의 처리(대화 상자·이동)가 필요한 풀이의 끝.
enum SessionEnd {
  /// 다른 기기에서 제출했거나 24시간이 지나 더 풀 수 없음.
  attemptEnded,

  /// 로그인이 풀림. 로그인 화면으로 보낸다.
  authExpired,
}

/// 풀이 화면 전체 상태: 격자([board])와 서버 풀이 기록의 진행 상황.
class PlaySession {
  const PlaySession({
    required this.board,
    required this.attemptId,
    this.checking = false,
    this.submitting = false,
    this.notice,
    this.result,
    this.end,
  });

  final PlayState board;
  final int attemptId;

  /// 확인 요청을 보내고 응답을 기다리는 중.
  final bool checking;

  /// 제출 요청을 보내고 응답을 기다리는 중.
  final bool submitting;
  final PlayNotice? notice;

  /// 제출이 끝나면 들어온다.
  final AttemptResult? result;
  final SessionEnd? end;

  bool get busy => checking || submitting || result != null || end != null;

  /// 확인은 단어 칸을 다 채워야 누를 수 있다. 맞힌 단어와 5번을 다 쓴 단어는 누를 수 없다.
  bool get canCheck {
    final Clue? clue = board.currentClue;
    if (busy || clue == null) return false;
    final p = board.progressOf(clue);
    return !p.done && p.triesLeft > 0 && board.isWordFilled(clue);
  }

  bool get canSubmit => !busy;

  PlaySession copyWith({
    PlayState? board,
    bool? checking,
    bool? submitting,
    PlayNotice? Function()? notice,
    AttemptResult? result,
    SessionEnd? end,
  }) =>
      PlaySession(
        board: board ?? this.board,
        attemptId: attemptId,
        checking: checking ?? this.checking,
        submitting: submitting ?? this.submitting,
        notice: notice == null ? this.notice : notice(),
        result: result ?? this.result,
        end: end ?? this.end,
      );
}
