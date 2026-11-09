import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/features/auth/presentation/auth_controller.dart';
import 'package:pilahin_app/features/auth/presentation/register_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferences> pumpRegisterScreen(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  Future<void> tapDaftar(WidgetTester tester) async {
    final button = find.widgetWithText(ElevatedButton, 'Daftar');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('RegisterScreen Widget Tests', () {
    testWidgets('menampilkan pesan error jika form kosong', (tester) async {
      await pumpRegisterScreen(tester);

      await tapDaftar(tester);

      expect(find.text('Nama wajib diisi'), findsOneWidget);
      expect(find.text('Email wajib diisi'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
      expect(find.text('Konfirmasi kata sandi wajib diisi'), findsOneWidget);
    });

    testWidgets('menampilkan format email tidak valid', (tester) async {
      await pumpRegisterScreen(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'Budi');
      await tester.enterText(find.byType(TextFormField).at(1), 'bukan-email');
      await tapDaftar(tester);

      expect(find.text('Format email tidak valid'), findsOneWidget);
    });

    testWidgets(
      'kata sandi kurang dari 8 karakter menampilkan pesan dan gagal daftar',
      (tester) async {
        final prefs = await pumpRegisterScreen(tester);

        await tester.enterText(find.byType(TextFormField).at(0), 'Budi');
        await tester.enterText(
          find.byType(TextFormField).at(1),
          'budi@email.com',
        );
        await tester.enterText(find.byType(TextFormField).at(2), '1234567');
        await tester.enterText(find.byType(TextFormField).at(3), '1234567');
        await tapDaftar(tester);

        // Pesan muncul di bawah field kata sandi.
        expect(find.text('Kata sandi minimal 8 karakter'), findsOneWidget);

        // Pendaftaran dibatalkan: akun tidak tersimpan dan sesi tidak dibuat.
        expect(prefs.getString(AppConstants.keyRegisteredAccounts), isNull);
        expect(prefs.getBool(AppConstants.keyUserSession), isNull);
      },
    );

    testWidgets('konfirmasi kata sandi tidak cocok ditolak', (tester) async {
      final prefs = await pumpRegisterScreen(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'Budi');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'budi@email.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'rahasia123');
      await tester.enterText(find.byType(TextFormField).at(3), 'rahasia456');
      await tapDaftar(tester);

      expect(find.text('Konfirmasi kata sandi tidak cocok'), findsOneWidget);
      expect(prefs.getString(AppConstants.keyRegisteredAccounts), isNull);
    });

    testWidgets('pendaftaran valid menyimpan akun dan membuat sesi', (
      tester,
    ) async {
      final prefs = await pumpRegisterScreen(tester);

      await tester.enterText(find.byType(TextFormField).at(0), 'Budi');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'budi@email.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'rahasia123');
      await tester.enterText(find.byType(TextFormField).at(3), 'rahasia123');
      await tapDaftar(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final stored = prefs.getString(AppConstants.keyRegisteredAccounts) ?? '';
      expect(stored, contains('budi@email.com'));
      expect(stored, isNot(contains('rahasia123')));
      expect(prefs.getBool(AppConstants.keyUserSession), isTrue);
      expect(prefs.getString(AppConstants.keyUserName), 'Budi');
    });
  });
}
