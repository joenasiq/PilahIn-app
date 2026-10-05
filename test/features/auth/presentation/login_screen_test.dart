import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilahin_app/features/auth/presentation/login_screen.dart';
import 'package:pilahin_app/features/auth/presentation/auth_controller.dart';
import 'package:pilahin_app/core/widgets/primary_button.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpLoginScreen(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );
  }

  group('LoginScreen Widget Tests', () {
    testWidgets('menampilkan pesan error jika form kosong saat disubmit', (tester) async {
      await pumpLoginScreen(tester);
      await tester.pumpAndSettle();
      
      await tester.ensureVisible(find.text('Masuk'));
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();
      
      expect(find.text('Email wajib diisi'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
    });

    testWidgets('menampilkan error format email salah', (tester) async {
      await pumpLoginScreen(tester);
      await tester.pumpAndSettle();
      
      // Isi email salah
      await tester.enterText(find.byType(TextFormField).first, 'emailsalah');
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      
      expect(find.text('Format email tidak valid'), findsOneWidget);
    });

    testWidgets('menampilkan error password kurang dari 6 karakter', (tester) async {
      await pumpLoginScreen(tester);
      await tester.pumpAndSettle();
      
      // Isi email benar, password kurang dari 6
      await tester.enterText(find.byType(TextFormField).first, 'test@email.com');
      await tester.enterText(find.byType(TextFormField).last, '12345');
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      
      expect(find.text('Kata sandi minimal 6 karakter'), findsOneWidget);
    });
  });
}
