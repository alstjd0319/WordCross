import 'package:material_ui/material_ui.dart';

import '../../../app/v3_theme.dart';

/// 화면 아래 전용 영문 키보드 (Figma v3/Key). 시스템 키보드 대신 그려서 격자를 가리지 않는다.
class LetterKeyboard extends StatelessWidget {
  const LetterKeyboard({super.key, required this.onLetter, required this.onBackspace});

  final ValueChanged<String> onLetter;
  final VoidCallback onBackspace;

  static const _rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

  static Key letterKey(String letter) => ValueKey('key-$letter');
  static const backspaceKey = ValueKey('key-backspace');

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(_rows[0]),
        const SizedBox(height: 8),
        // 둘째 줄은 반 칸씩 들여 QWERTY 모양을 맞춘다.
        Row(children: [const Spacer(), Expanded(flex: 18, child: _row(_rows[1])), const Spacer()]),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(flex: 14, child: _row(_rows[2])),
            const SizedBox(width: 6),
            Expanded(
              flex: 3,
              child: _Key(
                key: backspaceKey,
                semanticLabel: '지우기',
                color: const Color(0xFFF2D9BF),
                onTap: onBackspace,
                child: const Icon(Icons.backspace_outlined, size: 20, color: V3Colors.cocoa),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(String letters) {
    return Row(
      children: [
        for (var i = 0; i < letters.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _Key(
              key: letterKey(letters[i]),
              semanticLabel: letters[i],
              onTap: () => onLetter(letters[i]),
              child: Text(letters[i], style: V3Text.word(18)),
            ),
          ),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({super.key, required this.semanticLabel, required this.onTap, required this.child, this.color = V3Colors.paper});

  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        height: 44,
        decoration: v3Box(color: color, radius: 10),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
