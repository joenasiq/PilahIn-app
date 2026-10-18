class AppBadge {
  final String id;
  final String nama;
  final String deskripsi;
  final String kategori; // organik/anorganik/streak/umum
  final String iconKey; 
  final int progres;
  final int target;
  final String satuan;
  final DateTime? tanggalDiraih;
  final int hadiahPoin;

  AppBadge({
    required this.id,
    required this.nama,
    required this.deskripsi,
    required this.kategori,
    required this.iconKey,
    required this.progres,
    required this.target,
    required this.satuan,
    this.tanggalDiraih,
    required this.hadiahPoin,
  });

  bool get isOpen => progres >= target;
}
