import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pilahin_app/core/waste/waste_types.dart';
import 'package:pilahin_app/features/result/domain/eco_impact.dart';
import 'package:pilahin_app/features/result/presentation/widgets/eco_impact_card.dart';
import 'package:pilahin_app/features/result/presentation/widgets/point_reward_dialog.dart';
import 'package:pilahin_app/features/result/presentation/widgets/animated_reward_badge.dart';

void main() {
  group('EcoImpact Domain Tests', () {
    test('Setiap WasteType memiliki data EcoImpact yang valid', () {
      for (final type in WasteType.values) {
        final impact = getEcoImpactForWasteType(type);
        expect(impact.wasteType, type);
        expect(impact.co2SavedKg, greaterThan(0));
        expect(impact.co2SavedFormatted, contains('kg'));
        expect(impact.primaryMetricLabel.isNotEmpty, isTrue);
        expect(impact.primaryMetricValue.isNotEmpty, isTrue);
        expect(impact.decompositionTime.isNotEmpty, isTrue);
        expect(impact.environmentalEquivalence.isNotEmpty, isTrue);
        expect(impact.actionTip.isNotEmpty, isTrue);
        expect(impact.highlightFact.isNotEmpty, isTrue);
      }
    });
  });

  group('EcoImpactCard Widget Tests', () {
    testWidgets('Menampilkan komponen EcoImpactCard untuk plastik', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EcoImpactCard(wasteType: WasteType.plastic),
          ),
        ),
      );

      expect(find.text('ECO-IMPACT'), findsOneWidget);
      expect(find.text('Dampak Nyata Pemilahanmu'), findsOneWidget);
      expect(find.text('Jejak Karbon'), findsOneWidget);
      expect(find.text('-0.09 kg'), findsOneWidget);
      expect(find.text('Cegah Polusi Laut'), findsOneWidget);
      expect(find.text('450 Tahun'), findsOneWidget);
      expect(find.text('Tahukah Kamu?'), findsOneWidget);
    });

    testWidgets('Menampilkan komponen EcoImpactCard untuk biologis', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EcoImpactCard(wasteType: WasteType.biological),
          ),
        ),
      );

      expect(find.text('Potensi Kompos'), findsOneWidget);
      expect(find.text('-0.12 kg'), findsOneWidget);
      expect(find.text('2 - 6 Minggu'), findsOneWidget);
    });
  });

  group('AnimatedRewardBadge & PointRewardDialog Tests', () {
    testWidgets('AnimatedRewardBadge menampilkan teks reward dan dapat diklik', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedRewardBadge(points: 15),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('+15 Poin Pemindaian'), findsOneWidget);

      // Tap badge membuka dialog
      await tester.tap(find.byType(AnimatedRewardBadge));
      await tester.pumpAndSettle();

      expect(find.byType(PointRewardDialog), findsOneWidget);
      expect(find.text('Luar Biasa!'), findsOneWidget);
      expect(find.text('+15 Poin'), findsOneWidget);
      expect(find.text('Lihat Dampak Lingkungan 🌱'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Lihat Dampak Lingkungan 🌱'));
      await tester.pumpAndSettle();
      expect(find.byType(PointRewardDialog), findsNothing);
    });
  });
}
