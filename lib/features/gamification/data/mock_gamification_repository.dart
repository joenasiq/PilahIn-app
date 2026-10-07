import '../domain/gamification_repository.dart';
import '../domain/mission.dart';
import '../domain/badge.dart';

// Kelas ini merupakan contoh data sementara
class MockGamificationRepository implements GamificationRepository {
  @override
  Future<List<Mission>> getMissions() async {
    return [
      Mission(
        id: '1',
        judul: 'Deteksi 10 Botol Plastik',
        progres: 7,
        target: 10,
        satuan: 'Botol',
        hadiahPoin: 50,
        periode: 'mingguan',
        status: 'berjalan',
      ),
      Mission(
        id: '2',
        judul: 'Pindai Kulit Pisang Pertama',
        progres: 1,
        target: 1,
        satuan: 'Sampah',
        hadiahPoin: 15,
        periode: 'harian',
        status: 'selesai-diklaim',
      ),
    ];
  }

  @override
  Future<List<AppBadge>> getBadges() async {
    return [
      // 6 unlocked
      AppBadge(id: '1', nama: 'Pahlawan Hijau', deskripsi: 'Mulai memilah sampah organik', kategori: 'organik', iconKey: 'eco', progres: 10, target: 10, satuan: 'organik', tanggalDiraih: DateTime(2026, 9, 12), hadiahPoin: 100),
      AppBadge(id: '2', nama: 'Pemilah Pemula', deskripsi: '1 pemindaian pertama', kategori: 'umum', iconKey: 'star', progres: 1, target: 1, satuan: 'pemindaian', tanggalDiraih: DateTime(2026, 9, 10), hadiahPoin: 20),
      AppBadge(id: '3', nama: 'Api Semangat', deskripsi: '7 hari beruntun', kategori: 'streak', iconKey: 'local_fire_department', progres: 7, target: 7, satuan: 'hari', tanggalDiraih: DateTime(2026, 9, 14), hadiahPoin: 50),
      AppBadge(id: '4', nama: 'Raja Botol', deskripsi: '10 botol plastik terdeteksi', kategori: 'anorganik', iconKey: 'water_drop', progres: 10, target: 10, satuan: 'botol', tanggalDiraih: DateTime(2026, 9, 15), hadiahPoin: 80),
      AppBadge(id: '5', nama: 'Pengumpul Kertas', deskripsi: '20 kertas terdeteksi', kategori: 'anorganik', iconKey: 'article', progres: 25, target: 20, satuan: 'kertas', tanggalDiraih: DateTime(2026, 9, 16), hadiahPoin: 60),
      AppBadge(id: '6', nama: 'Pejuang Lingkungan', deskripsi: '50 total pemindaian', kategori: 'umum', iconKey: 'public', progres: 55, target: 50, satuan: 'pemindaian', tanggalDiraih: DateTime(2026, 9, 18), hadiahPoin: 200),
      
      // 9 locked
      AppBadge(id: '7', nama: 'Master Kompos', deskripsi: 'Pilah 50 sampah organik untuk membuka badge ini.', kategori: 'organik', iconKey: 'compost', progres: 32, target: 50, satuan: 'organik', hadiahPoin: 100),
      AppBadge(id: '8', nama: 'Dewa Daur Ulang', deskripsi: 'Pilah 100 sampah anorganik', kategori: 'anorganik', iconKey: 'recycling', progres: 45, target: 100, satuan: 'anorganik', hadiahPoin: 150),
      AppBadge(id: '9', nama: 'Legenda Streak', deskripsi: '30 hari beruntun', kategori: 'streak', iconKey: 'local_fire_department', progres: 7, target: 30, satuan: 'hari', hadiahPoin: 300),
      AppBadge(id: '10', nama: 'Penyelamat Bumi', deskripsi: '500 total pemindaian', kategori: 'umum', iconKey: 'language', progres: 55, target: 500, satuan: 'pemindaian', hadiahPoin: 500),
      AppBadge(id: '11', nama: 'Ksatria Kaca', deskripsi: '20 pecahan kaca', kategori: 'anorganik', iconKey: 'wine_bar', progres: 5, target: 20, satuan: 'kaca', hadiahPoin: 75),
      AppBadge(id: '12', nama: 'Pecinta Sayur', deskripsi: '100 sisa sayur', kategori: 'organik', iconKey: 'restaurant', progres: 12, target: 100, satuan: 'sayur', hadiahPoin: 80),
      AppBadge(id: '13', nama: 'Pemilah Setia', deskripsi: '100 hari beruntun', kategori: 'streak', iconKey: 'workspace_premium', progres: 7, target: 100, satuan: 'hari', hadiahPoin: 1000),
      AppBadge(id: '14', nama: 'Guardian', deskripsi: '1000 total pemindaian', kategori: 'umum', iconKey: 'shield', progres: 55, target: 1000, satuan: 'pemindaian', hadiahPoin: 2000),
      AppBadge(id: '15', nama: 'Organik Spesialis', deskripsi: '500 organik', kategori: 'organik', iconKey: 'spa', progres: 32, target: 500, satuan: 'organik', hadiahPoin: 400),
    ];
  }
}
