import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/supabase_errors.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth, {required this._deleteAccountRpc});

  final sb.GoTrueClient _auth;

  /// `delete_my_account` RPC. auth.users 행을 지우면 프로필·풀이 기록·오답이 함께 지워진다.
  final Future<void> Function() _deleteAccountRpc;

  /// 인증 메일 링크를 누르면 돌아올 앱 주소. Supabase 대시보드 Redirect URLs 와
  /// AndroidManifest.xml · Info.plist 의 URL scheme 과 같아야 한다.
  static const emailRedirectUrl = 'com.wordcross.wordcross://login-callback';

  static AppUser? _map(sb.User? user) {
    if (user == null) return null;
    final nickname = user.userMetadata?['nickname'];
    return AppUser(id: user.id, email: user.email ?? '', nickname: nickname is String ? nickname : null);
  }

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.onAuthStateChange
      .map((state) => _map(state.session?.user))
      // 만료된 인증 링크 처리 실패도 이 스트림에 오류로 들어온다. 로그인 상태는 그대로이므로 무시한다.
      .handleError((Object _) {});

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

  @override
  Future<void> deleteAccount() async {
    try {
      await _deleteAccountRpc().timeout(const Duration(seconds: 15));
    } on sb.PostgrestException catch (e) {
      if (isLoginExpired(e)) throw const AuthFailure('로그인이 풀렸어요. 다시 로그인해 주세요.', loginExpired: true);
      throw const AuthFailure('계정을 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.');
    } catch (_) {
      throw const AuthFailure(_networkMessage);
    }
    try {
      await _auth.signOut();
    } catch (_) {
      // 기기의 세션은 먼저 지워진다. 계정이 이미 없어 서버 쪽 로그아웃이 실패하는 것은 무시한다.
    }
  }

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
