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
      expect(Validators.newPassword('1234567'), isNotNull);
      expect(Validators.newPassword('12345678'), isNull);
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
