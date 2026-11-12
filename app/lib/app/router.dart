import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/home/home_screen.dart';
import '../features/my_page/my_page_screen.dart';
import '../features/puzzles/puzzle_list_screen.dart';
import '../features/wrong_notes/wrong_notes_screen.dart';
import 'main_shell.dart';

abstract final class Routes {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const puzzles = '/puzzles';
  static const wrongNotes = '/wrong-notes';
  static const myPage = '/my';
}

/// 인증 상태가 바뀌면 GoRouter가 redirect를 다시 계산하게 한다.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<Object?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  final refresh = _AuthRefresh(auth.authStateChanges());
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  final router = GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final loc = state.matchedLocation;
      final onAuthPage = loc == Routes.login || loc == Routes.signup;
      if (!loggedIn) return onAuthPage ? null : Routes.login;
      if (onAuthPage) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: Routes.signup, builder: (context, state) => const SignUpScreen()),
      // 하단 메뉴 4개 탭. 탭마다 화면 상태(스크롤 위치 등)를 따로 유지한다.
      // 퍼즐 풀이·결과·복습 카드는 2주차부터 rootKey에 올려 메뉴를 숨긴다.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.puzzles, builder: (context, state) => const PuzzleListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.wrongNotes, builder: (context, state) => const WrongNotesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.myPage, builder: (context, state) => const MyPageScreen())]),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
