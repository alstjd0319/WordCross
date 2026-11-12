import 'dart:async';

import 'auth_repository.dart';

/// Supabase 접속 정보가 없을 때 쓰는 로컬 모드 인증. 앱을 끄면 가입 정보가 사라진다.
/// 위젯 테스트에서도 쓴다.
class FakeAuthRepository implements AuthRepository {
  final _users = <String, String>{};
  final _controller = StreamController<AppUser?>.broadcast();
  final _notices = StreamController<AuthNotice>.broadcast();
  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  Stream<AuthNotice> notices() => _notices.stream;

  /// 테스트용: 인증 메일 링크로 앱이 열린 상황을 흉내 낸다.
  void simulateEmailLink({required String email, bool success = true}) {
    if (!success) {
      _notices.add(AuthNotice.confirmLinkFailed);
      return;
    }
    final key = email.trim().toLowerCase();
    _set(AppUser(id: 'local-$key', email: key));
    _notices.add(AuthNotice.emailConfirmed);
  }

  void _set(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final key = email.trim().toLowerCase();
    if (_users[key] != password) throw const AuthFailure('이메일 또는 비밀번호가 맞지 않아요.');
    _set(AppUser(id: 'local-$key', email: key));
  }

  @override
  Future<SignUpResult> signUp({required String email, required String password, required String nickname}) async {
    final key = email.trim().toLowerCase();
    if (_users.containsKey(key)) throw const AuthFailure('이미 가입된 이메일이에요.');
    _users[key] = password;
    _set(AppUser(id: 'local-$key', email: key));
    return SignUpResult.signedIn;
  }

  @override
  Future<void> signOut() async => _set(null);

  Future<void> dispose() async {
    await _controller.close();
    await _notices.close();
  }
}
