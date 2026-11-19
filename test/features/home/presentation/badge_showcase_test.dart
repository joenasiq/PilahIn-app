import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilahin_app/features/auth/presentation/auth_controller.dart';
import 'package:pilahin_app/features/gamification/domain/badge.dart';
import 'package:pilahin_app/features/gamification/domain/gamification_repository.dart';
import 'package:pilahin_app/features/gamification/domain/mission.dart';
import 'package:pilahin_app/features/gamification/presentation/gamification_provider.dart';
import 'package:pilahin_app/features/home/presentation/widgets/badge_showcase.dart';

/// Repository dengan daftar badge yang bisa diatur per test.
class _FakeGamificationRepository implements GamificationRepository {
  _FakeGamificationRepository(this._badges);

  final List<AppBadge> _badges;

  @override
  Future<List<AppBadge>> getBadges() async => _badges;

  @override
  Future<List<Mission>> getMissions() async => const [];
}

AppBadge _badge({
  required String id,
  required String nama,
  required String iconKey,
  required int progres,
  required int target,
}) {
  return AppBadge(
    id: id,
    nama: nama,
    deskripsi: 'Deskripsi $nama',
    kategori: 'umum',
    iconKey: iconKey,
    progres: progres,
    target: target,
    satuan: 'pemindaian',
    tanggalDiraih: progres >= target ? DateTime(2026, 9, 10) : null,
    hadiahPoin: 20,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Widget> wrap(GamificationRepository repo) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentUserIdProvider.overrideWithValue('user_1'),
        gamificationRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: BadgeShowcase(),
          ),
        ),
      ),
    );
  }

  testWidgets('hanya menampilkan badge yang sudah terbuka', (tester) async {
    final repo = _FakeGamificationRepository([
      _badge(
        id: '1',
        nama: 'Pahlawan Hijau',
        iconKey: 'eco',
        progres: 10,
        target: 10,
      ),
      _badge(
        id: '2',
        nama: 'Master Kompos',
        iconKey: 'compost',
        progres: 32,
        target: 50,
      ),
      _badge(
        id: '3',
        nama: 'Pemilah Pemula',
        iconKey: 'star',
        progres: 1,
        target: 1,
      ),
    ]);

    await tester.pumpWidget(await wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Lencana Saya'), findsOneWidget);
    expect(find.text('2 dari 3 badge terbuka'), findsOneWidget);
    expect(find.text('Pahlawan Hijau'), findsOneWidget);
    expect(find.text('Pemilah Pemula'), findsOneWidget);
    // Badge terkunci tidak ikut ditampilkan di beranda.
    expect(find.text('Master Kompos'), findsNothing);
    expect(find.byIcon(Icons.eco), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
  });

  testWidgets('mengetuk badge membuka detail badge', (tester) async {
    final repo = _FakeGamificationRepository([
      _badge(
        id: '1',
        nama: 'Pahlawan Hijau',
        iconKey: 'eco',
        progres: 10,
        target: 10,
      ),
    ]);

    await tester.pumpWidget(await wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pahlawan Hijau'));
    await tester.pumpAndSettle();

    expect(find.text('Detail Badge'), findsOneWidget);
    expect(find.text('Terbuka'), findsOneWidget);
  });

  testWidgets('empty state tampil bila belum ada badge terbuka', (
    tester,
  ) async {
    final repo = _FakeGamificationRepository([
      _badge(
        id: '2',
        nama: 'Master Kompos',
        iconKey: 'compost',
        progres: 0,
        target: 50,
      ),
    ]);

    await tester.pumpWidget(await wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('0 dari 1 badge terbuka'), findsOneWidget);
    expect(
      find.textContaining('Belum ada lencana'),
      findsOneWidget,
    );
    expect(find.text('Mulai Pindai'), findsOneWidget);
  });
}
