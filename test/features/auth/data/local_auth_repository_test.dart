import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/features/auth/data/local_auth_repository.dart';

void main() {
  late LocalAuthRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    repository = LocalAuthRepository(prefs);
  });

  group('LocalAuthRepository Tests', () {
    test('login dengan kredensial benar mengembalikan AppUser', () async {
      final user = await repository.login(AppConstants.demoEmail, AppConstants.demoPassword);
      
      expect(user.email, AppConstants.demoEmail);
      expect(user.displayName, AppConstants.demoDisplayName);
      expect(user.isGuest, false);
      
      final currentUser = await repository.getCurrentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!.email, AppConstants.demoEmail);
    });

    test('login dengan email dan kata sandi salah melempar Exception yang sesuai', () async {
      expect(
        () => repository.login('salah@email.com', 'salah123'),
        throwsA(predicate((e) => e.toString().contains('Email dan kata sandi salah'))),
      );
    });

    test('login dengan email salah dan password benar melempar Exception Email salah', () async {
      expect(
        () => repository.login('salah@email.com', AppConstants.demoPassword),
        throwsA(predicate((e) => e.toString().contains('Email salah'))),
      );
    });

    test('login dengan email benar dan password salah melempar Exception Kata sandi salah', () async {
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
