class Mission {
  final String id;
  final String judul;
  final int progres;
  final int target;
  final String satuan;
  final int hadiahPoin;
  final String periode; // 'mingguan' / 'harian'
  final String status; // 'berjalan' / 'selesai-diklaim'
  
  Mission({
    required this.id,
    required this.judul,
    required this.progres,
    required this.target,
    required this.satuan,
    required this.hadiahPoin,
    required this.periode,
    required this.status,
  });
}
