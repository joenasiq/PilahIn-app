import 'package:flutter/material.dart';
import '../../../core/waste/waste_types.dart';

/// Model untuk data dampak lingkungan (Eco-Impact) dari jenis sampah tertentu.
class EcoImpact {
  final WasteType wasteType;
  final double co2SavedKg;
  final String primaryMetricLabel;
  final String primaryMetricValue;
  final IconData primaryMetricIcon;
  final String decompositionTime;
  final String environmentalEquivalence;
  final String actionTip;
  final String highlightFact;

  const EcoImpact({
    required this.wasteType,
    required this.co2SavedKg,
    required this.primaryMetricLabel,
    required this.primaryMetricValue,
    required this.primaryMetricIcon,
    required this.decompositionTime,
    required this.environmentalEquivalence,
    required this.actionTip,
    required this.highlightFact,
  });

  String get co2SavedFormatted => '${co2SavedKg.toStringAsFixed(2)} kg';
}

/// Menghitung / mengambil data dampak lingkungan spesifik untuk [WasteType].
EcoImpact getEcoImpactForWasteType(WasteType type) {
  switch (type) {
    case WasteType.plastic:
      return const EcoImpact(
        wasteType: WasteType.plastic,
        co2SavedKg: 0.09,
        primaryMetricLabel: 'Cegah Polusi Laut',
        primaryMetricValue: '1 Wadah',
        primaryMetricIcon: Icons.waves,
        decompositionTime: '450 Tahun',
        environmentalEquivalence: 'Mencegah pembentukan ribuan partikel mikroplastik berbahaya.',
        actionTip: 'Remas botol plastik dan kumpulkan untuk disetor ke Bank Sampah.',
        highlightFact: '1 kg daur ulang plastik menghemat setara 2 liter minyak bumi.',
      );

    case WasteType.biological:
      return const EcoImpact(
        wasteType: WasteType.biological,
        co2SavedKg: 0.12,
        primaryMetricLabel: 'Potensi Kompos',
        primaryMetricValue: '0.25 kg',
        primaryMetricIcon: Icons.eco,
        decompositionTime: '2 - 6 Minggu',
        environmentalEquivalence: 'Mengurangi gas metana (CH₄) di TPA yang 25x lebih merusak dari CO₂.',
        actionTip: 'Jadikan kompos rumah tangga atau masukkan ke lubang biopori.',
        highlightFact: 'Sampah organik terolah menyuburkan tanah tanpa bahan kimia buatan.',
      );

    case WasteType.paper:
      return const EcoImpact(
        wasteType: WasteType.paper,
        co2SavedKg: 0.14,
        primaryMetricLabel: 'Hemat Air Bersih',
        primaryMetricValue: '1.8 Liter',
        primaryMetricIcon: Icons.water_drop_outlined,
        decompositionTime: '2 - 6 Minggu',
        environmentalEquivalence: 'Menghemat energi setara pengisian penuh 12 baterai smartphone.',
        actionTip: 'Jaga kertas tetap kering dan bersih dari noda minyak agar mudah didaur ulang.',
        highlightFact: 'Serat kertas dapat didaur ulang hingga 5-7 kali menjadi produk baru.',
      );

    case WasteType.cardboard:
      return const EcoImpact(
        wasteType: WasteType.cardboard,
        co2SavedKg: 0.18,
        primaryMetricLabel: 'Lindungi Pohon',
        primaryMetricValue: 'Serat Kayu',
        primaryMetricIcon: Icons.forest_outlined,
        decompositionTime: '2 - 3 Bulan',
        environmentalEquivalence: 'Menyelamatkan pohon dari penebangan industri pulp dan kertas.',
        actionTip: 'Lipat kardus hingga pipih untuk menghemat ruang tempat penyimpanan.',
        highlightFact: 'Daur ulang 1 ton kardus menyelamatkan setara 17 pohon dewasa.',
      );

    case WasteType.metal:
      return const EcoImpact(
        wasteType: WasteType.metal,
        co2SavedKg: 0.45,
        primaryMetricLabel: 'Hemat Energi',
        primaryMetricValue: '95%',
        primaryMetricIcon: Icons.bolt,
        decompositionTime: '50 - 500 Tahun',
        environmentalEquivalence: '1 kaleng aluminium hemat energi menonton TV selama 3 jam.',
        actionTip: 'Bilas kaleng dari sisa minuman agar tidak mengundang semut dan bau.',
        highlightFact: 'Logam dapat didaur ulang selamanya tanpa kehilangan kualitas murninya.',
      );

    case WasteType.battery:
      return const EcoImpact(
        wasteType: WasteType.battery,
        co2SavedKg: 0.15,
        primaryMetricLabel: 'Air Tanah Aman',
        primaryMetricValue: '1.000 L',
        primaryMetricIcon: Icons.shield_outlined,
        decompositionTime: '100+ Thn (B3)',
        environmentalEquivalence: 'Mencegah merkuri, asam, dan kadmium meracuni ekosistem sumur warga.',
        actionTip: 'Tutup kutub baterai dengan selotip dan serahkan ke Drop Point E-Waste khusus.',
        highlightFact: '1 baterai kecil dapat mencemari ribuan liter air jika bocor di tanah.',
      );

    case WasteType.brownGlass:
    case WasteType.greenGlass:
    case WasteType.whiteGlass:
      return EcoImpact(
        wasteType: type,
        co2SavedKg: 0.20,
        primaryMetricLabel: 'Hemat Energi Kiln',
        primaryMetricValue: '30%',
        primaryMetricIcon: Icons.local_fire_department_outlined,
        decompositionTime: '1 Juta+ Thn',
        environmentalEquivalence: 'Kaca daur ulang meleleh di suhu lebih rendah, menghemat bahan bakar pabrik.',
        actionTip: 'Kumpulkan dalam wadah terpisah agar tidak pecah dan melukai petugas pemilah.',
        highlightFact: 'Kaca bersifat 100% sirkular dan tidak pernah membusuk di alam liar.',
      );

    case WasteType.clothes:
      return const EcoImpact(
        wasteType: WasteType.clothes,
        co2SavedKg: 0.35,
        primaryMetricLabel: 'Hemat Air Tekstil',
        primaryMetricValue: '2.700 L',
        primaryMetricIcon: Icons.water_drop,
        decompositionTime: '20 - 200 Thn',
        environmentalEquivalence: 'Menghindari polusi pewarna kimia limbah cair pabrik tekstil.',
        actionTip: 'Donasikan bila masih layak pakai, atau jadikan kain lap / kreasi upcycling.',
        highlightFact: 'Industri fashion adalah salah satu penyumbang emisi karbon terbesar dunia.',
      );

    case WasteType.shoes:
      return const EcoImpact(
        wasteType: WasteType.shoes,
        co2SavedKg: 0.28,
        primaryMetricLabel: 'Sol Karet Daur Ulang',
        primaryMetricValue: '0.3 kg',
        primaryMetricIcon: Icons.recycling,
        decompositionTime: '40 - 80 Tahun',
        environmentalEquivalence: 'Komponen sol karet dapat diproses menjadi bantalan lintasan lari.',
        actionTip: 'Perbaiki sol sepatu yang lepas ke pengrajin sebelum memutuskan membuang.',
        highlightFact: 'Sepatu terdiri dari berbagai material campuran yang sulit terurai di TPA.',
      );

    case WasteType.trash:
      return const EcoImpact(
        wasteType: WasteType.trash,
        co2SavedKg: 0.05,
        primaryMetricLabel: 'Pilah Residu Tepat',
        primaryMetricValue: 'Bebas Kontaminasi',
        primaryMetricIcon: Icons.delete_outline,
        decompositionTime: 'Bervariasi',
        environmentalEquivalence: 'Mencegah sampah daur ulang lain kotor dan rusak akibat residu.',
        actionTip: 'Bungkus residu rapat agar tidak berserakan dan mencemari lingkungan sekitar.',
        highlightFact: 'Dengan memilah residu, kamu mempermudah pekerjaan petugas kebersihan.',
      );
  }
}
