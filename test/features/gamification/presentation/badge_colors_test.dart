import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/features/gamification/domain/reference_data.dart';
import 'package:pilahin_app/features/gamification/presentation/badge_colors.dart';

void main() {
  group('badgeColorFor', () {
    test('setiap badge di kBadges punya warna gradient unik', () {
      final seen = <String>{};

      for (final def in kBadges) {
        final colors = badgeColorFor(def.code);
        expect(
          colors.start,
          isNot(colors.end),
          reason: 'gradient ${def.code} polos',
        );
        seen.add('${colors.start.toARGB32()}-${colors.end.toARGB32()}');
      }

      expect(seen.length, kBadges.length);
    });

    test('badge kategori sama tetap beda warna', () {
      // Kasus nyata: keduanya kategori 'umum' tapi tidak boleh tampak sama.
      final pemula = badgeColorFor('pemilah_pemula');
      final pejuang = badgeColorFor('pejuang_lingkungan');

      expect(pemula.start, isNot(pejuang.start));
      expect(pemula.end, isNot(pejuang.end));
    });

    test('badge id tak dikenal memakai fallback deterministik', () {
      final first = badgeColorFor('badge_baru_dari_backend');
      final second = badgeColorFor('badge_baru_dari_backend');

      expect(first.start, second.start);
      expect(first.end, second.end);
      expect(first.start, isNot(first.end));
    });

    test('badge login_streak_7 punya warna khusus', () {
      final colors = badgeColorFor('login_streak_7');

      expect(colors.start, isNot(colors.end));
    });
  });
}
