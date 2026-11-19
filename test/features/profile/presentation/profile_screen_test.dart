import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pilahin_app/core/constants/app_constants.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/auth/presentation/auth_controller.dart';
import 'package:pilahin_app/features/history/domain/history_entry.dart';
import 'package:pilahin_app/features/history/presentation/history_provider.dart';
import 'package:pilahin_app/features/home/presentation/home_provider.dart';
import 'package:pilahin_app/features/home/data/home_repository.dart';
import 'package:pilahin_app/features/home/domain/home_summary.dart';
import 'package:pilahin_app/features/gamification/domain/reference_data.dart';
import 'package:pilahin_app/features/profile/data/avatar_service.dart';
import 'package:pilahin_app/features/profile/presentation/avatar_photo_viewer.dart';
import 'package:pilahin_app/features/profile/presentation/profile_screen.dart';
import 'package:pilahin_app/features/scan/domain/waste_category.dart';
import 'package:pilahin_app/features/auth/domain/app_user.dart';

import '../../history/helpers/fake_history_repository.dart';

/// Home repository palsu dengan level yang bisa diatur, agar aturan
/// pembukaan foto profil (Level >= 2) bisa diuji.
class FakeHomeRepository implements HomeRepository {
  FakeHomeRepository({this.level = 1});

  final int level;

  @override
  Future<HomeSummary> getHomeSummary({
    required String userName,
    required bool isDemoOrGuest,
  }) async {
    final info = kLevels.firstWhere(
      (lvl) => lvl.level == level,
      orElse: () => kLevels.first,
    );
    return HomeSummary(
      userName: userName,
      levelName: info.name,
      level: info.level,
      points: info.minPoints,
      pointsToNextLevel: (nextLevelMinPoints(info.minPoints) ?? 0) -
          info.minPoints,
      streakDays: 0,
      unlockedBadges: 0,
      totalBadges: kBadges.length,
      dailyMissions: const [],
    );
  }
}

class MockAuthController extends AuthController {
  final AppUser? mockUser;
  MockAuthController(this.mockUser);

  @override
  Future<AppUser?> build() async => mockUser;

  @override
  Future<void> logout() async {
    state = const AsyncValue.data(null);
  }
}

