import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final sb.GoTrueClient _auth;

  /// 인증 메일 링크를 누르면 돌아올 앱 주소. Supabase 대시보드 Redirect URLs 와
  /// AndroidManifest.xml · Info.plist 의 URL scheme 과 같아야 한다.
  static const emailRedirectUrl = 'com.wordcross.wordcross://login-callback';

  static AppUser? _map(sb.User? user) => user == null ? null : AppUser(id: user.id, email: user.email ?? '');

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.onAuthStateChange.map((state) => _map(state.session?.user));

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } on sb.AuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      throw const AuthFailure(_networkMessage);
    }
  }

  @override
  Future<SignUpResult> signUp({required String email, required String password, required String nickname}) async {
    try {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'nickname': nickname.trim()},
        emailRedirectTo: emailRedirectUrl,
      );
      return res.session == null ? SignUpResult.needsEmailConfirmation : SignUpResult.signedIn;
    } on sb.AuthException catch (e) {
      throw AuthFailure(_message(e));
    } catch (_) {
      throw const AuthFailure(_networkMessage);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  static const _networkMessage = '서버에 연결하지 못했어요. 네트워크를 확인해 주세요.';

  static String _message(sb.AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return '이메일 또는 비밀번호가 맞지 않아요.';
      case 'user_already_exists':
      case 'email_exists':
        return '이미 가입된 이메일이에요.';
      case 'email_not_confirmed':
        return '이메일 인증을 먼저 마쳐 주세요.';
      case 'weak_password':
        return '비밀번호는 영문과 숫자를 함께 넣어 8자 이상으로 해 주세요.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.';
    }
    if (e is sb.AuthRetryableFetchException) return _networkMessage;
    return '요청을 처리하지 못했어요. 잠시 후 다시 시도해 주세요.';
  }
}
