/// 로그인한 사용자. 화면에 필요한 최소 정보만 담는다.
class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String email;
}

/// 화면에 그대로 보여 줄 수 있는 한국어 오류 문구를 담은 인증 실패.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => 'AuthFailure($message)';
}

enum SignUpResult {
  /// 가입과 동시에 로그인됨.
  signedIn,

  /// 이메일 인증을 마쳐야 로그인할 수 있음 (Supabase에서 이메일 인증을 켠 경우).
  needsEmailConfirmation,
}

/// 화면에 한 번 알려 줄 인증 관련 소식.
enum AuthNotice {
  /// 인증 메일 링크로 앱이 열려 이메일 인증과 로그인이 끝남.
  emailConfirmed,

  /// 인증 메일 링크가 만료됐거나 이미 사용돼 로그인하지 못함.
  confirmLinkFailed,
}

/// 화면은 이 인터페이스만 알고, 실제 구현(Supabase 또는 로컬 가짜)은 main에서 고른다.
abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// 로그인·로그아웃 때마다 새 사용자(또는 null)를 내보낸다.
  Stream<AppUser?> authStateChanges();

  /// 앱이 직접 로그인시키지 않은 인증 소식(인증 메일 링크 등)을 내보낸다.
  Stream<AuthNotice> notices();

  /// 실패하면 [AuthFailure]를 던진다.
  Future<void> signIn({required String email, required String password});

  /// 실패하면 [AuthFailure]를 던진다.
  /// [nickname]은 가입 정보(user metadata)로 보내고, DB 트리거가 profiles.nickname 에 저장한다.
  Future<SignUpResult> signUp({required String email, required String password, required String nickname});

  Future<void> signOut();
}
