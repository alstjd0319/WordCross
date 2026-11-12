import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// 하단 메뉴(홈 · 퍼즐 · 오답 노트 · 마이페이지)가 있는 화면 틀.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          // 지금 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
            NavigationDestination(icon: Icon(Icons.grid_on_outlined), selectedIcon: Icon(Icons.grid_on), label: '퍼즐'),
            NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: '오답 노트'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '마이페이지'),
          ],
        ),
      ),
    );
  }
}
