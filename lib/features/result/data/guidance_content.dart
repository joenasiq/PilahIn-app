import '../../scan/domain/waste_category.dart';

class WasteGuidance {
  final String title;
  final String description;
  final List<String> summaryPoints;
  final List<String> steps;
  final List<String> doList;
  final List<String> dontList;

  const WasteGuidance({
    required this.title,
    required this.description,
    required this.summaryPoints,
    required this.steps,
    required this.doList,
    required this.dontList,
  });
}

// Teks adalah konten awal, warna tempat sampah perlu dikonfirmasi nanti.
class GuidanceContent {
  static const WasteGuidance organic = WasteGuidance(
    title: 'Sampah Organik',
    description: 'Sampah yang mudah terurai secara alami. Dapat diolah menjadi kompos.',
    summaryPoints: [
      'Masukkan ke tempat sampah hijau.',
      'Dapat diolah menjadi pupuk kompos organik.',
      'Hindari pencampuran dengan kemasan plastik.',
    ],
    steps: [
      'Pisahkan dari plastik',
      'Potong kecil agar cepat terurai',
      'Campurkan dengan daun kering dalam komposter',
    ],
    doList: [
      'Potong kecil-kecil',
      'Campur dengan daun kering',
    ],
    dontList: [
      'Campur dengan plastik',
      'Buang ke saluran air',
    ],
  );

  static const WasteGuidance inorganic = WasteGuidance(
    title: 'Sampah Anorganik',
    description: 'Sampah yang sulit terurai dan banyak yang dapat didaur ulang.',
    summaryPoints: [
      'Masukkan ke tempat sampah kuning.',
      'Bersihkan dan keringkan sebelum dibuang atau didaur ulang.',
      'Hindari pencampuran dengan sisa makanan.',
    ],
    steps: [
      'Pisahkan dari sampah organik',
      'Bilas dan keringkan',
      'Serahkan ke bank sampah atau tempat daur ulang',
    ],
    doList: [
      'Bilas dan keringkan',
      'Kumpulkan untuk bank sampah',
    ],
    dontList: [
      'Membakar sampah',
      'Mencampur dengan sisa makanan',
    ],
  );

  static WasteGuidance getGuidance(WasteCategory category) {
    return category == WasteCategory.organik ? organic : inorganic;
  }
}
