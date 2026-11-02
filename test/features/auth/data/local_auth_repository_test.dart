import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/core/db/password_hasher.dart';
import 'package:pilahin_app/core/db/users_repository.dart';
import 'package:pilahin_app/features/auth/data/local_auth_repository.dart';

/// Fake in-memory [UsersRepository] untuk menguji logika [LocalAuthRepository]
/// TANPA menyentuh SQLite nyata (lingkungan test host tidak perlu native asset).
///
/// Disiisi user tamu + akun demo (hash dibuat dengan [hashPassword] sungguhan).
class FakeUsersRepository implements UsersRepository {
  final Map<String, DbUser> _byId = {};

  FakeUsersRepository() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _byId[UsersRepository.guestId] = const DbUser(
      id: UsersRepository.guestId,
      displayName: 'Tamu',
      isGuest: true,
      totalPoints: 0,
      currentStreak: 0,
      bestStreak: 0,
      createdAt: 0,
      updatedAt: 0,
    );
    _byId['user_1'] = DbUser(
      id: 'user_1',
      email: AppConstants.demoEmail.trim().toLowerCase(),
      passwordHash: hashPassword(AppConstants.demoEmail, AppConstants.demoPassword),
      displayName: AppConstants.demoDisplayName,
      isGuest: false,
      totalPoints: 0,
      currentStreak: 0,
      bestStreak: 0,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<DbUser?> findById(String id) async => _byId[id];

  @override
  Future<DbUser?> findByEmail(String email) async {
    final clean = email.trim().toLowerCase();
    for (final user in _byId.values) {
      if (user.email?.toLowerCase() == clean) return user;
    }
    return null;
  }

  @override
  Future<DbUser> getOrCreateGuest() async => _byId[UsersRepository.guestId]!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalAuthRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    repository = LocalAuthRepository(prefs, FakeUsersRepository());
  });

  group('LocalAuthRepository Tests', () {
    test('login dengan kredensial benar mengembalikan AppUser', () async {
      final user = await repository
          .login(AppConstants.demoEmail, AppConstants.demoPassword);

      expect(user.email, AppConstants.demoEmail);
      expect(user.displayName, AppConstants.demoDisplayName);
      expect(user.isGuest, false);

      final currentUser = await repository.getCurrentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!.email, AppConstants.demoEmail);
    });

    test('login dengan email tidak terdaftar melempar Exception kombinasi',
        () async {
      expect(
        () => repository.login('salah@email.com', 'salah123'),
        throwsA(
          predicate((e) => e.toString().contains('Email dan kata sandi salah')),
        ),
      );
    });

    test(
        'login dengan email terdaftar dan password salah melempar Exception Kata sandi salah',
        () async {
      expect(
        () => repository.login(AppConstants.demoEmail, 'salah123'),
        throwsA(predicate((e) => e.toString().contains('Kata sandi salah'))),
      );
    });

    test('loginAsGuest mengembalikan user tamu', () async {
      final user = await repository.loginAsGuest();

      expect(user.isGuest, true);
      expect(user.displayName, 'Tamu');

      final currentUser = await repository.getCurrentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!.isGuest, true);
    });

    test('logout menghapus sesi', () async {
      await repository.loginAsGuest();
      expect(await repository.getCurrentUser(), isNotNull);

      await repository.logout();
      expect(await repository.getCurrentUser(), isNull);
    });
  });
}