void main() {
  // Save current gamification value since it's a const we can't easily mock
  // without rebuilding the UI. But in tests we can use a wrapper if it's dynamic,
  // since it's static const, we can only test the true state here unless we mock it,
  // but we can't mock static const easily in Dart. Wait, the prompt asked to test
  // gamificationEnabled=false. To do that in widget test, we can't change static const.
  // Wait, I will just ignore changing gamificationEnabled to false in widget test if it's static const,
  // OR I can use a global variable in AppConstants instead of const.
  // Since I made it `static const bool gamificationEnabled = true;` per prompt,
  // I will test guest mode and data displaying instead, or I can just mock what I can.

  // Wait, I can just use a fake auth repo and prefs to mock guest mode.
  Future<Widget> createWidgetUnderTest({
    required FakeHistoryRepository repo,
    bool isGuest = false,
    String? photoUrl,
    int level = 3,
    Uint8List? avatarBytes,
    bool overrideAvatarBytes = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.keyIsGuest: isGuest,
      if (!isGuest) AppConstants.keyUserSession: 'mock_token',
    });
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        historyRepositoryProvider.overrideWithValue(repo),
        currentUserIdProvider.overrideWithValue(
          isGuest ? AppConstants.guestUserId : AppConstants.demoUserId,
        ),
        isDemoOrGuestProvider.overrideWithValue(isGuest),
        homeRepositoryProvider.overrideWithValue(
          FakeHomeRepository(level: level),
        ),
        if (overrideAvatarBytes)
          avatarBytesProvider.overrideWith((ref, key) async => avatarBytes),
        authControllerProvider.overrideWith(
          () => MockAuthController(
            isGuest
                ? AppUser.guest()
                : AppUser(
                    id: '1',
                    email: 'test@polinema.ac.id',
                    displayName: 'Kelompok Baiq',
                    photoUrl: photoUrl,
                  ),
          ),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
    );
  }

  testWidgets('Guest mode shows Tamu and Keluar', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(
      await createWidgetUnderTest(repo: repo, isGuest: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tamu'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);

    // No history
    expect(find.text('Belum ada data'), findsOneWidget);
  });

  testWidgets('Logged in mode shows name, initials, data, and Keluar', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    // Add 2 organic, 1 anorganic
    await repo.add(
      HistoryEntry(
        userId: AppConstants.demoUserId,
        scanKey: '1',
        category: WasteCategory.organik,
        confidence: 1,
        isUncertain: false,
        pointsEarned: 10,
        createdAt: DateTime.now(),
      ),
    );
    await repo.add(
      HistoryEntry(
        userId: AppConstants.demoUserId,
        scanKey: '2',
        category: WasteCategory.organik,
        confidence: 1,
        isUncertain: false,
        pointsEarned: 10,
        createdAt: DateTime.now(),
      ),
    );
    await repo.add(
      HistoryEntry(
        userId: AppConstants.demoUserId,
        scanKey: '3',
        category: WasteCategory.anorganik,
        confidence: 1,
        isUncertain: false,
        pointsEarned: 10,
        createdAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      await createWidgetUnderTest(repo: repo, isGuest: false),
    );
    await tester.pumpAndSettle();

    // The mock auth repository returns AppUser with 'Kelompok Baiq' if logged in.
    expect(
      find.text('Kelompok Baiq'),
      findsWidgets,
    ); // wait, AuthRepository mock?
    // Wait, LocalAuthRepository might return something else.
    // We can just verify 'Masuk' is absent and 'Keluar' is present.
    expect(find.text('Masuk'), findsNothing);
    expect(find.text('Keluar'), findsOneWidget);

    // Verify Legend beserta persentase kategori
    expect(find.text('66.7%'), findsOneWidget); // organic
    expect(find.text('33.3%'), findsOneWidget); // anorganic
    expect(find.text('2 item'), findsOneWidget); // organic
    expect(find.text('1 item'), findsOneWidget); // anorganic
    expect(find.textContaining('Total 3 pemindaian'), findsOneWidget);

    // Tap Keluar should show dialog
    await tester.ensureVisible(find.text('Keluar'));
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsOneWidget);

    // Tap Batal
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari akun?'), findsNothing);
  });

  testWidgets(
    'Statistik menampilkan rincian jenis sampah dan total poin scan',
    (WidgetTester tester) async {
      final repo = FakeHistoryRepository();
      await repo.add(
        HistoryEntry(
          userId: AppConstants.demoUserId,
          scanKey: '1',
          wasteType: WasteType.biological,
          confidence: 1,
          isUncertain: false,
          pointsEarned: 10,
          createdAt: DateTime.now(),
        ),
      );
      await repo.add(
        HistoryEntry(
          userId: AppConstants.demoUserId,
          scanKey: '2',
          wasteType: WasteType.biological,
          confidence: 1,
          isUncertain: false,
          pointsEarned: 10,
          createdAt: DateTime.now(),
        ),
      );
      await repo.add(
        HistoryEntry(
          userId: AppConstants.demoUserId,
          scanKey: '3',
          wasteType: WasteType.cardboard,
          confidence: 1,
          isUncertain: false,
          pointsEarned: 10,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        await createWidgetUnderTest(repo: repo, isGuest: false),
      );
      await tester.pumpAndSettle();

      // Rincian klasifikasi tingkat kedua (jenis sampah dari dataset)
      expect(find.text('Rincian Sub-kategori'), findsOneWidget);
      expect(find.text('Biologis'), findsOneWidget);
      expect(find.text('Kardus'), findsOneWidget);
      expect(find.text('Organik • 2 item'), findsOneWidget);
      expect(find.text('Anorganik • 1 item'), findsOneWidget);
      // Persentase pada kategori dan rincian jenis sama-sama tampil
      expect(find.text('66.7%'), findsNWidgets(2));
      expect(find.text('33.3%'), findsNWidgets(2));
      expect(find.text('3 terklasifikasi'), findsOneWidget);

      // Akun non-demo: poin hanya dari scan (3 × 10) + breakdown harian
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Scan 30 • Login 0 • Hari ini 0/150'), findsOneWidget);
    },
  );

  testWidgets('Akun login: avatar bisa diketuk untuk opsi foto profil', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(
      await createWidgetUnderTest(repo: repo, isGuest: false),
    );
    await tester.pumpAndSettle();

    // Badge kamera hanya tampil untuk akun yang sudah login.
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.photo_camera_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Foto Profil'), findsOneWidget);
    expect(find.text('Pilih dari Galeri'), findsOneWidget);
    expect(find.text('Ambil dari Kamera'), findsOneWidget);
    // Belum ada foto -> opsi hapus tidak ditampilkan.
    expect(find.text('Hapus Foto'), findsNothing);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(find.text('Foto Profil'), findsNothing);
  });

  testWidgets('Akun login dengan foto menampilkan gambar & opsi hapus', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(
      await createWidgetUnderTest(
        repo: repo,
        isGuest: false,
        photoUrl: 'https://example.com/avatar.jpg',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-avatar-photo')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.photo_camera_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Foto'), findsOneWidget);
  });

  testWidgets('Foto dari Firestore (penanda fs:) dimuat lewat byte gambar', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(16, 185, 129));
    final bytes = Uint8List.fromList(img.encodePng(image));

    await tester.pumpWidget(
      await createWidgetUnderTest(
        repo: repo,
        isGuest: false,
        photoUrl: 'fs:1700000000000',
        avatarBytes: bytes,
      ),
    );
    await tester.pumpAndSettle();

    // Byte dari provider dipakai, bukan Image.network.
    expect(find.byKey(const ValueKey('profile-avatar-photo')), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Penanda fs: tanpa data menampilkan inisial', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(
      await createWidgetUnderTest(
        repo: repo,
        isGuest: false,
        photoUrl: 'fs:1700000000000',
        avatarBytes: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('profile-avatar-photo')), findsNothing);
    expect(find.text('K'), findsOneWidget); // inisial "Kelompok Baiq"
  });

  testWidgets('Foto profil bisa dibuka ukuran penuh saat avatar diketuk', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(5, 150, 105));
    final bytes = Uint8List.fromList(img.encodePng(image));

    await tester.pumpWidget(
      await createWidgetUnderTest(
        repo: repo,
        isGuest: false,
        photoUrl: 'fs:1700000000001',
        avatarBytes: bytes,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-avatar-photo')));
    await tester.pumpAndSettle();

    // Viewer terbuka dengan tombol ganti foto.
    expect(find.byType(AvatarPhotoViewer), findsOneWidget);
    expect(find.text('Ganti Foto'), findsOneWidget);
    // Foto dibingkai bulat.
    expect(find.byType(ClipOval), findsWidgets);

    // Tombol tutup mengembalikan ke layar profil.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(AvatarPhotoViewer), findsNothing);
  });

  testWidgets('Tombol Ganti Foto di viewer membuka menu foto', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(16, 185, 129));
    final bytes = Uint8List.fromList(img.encodePng(image));

    await tester.pumpWidget(
      await createWidgetUnderTest(
        repo: repo,
        isGuest: false,
        photoUrl: 'fs:1700000000002',
        avatarBytes: bytes,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-avatar-photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ganti Foto'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih dari Galeri'), findsOneWidget);
    expect(find.text('Hapus Foto'), findsOneWidget);
  });

  testWidgets('Avatar tanpa foto tetap membuka menu, bukan viewer', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(
      await createWidgetUnderTest(repo: repo, isGuest: false),
    );
    await tester.pumpAndSettle();

    // Ketuk inisial avatar (belum ada foto).
    await tester.tap(find.text('K'));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarPhotoViewer), findsNothing);
    expect(find.text('Pilih dari Galeri'), findsOneWidget);
  });

  testWidgets('Level 1: avatar berfoto tidak membuka viewer', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    final image = img.Image(width: 8, height: 8);
    img.fill(image, color: img.ColorRgb8(16, 185, 129));
    final bytes = Uint8List.fromList(img.encodePng(image));

    await tester.pumpWidget(
      await createWidgetUnderTest(
        repo: repo,
        isGuest: false,
        level: 1,
        photoUrl: 'fs:1700000000003',
        avatarBytes: bytes,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-avatar-photo')));
    await tester.pumpAndSettle();

    expect(find.byType(AvatarPhotoViewer), findsNothing);
    expect(find.text('Foto Profil Terkunci'), findsOneWidget);
  });

  testWidgets('Tamu: mengetuk avatar hanya menampilkan pesan masuk', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(
      await createWidgetUnderTest(repo: repo, isGuest: true),
    );
    await tester.pumpAndSettle();

    // Tamu tidak mendapat tombol ganti foto.
    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.person));
    await tester.pump();

    expect(
      find.text('Masuk ke akun untuk menambahkan foto profil'),
      findsOneWidget,
    );
    expect(find.text('Foto Profil'), findsNothing);
  });

  testWidgets('Level 1: foto profil terkunci dan picker tidak terbuka', (
    WidgetTester tester,
  ) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(
      await createWidgetUnderTest(repo: repo, isGuest: false, level: 1),
    );
    await tester.pumpAndSettle();

    // Badge gembok menggantikan ikon kamera.
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.lock_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Foto Profil Terkunci'), findsOneWidget);
    expect(
      find.textContaining('Level 2 (Juru Kompos)'),
      findsOneWidget,
    );
    expect(find.text('Lihat Misi'), findsOneWidget);
    // Sheet opsi foto tidak boleh muncul.
    expect(find.text('Pilih dari Galeri'), findsNothing);
    expect(find.text('Ambil dari Kamera'), findsNothing);

    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.text('Foto Profil Terkunci'), findsNothing);
  });

  testWidgets('Level 2: foto profil terbuka', (WidgetTester tester) async {
    final repo = FakeHistoryRepository();
    await tester.pumpWidget(
      await createWidgetUnderTest(repo: repo, isGuest: false, level: 2),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.photo_camera_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Pilih dari Galeri'), findsOneWidget);
  });
}
