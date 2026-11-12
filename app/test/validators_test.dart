import 'package:flutter_test/flutter_test.dart';
import 'package:wordcross/core/validators.dart';

void main() {
  group('Validators.email', () {
    test('빈 값과 형식 오류를 거른다', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('   '), isNotNull);
      expect(Validators.email('no-at-sign'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
    });
    test('앞뒤 공백이 있어도 올바른 주소는 통과', () {
      expect(Validators.email(' user@example.com '), isNull);
    });
  });

  group('Validators.newPassword', () {
    test('8자 미만은 거른다', () {
      expect(Validators.newPassword('abc1234'), isNotNull);
      expect(Validators.newPassword('abcd1234'), isNull);
    });
    test('영문과 숫자가 모두 있어야 통과 (서버 letters_digits 규칙)', () {
      expect(Validators.newPassword('12345678'), isNotNull);
      expect(Validators.newPassword('abcdefgh'), isNotNull);
      expect(Validators.newPassword('Password1'), isNull);
    });
  });

  group('Validators.nickname', () {
    test('비었거나 20자를 넘으면 거른다', () {
      expect(Validators.nickname(''), isNotNull);
      expect(Validators.nickname('   '), isNotNull);
      expect(Validators.nickname('가' * 21), isNotNull);
      expect(Validators.nickname(' 민성 '), isNull);
      expect(Validators.nickname('가' * 20), isNull);
    });
  });

  group('Validators.passwordConfirm', () {
    test('비밀번호와 같아야 통과', () {
      expect(Validators.passwordConfirm('', 'abcdefgh'), isNotNull);
      expect(Validators.passwordConfirm('abcdefgx', 'abcdefgh'), isNotNull);
      expect(Validators.passwordConfirm('abcdefgh', 'abcdefgh'), isNull);
    });
  });
}
