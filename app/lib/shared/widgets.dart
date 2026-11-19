import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';

/// v3 손그림 그림자: 아래로 3px, 코코아 18%. 버튼처럼 모양이 정해진 위젯 뒤에 깐다.
class HandDrawnShadow extends StatelessWidget {
  const HandDrawnShadow({super.key, required this.child, this.radius = AppTheme.buttonRadius});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: V3Colors.cocoa.withValues(alpha: 0.18), offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }
}

/// v3 주 버튼: 복숭아 바탕 + 갈색 선 + 손그림 그림자. 안쪽은 [FilledButton]이다.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return HandDrawnShadow(child: FilledButton(onPressed: onPressed, child: child));
  }
}

/// v3 아이콘 버튼 (Figma v3/IconButton): 둥근 네모 안의 아이콘. 뒤로·닫기 등에 쓴다.
class V3IconButton extends StatelessWidget {
  const V3IconButton({super.key, required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 40,
          height: 40,
          decoration: v3Box(radius: 12),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onPressed,
              child: Icon(icon, color: V3Colors.cocoa),
            ),
          ),
        ),
      ),
    );
  }
}

/// v3 카드: 종이색 바탕, 갈색 선, 손그림 그림자.
class V3Card extends StatelessWidget {
  const V3Card({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color = V3Colors.paper});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(padding: padding, decoration: v3Box(color: color, radius: 18), child: child);
  }
}

/// Figma v3/Cat 고양이 그림. [name]은 `<자세>_<털색>` (예: sit_calico, curl_black).
/// 그림은 assets/images/cats/ 에 1x·2x·3x로 들어 있어 화면 해상도에 맞는 것이 쓰인다.
class CatImage extends StatelessWidget {
  const CatImage(this.name, {super.key, this.height});

  final String name;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/images/cats/$name.png',
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        // 그림을 못 읽어도 화면은 그대로 보이게 한다.
        errorBuilder: (context, error, stack) => SizedBox(height: height),
      ),
    );
  }
}

/// Figma의 TextField 컴포넌트: 위에 라벨, 아래에 입력 상자.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final String? hint;

  /// 입력 상자 아래 작은 안내 문구. 오류가 있으면 오류 문구가 대신 보인다.
  final String? helper;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        // 입력칸 아래 안내·오류 문구까지 그림자가 번지지 않게, 입력 상자 크기의 그림자를 뒤에 따로 깐다.
        Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: AppTheme.fieldHeight,
              child: HandDrawnShadow(radius: AppTheme.fieldRadius, child: SizedBox.expand()),
            ),
            TextFormField(
              controller: controller,
              validator: validator,
              obscureText: obscure,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              autofillHints: autofillHints,
              autocorrect: false,
              enableSuggestions: !obscure,
              onFieldSubmitted: onSubmitted,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: hint,
                helperText: helper,
                helperStyle: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.wcColors.textMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 서버·인증 오류를 보여 주는 상자.
class ErrorBox extends StatelessWidget {
  const ErrorBox(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: v3Box(color: AppColors.errorContainer, radius: 12, borderColor: AppColors.error, shadow: false),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: AppColors.error)),
    );
  }
}

/// 버튼 안 로딩 표시.
class ButtonSpinner extends StatelessWidget {
  const ButtonSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white));
  }
}

/// 아직 만들지 않은 탭에 보여 주는 안내. 해당 주차에 실제 화면으로 바꾼다.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.cat, required this.title, required this.description});

  /// 안내 위에 앉힐 고양이 ([CatImage] 이름).
  final String cat;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CatImage(cat, height: 72),
            const SizedBox(height: 4),
            V3Card(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                children: [
                  Text(title, style: text.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text(description, style: text.bodyLarge!.copyWith(color: context.wcColors.textMuted), textAlign: TextAlign.center),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
