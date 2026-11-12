import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

/// main(또는 테스트)에서 실제 구현으로 덮어쓴다.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('authRepositoryProvider를 main에서 override 해야 합니다.'),
);

/// Supabase 없이 로컬 가짜 로그인으로 실행 중인지 여부.
final localModeProvider = Provider<bool>((ref) => false);

/// 현재 로그인한 사용자. 로그인·로그아웃 때마다 바뀐다.
final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.currentUser;
  yield* repo.authStateChanges();
});
