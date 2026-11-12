import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../core/validators.dart';
import '../../shared/widgets.dart';
import 'auth_providers.dart';
import 'auth_repository.dart';

/// Figma 1-2 회원가입.
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final result = await ref.read(authRepositoryProvider).signUp(email: _email.text, password: _password.text);
      if (!mounted) return;
      if (result == SignUpResult.needsEmailConfirmation) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증 메일을 보냈어요. 메일의 링크를 누른 뒤 로그인해 주세요.')),
        );
        context.go(Routes.login);
      }
      // signedIn이면 라우터가 인증 상태 변화를 받아 홈으로 보낸다.
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AutofillGroup(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              children: [
                Text('이메일로 가입하기', style: text.titleLarge),
                const SizedBox(height: 4),
                Text('학습 기록과 오답 노트가 계정에 저장돼요.', style: text.bodyLarge!.copyWith(color: context.wcColors.textMuted)),
                const SizedBox(height: 24),
                LabeledField(
                  label: '이메일',
                  hint: 'example@email.com',
                  controller: _email,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: '비밀번호',
                  hint: '${Validators.minPasswordLength}자 이상',
                  controller: _password,
                  validator: Validators.newPassword,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 14),
                LabeledField(
                  label: '비밀번호 확인',
                  hint: '비밀번호를 한 번 더 입력',
                  controller: _confirm,
                  validator: (v) => Validators.passwordConfirm(v, _password.text),
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[const SizedBox(height: 14), ErrorBox(_error!)],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting ? const ButtonSpinner() : const Text('가입하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
