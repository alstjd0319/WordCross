import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// 하단 메뉴(홈 · 퍼즐 · 오답 노트 · 마이페이지)가 있는 화면 틀.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: MainNavBar(
        selectedIndex: shell.currentIndex,
        // 지금 탭을 다시 누르면 그 탭의 첫 화면으로 돌아간다.
        onSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

/// Figma v3/BottomNav: 위쪽 갈색 선, 고른 탭은 버터색 둥근 네모 안에 아이콘과 이름.
class MainNavBar extends StatelessWidget {
  const MainNavBar({super.key, required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (Icons.home_outlined, Icons.home, '홈'),
    (Icons.grid_on_outlined, Icons.grid_on, '퍼즐'),
    (Icons.menu_book_outlined, Icons.menu_book, '오답 노트'),
    (Icons.person_outline, Icons.person, '마이페이지'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: V3Colors.paper,
        border: Border(top: BorderSide(color: V3Colors.cocoa, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(child: _Tab(item: _items[i], selected: i == selectedIndex, onTap: () => onSelected(i))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final (IconData, IconData, String) item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, selectedIcon, label) = item;
    final color = selected ? V3Colors.cocoa : V3Colors.cocoaMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 52,
          decoration: selected
              ? v3Box(color: V3Colors.butter, radius: 14)
              : const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(14))),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? selectedIcon : icon, size: 22, color: color),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: TextStyle(fontFamily: V3Fonts.jua, fontSize: 12, height: 1.2, color: color)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
