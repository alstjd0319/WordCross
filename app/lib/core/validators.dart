/// 입력값 검사. 통과하면 null, 아니면 화면에 보여 줄 오류 문구를 돌려준다.
abstract final class Validators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const minPasswordLength = 8;
  static const maxNicknameLength = 20;
  static final _letter = RegExp(r'[A-Za-z]');
  static final _digit = RegExp(r'[0-9]');

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
    // 서버(Supabase Auth)의 비밀번호 규칙 'letters_digits'와 같아야 한다.
    if (!_letter.hasMatch(value) || !_digit.hasMatch(value)) return '영문과 숫자를 함께 넣어 주세요.';
    return null;
  }

  /// DB profiles.nickname 은 1~20자.
  static String? nickname(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '닉네임을 입력해 주세요.';
    if (v.length > maxNicknameLength) return '닉네임은 $maxNicknameLength자 이하로 해 주세요.';
    return null;
  }

  static String? passwordConfirm(String? value, String password) {
    if (value == null || value.isEmpty) return '비밀번호를 한 번 더 입력해 주세요.';
    if (value != password) return '비밀번호가 서로 달라요.';
    return null;
  }
}
