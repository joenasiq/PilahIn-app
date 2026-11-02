import 'package:flutter_test/flutter_test.dart';

import 'package:pilahin_app/core/db/password_hasher.dart';

void main() {
  group('password_hasher', () {
    test('hashPassword deterministik untuk email+password yang sama', () {
      final a = hashPassword('user@mail.com', 'rahasia123');
      final b = hashPassword('user@mail.com', 'rahasia123');
      expect(a, b);
      expect(a, isNotEmpty);
    });

    test('hash berbeda jika password berbeda', () {
      final a = hashPassword('user@mail.com', 'rahasia123');
      final b = hashPassword('user@mail.com', 'lainnya456');
      expect(a, isNot(b));
    });

    test('hash berbeda jika email berbeda (garam = email)', () {
      final a = hashPassword('user@mail.com', 'rahasia123');
      final b = hashPassword('lain@mail.com', 'rahasia123');
      expect(a, isNot(b));
    });

    test('hash tidak sensitif terhadap kapital/spasi pada email', () {
      final a = hashPassword('User@Mail.com ', 'rahasia123');
      final b = hashPassword('user@mail.com', 'rahasia123');
      expect(a, b);
    });

    test('verifyPassword benar/salah', () {
      final hash = hashPassword('user@mail.com', 'rahasia123');
      expect(verifyPassword('user@mail.com', 'rahasia123', hash), isTrue);
      expect(verifyPassword('user@mail.com', 'salah', hash), isFalse);
    });
  });
}
