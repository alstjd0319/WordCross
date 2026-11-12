import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';

/// Figma의 TextField 컴포넌트: 위에 라벨, 아래에 입력 상자.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final String? hint;
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
          decoration: InputDecoration(hintText: hint),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(10)),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: scheme.error)),
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
  const ComingSoon({super.key, required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primaryContainer,
              child: Icon(icon, size: 30, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(description, style: text.bodyLarge!.copyWith(color: context.wcColors.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
