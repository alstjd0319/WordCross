/// 입력값 검사. 통과하면 null, 아니면 화면에 보여 줄 오류 문구를 돌려준다.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const minPasswordLength = 8;

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '이메일을 입력해 주세요.';
    if (!_email.hasMatch(v)) return '이메일 형식이 맞지 않아요.';
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해 주세요.';
    return null;
  }

  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해 주세요.';
    if (value.length < minPasswordLength) return '비밀번호는 $minPasswordLength자 이상이어야 해요.';
    return null;
  }

  static String? passwordConfirm(String? value, String password) {
    if (value == null || value.isEmpty) return '비밀번호를 한 번 더 입력해 주세요.';
    if (value != password) return '비밀번호가 서로 달라요.';
    return null;
  }
}
