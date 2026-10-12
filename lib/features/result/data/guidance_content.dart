import 'package:flutter/material.dart';

import '../../../core/waste/waste_types.dart';
import '../../scan/domain/waste_category.dart';

/// Model untuk setiap langkah pengolahan sampah.
class GuidanceStep {
  final String title;
  final String description;

  const GuidanceStep({
    required this.title,
    required this.description,
  });
}

/// Model panduan pengolahan per jenis sampah.
class WasteGuidance {
  final String title;
  final String description;
  final List<String> summaryPoints;
  final List<GuidanceStep> steps;
  final List<String> doList;
  final List<String> dontList;
  final List<String> reuseIdeas;

  const WasteGuidance({
    required this.title,
    required this.description,
    required this.summaryPoints,
    required this.steps,
    required this.doList,
    required this.dontList,
    this.reuseIdeas = const [],
  });
}

/// Informasi warna dan petunjuk tempat sampah.
class WasteBinInfo {
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final String binName;
  final String actionText;
  final IconData icon;

  const WasteBinInfo({
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.binName,
    required this.actionText,
    required this.icon,
  });
}

/// Helper untuk menurunkan tempat sampah dari kategori dan isHazardous jenis sampah.
WasteBinInfo getWasteBinInfo(WasteType type) {
  if (type.isHazardous) {
    return const WasteBinInfo(
      color: Colors.red,
      backgroundColor: Color(0xFFFFEBEE),
      borderColor: Color(0xFFFFCDD2),
      binName: 'tempat khusus limbah B3',
      actionText: 'Buang ke: tempat khusus limbah B3',
      icon: Icons.warning_amber_rounded,
    );
  }
  if (type.category == WasteCategory.organik) {
    return const WasteBinInfo(
      color: Colors.green,
      backgroundColor: Color(0xFFE8F5E9),
      borderColor: Color(0xFFC8E6C9),
      binName: 'tempat sampah hijau',
      actionText: 'Buang ke: tempat sampah hijau',
      icon: Icons.delete_outline,
    );
  }
  return const WasteBinInfo(
    color: Color(0xFFF57F17), // amber/kuning gelap agar kontras teks baik
    backgroundColor: Color(0xFFFFFDE7),
    borderColor: Color(0xFFFFF59D),
    binName: 'tempat sampah kuning',
    actionText: 'Buang ke: tempat sampah kuning',
    icon: Icons.delete_outline,
  );
}

/// Konten panduan per jenis sampah untuk 12 jenis sampah.
class GuidanceContent {
  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance battery = WasteGuidance(
    title: 'Baterai',
    description: 'Limbah bahan berbahaya dan beracun (B3) yang memerlukan penanganan khusus agar tidak mencemari lingkungan.',
    summaryPoints: [
      'Jangan dibuang ke tempat pembuangan sampah biasa.',
      'Tutup kedua kutub baterai dengan selotip sebelum disimpan.',
      'Serahkan ke titik pengumpulan limbah berbahaya atau drop point e-waste.',
    ],
    steps: [
      GuidanceStep(
        title: 'Pisahkan Baterai Bekas',
        description: 'Segera keluarkan baterai bekas dari perangkat elektronik untuk mencegah kebocoran zat kimia berbahaya.',
      ),
      GuidanceStep(
        title: 'Tutup Kutub dengan Selotip',
        description: 'Tempelkan selotip isolasi pada kedua kutub baterai untuk mencegah korsleting atau percikan api.',
      ),
      GuidanceStep(
        title: 'Simpan di Wadah Kering Non-Logam',
        description: 'Simpan baterai dalam wadah plastik atau kotak kardus kering, jauh dari jangkauan anak-anak.',
      ),
      GuidanceStep(
        title: 'Jauhkan dari Sumber Panas',
        description: 'Hindari paparan sinar matahari langsung, kelembapan tinggi, dan benda bertegangan panas.',
      ),
      GuidanceStep(
        title: 'Serahkan ke Titik Kumpul B3',
        description: 'Bawa tumpukan baterai bekas ke dropbox limbah B3 atau bank sampah khusus limbah elektronik.',
      ),
    ],
    doList: [
      'Menutup kedua kutub baterai menggunakan selotip isolasi.',
      'Menyimpan baterai dalam wadah kering non-logam.',
      'Menyerahkan ke titik pengumpulan limbah berbahaya.',
    ],
    dontList: [
      'Membakar, membongkar, atau menekan fisik baterai.',
      'Membuang baterai bekas ke tempat sampah biasa.',
      'Mencampur baterai bocor dengan benda berbahan logam.',
    ],
    reuseIdeas: [],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance biological = WasteGuidance(
    title: 'Biologis',
    description: 'Sisa bahan alami dari dapur dan kebun yang dapat terurai menjadi nutrisi penyubur tanah.',
    summaryPoints: [
      'Tiriskan sisa air dan pisahkan dari plastik pembungkus.',
      'Olah menjadi kompos menggunakan komposter atau lubang biopori.',
      'Campurkan dengan daun kering dan aduk tumpukan secara berkala.',
    ],
    steps: [
      GuidanceStep(
        title: 'Pilah dan Tiriskan',
        description: 'Pisahkan sisa makanan dan daun dari kemasan pembungkus, lalu tiriskan kuah atau airnya.',
      ),
      GuidanceStep(
        title: 'Cacah Menjadi Bagian Kecil',
        description: 'Potong sayuran, kulit buah, atau dedaunan menjadi potongan kecil agar lebih cepat terurai.',
      ),
      GuidanceStep(
        title: 'Masukkan ke Komposter',
        description: 'Masukkan bahan cacahan ke dalam wadah komposter atau lubang biopori yang sudah disiapkan.',
      ),
      GuidanceStep(
        title: 'Campur dengan Daun Kering',
        description: 'Tambahkan dedaunan kering atau serbuk kayu untuk menjaga keseimbangan kelembapan dan udara.',
      ),
      GuidanceStep(
        title: 'Aduk Berkala',
        description: 'Aduk tumpukan secara berkala seminggu sekali agar oksigen merata hingga menjadi pupuk matang.',
      ),
    ],
    doList: [
      'Mencacah sisa sayur dan kulit buah menjadi potongan kecil.',
      'Mencampur dengan daun kering atau sekam di komposter.',
      'Mengaduk tumpukan secara berkala setiap minggu.',
    ],
    dontList: [
      'Memasukkan daging, lemak, atau minyak dalam jumlah berlebih.',
      'Mencampur kantong plastik ke dalam wadah komposter.',
      'Membuang sisa makanan langsung ke saluran selokan air.',
    ],
    reuseIdeas: [
      'Diolah menjadi pupuk cair alami dari kulit buah segar.',
      'Dijadikan kompos penyubur tanaman pot pekarangan rumah.',
      'Diolah menjadi ekoenzim serbaguna untuk pembersih ramah lingkungan.',
    ],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance brownGlass = WasteGuidance(
    title: 'Kaca Cokelat',
    description: 'Wadah kaca berwarna cokelat seperti botol sirup atau obat yang melindungi cairan dari radiasi cahaya.',
    summaryPoints: [
      'Bilas bersih sisa isi dan lepaskan penutup botol.',
      'Bungkus pecahan dengan kertas atau kardus lalu beri tanda.',
      'Pisahkan menurut warna wadah saat menyetor ke bank sampah.',
    ],
    steps: [
      GuidanceStep(
        title: 'Kosongkan dan Bilas',
        description: 'Bilas bagian dalam botol sirup atau obat cokelat hingga bersih dari sisa cairan pekat.',
      ),
      GuidanceStep(
        title: 'Lepas Penutup dan Segel',
        description: 'Buka tutup botol berbahan logam seng atau plastik dan lepaskan cincin segel pengaman.',
      ),
      GuidanceStep(
        title: 'Periksa Kondisi Botol',
        description: 'Pastikan botol utuh; jika retak, lapisi dengan pembungkus pelindung agar tidak melukai tangan.',
      ),
      GuidanceStep(
        title: 'Bungkus Pecahan dengan Aman',
        description: 'Bungkus pecahan kaca dengan kertas tebal atau kardus lalu beri tanda peringatan benda tajam.',
      ),
      GuidanceStep(
        title: 'Serahkan ke Bank Sampah',
        description: 'Kumpulkan botol kaca cokelat terpisah dari wadah lain untuk diserahkan ke bank sampah.',
      ),
    ],
    doList: [
      'Membilas bersih botol dari endapan cairan obat atau sirup.',
      'Membungkus pecahan kaca dengan kertas tebal atau kardus.',
      'Memisahkan botol kaca cokelat sesuai kelompok warnanya.',
    ],
    dontList: [
      'Mencampur pecahan botol dengan cermin, keramik, atau kaca jendela.',
      'Membuang pecahan kaca terbuka tanpa pembungkus pelindung.',
      'Menumpuk botol kaca tinggi tanpa pengaman antar wadah.',
    ],
    reuseIdeas: [
      'Wadah vas bunga bergaya rustic untuk meja tamu.',
      'Tempat lilin aroma terapi pelindung cahaya remang.',
    ],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance cardboard = WasteGuidance(
    title: 'Kardus',
    description: 'Kemasan karton gelombang tebal yang mudah didaur ulang menjadi bubur kertas kemasan baru.',
    summaryPoints: [
      'Lepaskan lakban dan staples yang menempel pada kardus.',
      'Pipihkan kardus untuk menghemat ruang penyimpanan.',
      'Jaga kardus tetap kering, lalu tumpuk dan ikat rapi.',
    ],
    steps: [
      GuidanceStep(
        title: 'Buka dan Bersihkan',
        description: 'Buka lipatan kotak kardus dan lepaskan lakban perekat, stiker plastik, serta staples kawat.',
      ),
      GuidanceStep(
        title: 'Pipihkan Kardus',
        description: 'Tekan kardus hingga rata dan pipih agar tidak memakan banyak tempat penyimpanan.',
      ),
      GuidanceStep(
        title: 'Jaga Tetap Kering',
        description: 'Pastikan kardus terhindar dari tumpahan minyak, air hujan, atau tempat yang lembap.',
      ),
      GuidanceStep(
        title: 'Tumpuk dan Ikat Rapi',
        description: 'Susun lembaran kardus pipih sejenis, lalu ikat kencang dengan tali rafia.',
      ),
      GuidanceStep(
        title: 'Serahkan ke Bank Sampah',
        description: 'Bawa tumpukan kardus kering ke bank sampah atau mitra pengepul daur ulang terdekat.',
      ),
    ],
    doList: [
      'Melepas lakban dan perekat plastik sebelum melipat kardus.',
      'Menyimpan tumpukan kardus di tempat kering dan beralas.',
      'Mengikat rapi kardus pipih agar mudah diangkut.',
    ],
    dontList: [
      'Mencampur kardus yang terkena noda minyak atau kuah makanan.',
      'Membiarkan kardus basah terkena air hujan hingga rapuh.',
      'Membakar tumpukan kardus di pekarangan rumah.',
    ],
    reuseIdeas: [
      'Kotak penyimpanan barang atau arsip dokumen rumah tangga.',
      'Bahan pola kerajinan tangan atau alas bermain anak.',
      'Alas pelindung lantai saat mengecat ruangan rumah.',
    ],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance clothes = WasteGuidance(
    title: 'Pakaian',
    description: 'Produk tekstil sandang yang masih dapat dimanfaatkan kembali atau diolah serat benangnya.',
    summaryPoints: [
      'Cuci bersih dan pilah pakaian berdasarkan tingkat kelayakannya.',
      'Donasikan atau jual pakaian yang masih bagus dan layak pakai.',
      'Alih fungsikan pakaian rusak menjadi lap pembersih atau kerajinan.',
    ],
    steps: [
      GuidanceStep(
        title: 'Cuci dan Bersihkan',
        description: 'Cuci pakaian bekas dari debu dan kotoran, lalu jemur hingga benar-benar kering.',
      ),
      GuidanceStep(
        title: 'Pilah Berdasarkan Kelayakan',
        description: 'Kelompokkan pakaian yang masih utuh dan pakaian yang sudah robek atau bernoda berat.',
      ),
      GuidanceStep(
        title: 'Salurkan Pakaian Layak',
        description: 'Kemas pakaian layak pakai untuk didonasikan ke pos amal, ditukar, atau dijual kembali.',
      ),
      GuidanceStep(
        title: 'Olah Pakaian Rusak',
        description: 'Potong pakaian yang sudah tidak layak pakai menjadi kain lap pembersih atau isian bantal.',
      ),
      GuidanceStep(
        title: 'Bawa ke Drop Point Tekstil',
        description: 'Setorkan sisa kain perca ke tempat pengumpulan daur ulang serat tekstil jika tersedia.',
      ),
    ],
    doList: [
      'Mencuci bersih dan melipat rapi pakaian sebelum disalurkan.',
      'Memanfaatkan pakaian robek sebagai lap pembersih perabot dapur.',
      'Menjahit kancing copot atau benang lepas yang masih bisa diperbaiki.',
    ],
    dontList: [
      'Membuang pakaian dalam kondisi kotor atau basah berbau.',
      'Membakar kain sintetis berbahan poliester atau nilon.',
      'Mencampur kain bekas ke tempat sampah basah sisa makanan.',
    ],
    reuseIdeas: [
      'Kain lap pembersih debu dan perabot rumah tangga.',
      'Tas belanja kain jinjing dari celana atau kemeja lama.',
      'Keset kaki serbaguna dari anyaman guntingan kaos katun.',
    ],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance greenGlass = WasteGuidance(
    title: 'Kaca Hijau',
    description: 'Wadah kaca berwarna hijau segar seperti botol minuman atau soda yang memiliki nilai daur ulang tinggi.',
    summaryPoints: [
      'Bilas bersih sisa minuman dan lepaskan penutup botol.',
      'Bungkus dengan kertas atau kardus bila ada bagian yang retak.',
      'Kumpulkan bersama wadah kaca sejenis untuk bank sampah.',
    ],
    steps: [
      GuidanceStep(
        title: 'Kosongkan Sisa Cairan',
        description: 'Tuang habis sisa minuman segar atau soda dari dalam botol kaca hijau.',
      ),
      GuidanceStep(
        title: 'Bilas Bersih',
        description: 'Bilas bagian dalam botol dengan air mengalir hingga tidak ada sisa aroma manis tertinggal.',
      ),
      GuidanceStep(
        title: 'Lepaskan Tutup Botol',
        description: 'Lepaskan penutup botol dari bahan seng atau plastik serta segel leher botol.',
      ),
      GuidanceStep(
        title: 'Bungkus Pecahan Aman',
        description: 'Bungkus botol retak atau pecahan kaca menggunakan kertas koran tebal dan rekatkan isolasi.',
      ),
      GuidanceStep(
        title: 'Setorkan ke Bank Sampah',
        description: 'Simpan botol kaca hijau secara rapi di dalam kotak sebelum dibawa ke tempat daur ulang.',
      ),
    ],
    doList: [
      'Membilas bersih botol hingga terbebas dari sisa rasa manis.',
      'Memisahkan tutup botol metal atau plastik dari leher botol.',
      'Membungkus pecahan botol dengan rapat sebelum diserahkan.',
    ],
    dontList: [
      'Mencampur dengan keramik, cermin, kaca spion, atau kaca tahan panas.',
      'Menaruh pecahan botol terbuka tanpa pembungkus yang aman.',
      'Membuang botol kaca utuh ke saluran air atau pekarangan terbuka.',
    ],
    reuseIdeas: [
      'Vas tanaman air cantik penghias sudut meja kerja.',
      'Wadah terarium mini untuk lumut atau kaktus hias.',
    ],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance metal = WasteGuidance(
    title: 'Logam',
    description: 'Material kaleng minuman, makanan, atau perabot besi yang bernilai tinggi untuk dilebur kembali.',
    summaryPoints: [
      'Kosongkan dan bilas bersih sisa makanan atau minuman.',
      'Pipihkan kaleng jika mudah dan waspadai tepi tajam.',
      'Kumpulkan kaleng kering untuk disetorkan ke bank sampah.',
    ],
    steps: [
      GuidanceStep(
        title: 'Kosongkan Isi Kaleng',
        description: 'Keluarkan seluruh sisa cairan minuman atau sisa bahan makanan dari dalam kaleng.',
      ),
      GuidanceStep(
        title: 'Bilas dan Keringkan',
        description: 'Basuh bagian dalam kaleng dengan air hingga bersih dari minyak, lalu tiriskan.',
      ),
      GuidanceStep(
        title: 'Pipihkan Kaleng Minuman',
        description: 'Injak atau tekan kaleng minuman aluminium agar hemat tempat di wadah penyimpanan.',
      ),
      GuidanceStep(
        title: 'Amankan Tepi Tajam',
        description: 'Tekan tepi kaleng makanan yang bergerigi tajam ke arah dalam agar tidak melukai.',
      ),
      GuidanceStep(
        title: 'Kumpulkan dan Setorkan',
        description: 'Kumpulkan kaleng dalam wadah kering lalu serahkan ke bank sampah atau mitra pengepul.',
      ),
    ],
    doList: [
      'Membilas kaleng dari sisa saus atau minyak makanan.',
      'Memipihkan kaleng aluminium minuman untuk menghemat ruang.',
      'Menjaga kaleng dalam kondisi kering agar tidak berkarat.',
    ],
    dontList: [
      'Menekan, melubangi, atau membakar kaleng aerosol yang masih berisi gas.',
      'Mencampur kaleng berkarat parah dengan kaleng aluminium bersih.',
      'Membiarkan tepi kaleng yang tajam terbuka membahayakan.',
    ],
    reuseIdeas: [
      'Tempat pensil dan alat tulis meja belajar.',
      'Pot tanaman hias mini dengan lubang drainase di bagian bawah.',
    ],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance paper = WasteGuidance(
    title: 'Kertas',
    description: 'Lembaran serat kertas dokumen, buku, atau majalah yang dapat didaur ulang menjadi kertas cetak kembali.',
    summaryPoints: [
      'Pilah lembaran kertas yang bersih dan tetap dalam keadaan kering.',
      'Lepaskan staples kawat, klip logam, atau penjepit sebelum ditumpuk.',
      'Gunakan sisi belakang yang masih kosong untuk catatan harian.',
    ],
    steps: [
      GuidanceStep(
        title: 'Pilah Kertas Bersih',
        description: 'Kumpulkan kertas bekas dokumen atau buku yang bebas dari noda tumpahan makanan.',
      ),
      GuidanceStep(
        title: 'Lepas Staples dan Klip',
        description: 'Cabut kawat staples, klip logam, atau selotip plastik yang menempel pada sudut lembaran.',
      ),
      GuidanceStep(
        title: 'Manfaatkan Sisi Kosong',
        description: 'Gunakan bagian belakang kertas satu muka untuk memo harian atau lembar coretan belajar.',
      ),
      GuidanceStep(
        title: 'Rapikan dan Ikat',
        description: 'Susun tumpukan kertas rapi di wadah beralas kering lalu ikat dengan tali bila terkumpul banyak.',
      ),
      GuidanceStep(
        title: 'Bawa ke Pengepul Kertas',
        description: 'Serahkan tumpukan kertas ke bank sampah, pos penampungan kertas, atau pengepul daur ulang.',
      ),
    ],
    doList: [
      'Menyimpan kertas di dalam ruangan yang kering dan beralas.',
      'Melepas staples kawat sebelum menyetorkan ke bank sampah.',
      'Menggunakan sisi kertas yang masih kosong untuk lembar memo.',
    ],
    dontList: [
      'Mencampur kertas minyak, struk belanja thermal, atau tisu bekas pakai.',
      'Membiarkan kertas terkena percikan air atau lembap berjamur.',
      'Membakar tumpukan kertas bekas di pekarangan rumah.',
    ],
    reuseIdeas: [
      'Buku catatan memo saku dari kertas bekas satu muka.',
      'Bungkus kado kreatif bermotif tulisan lembaran lama.',
      'Bahan peredam guncangan pengganti plastik pelindung saat mengemas barang.',
    ],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance plastic = WasteGuidance(
    title: 'Plastik',
    description: 'Kemasan botol, cangkir, atau wadah polimer sintetis yang dapat didaur ulang menjadi biji bahan baru.',
    summaryPoints: [
      'Kosongkan sisa cairan lalu bilas dan tiriskan hingga kering.',
      'Lepaskan label pembungkus dan pipihkan botol kemasan.',
      'Kumpulkan botol dan cup plastik untuk disetorkan ke bank sampah.',
    ],
    steps: [
      GuidanceStep(
        title: 'Kosongkan dan Bilas',
        description: 'Bersihkan sisa minuman manis atau minyak dari dalam wadah plastik menggunakan sedikit air.',
      ),
      GuidanceStep(
        title: 'Lepas Label dan Tutup',
        description: 'Lepaskan penutup botol dan sobek label plastik merek jika diminta oleh mitra daur ulang.',
      ),
      GuidanceStep(
        title: 'Remas dan Pipihkan',
        description: 'Remas botol plastik hingga gepeng agar tidak menghabiskan tempat di wadah penampungan.',
      ),
      GuidanceStep(
        title: 'Keringkan Wadah',
        description: 'Angin-anginkan wadah hingga kering untuk mencegah timbulnya bau tidak sedap.',
      ),
      GuidanceStep(
        title: 'Kumpulkan ke Bank Sampah',
        description: 'Kumpulkan botol plastik bersih dalam kantong terpisah dan bawa ke bank sampah terdekat.',
      ),
    ],
    doList: [
      'Membilas botol minuman sebelum disimpan di tempat penampungan.',
      'Meremas botol plastik agar hemat tempat di wadah penyimpanan.',
      'Memisahkan tutup botol jika diminta oleh mitra bank sampah.',
    ],
    dontList: [
      'Membakar sampah kemasan plastik karena menghasilkan asap berbahaya.',
      'Menimbun botol kotor berisi cairan manis hingga didatangi semut.',
      'Membuang kemasan plastik sekali pakai ke saluran selokan air.',
    ],
    reuseIdeas: [
      'Pot tanaman gantung mandiri dengan tali sumbu penyerap air.',
      'Tempat wadah alat tulis atau kuas meja belajar.',
      'Corong darurat untuk menuang cairan ke botol lain.',
    ],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance shoes = WasteGuidance(
    title: 'Sepatu',
    description: 'Alas kaki berbahan kombinasi kulit, kain sintetis, dan karet sol yang membutuhkan pemilahan tepat.',
    summaryPoints: [
      'Bersihkan kotoran tanah atau lumpur yang menempel pada sol.',
      'Donasikan atau jual kembali sepatu yang masih layak pakai.',
      'Perbaiki kerusakan ringan atau buang sebagai residu jika telah rusak parah.',
    ],
    steps: [
      GuidanceStep(
        title: 'Bersihkan Permukaan',
        description: 'Sikat debu dan tanah kering yang menempel pada bagian bawah sol serta bahan kain sepatu.',
      ),
      GuidanceStep(
        title: 'Periksa Kondisi Kelayakan',
        description: 'Cek apakah sepatu masih aman digunakan atau sol karetnya sudah terlepas dan rapuh.',
      ),
      GuidanceStep(
        title: 'Perbaiki Kerusakan Ringan',
        description: 'Gunakan lem khusus atau bawa ke jasa sol sepatu jika hanya bagian tepinya yang terbuka.',
      ),
      GuidanceStep(
        title: 'Salurkan Sepatu Layak Pakai',
        description: 'Cuci bersih dan donasikan sepatu layak ke panti sosial, pos amal, atau jual bekas.',
      ),
      GuidanceStep(
        title: 'Kelola Sepatu Rusak Parah',
        description: 'Bila sudah robek berat dan tidak bisa diperbaiki, buang ke penampungan residu atau drop point daur ulang sol karet.',
      ),
    ],
    doList: [
      'Membersihkan kotoran tanah pada sol sebelum menyalurkan sepatu.',
      'Mendonasi sepatu yang masih bagus dan tidak sobek parah.',
      'Memperbaiki jahitan atau sol yang terlepas ringan.',
    ],
    dontList: [
      'Membakar sepatu bekas yang mengandung bahan sol karet sintetis.',
      'Mencampur sepatu kotor berlumpur basah ke tumpukan pakaian bersih.',
      'Membuang sepatu layak pakai langsung ke tempat pembuangan akhir.',
    ],
    reuseIdeas: [
      'Pot tanaman bunga unik untuk pekarangan luar ruangan.',
      'Bahan latihan prakarya perbaikan kerajinan tangan.',
    ],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance trash = WasteGuidance(
    title: 'Residu',
    description: 'Sisa pemakaian rumah tangga yang sulit dimanfaatkan kembali dan tidak bernilai daur ulang.',
    summaryPoints: [
      'Kemas dalam kantong tertutup rapat agar tidak tercecer.',
      'Bungkus benda tajam sebelum dimasukkan ke kantong sampah.',
      'Buang ke tempat penampungan sampah resmi untuk diangkut ke TPA.',
    ],
    steps: [
      GuidanceStep(
        title: 'Pilah Barang Residu',
        description: 'Pastikan benda yang masuk memang tidak dapat didaur ulang, seperti tisu kotor atau popok sekali pakai.',
      ),
      GuidanceStep(
        title: 'Bersihkan Popok Sekali Pakai',
        description: 'Buang kotoran padat popok ke kloset, gulung erat popok bekas, lalu rekatkan selotip perekatnya.',
      ),
      GuidanceStep(
        title: 'Amankan Benda Tajam',
        description: 'Bungkus tusuk sate, beling kecil, atau benda tajam dengan kertas tebal atau botol bekas.',
      ),
      GuidanceStep(
        title: 'Masukkan ke Kantong Tertutup',
        description: 'Kumpulkan residu ke dalam kantong plastik kuat lalu ikat erat agar tidak menimbulkan bau menyengat.',
      ),
      GuidanceStep(
        title: 'Buang ke TPS Resmi',
        description: 'Letakkan kantong sampah di bak penampungan lingkungan untuk diangkut petugas ke tempat pembuangan akhir.',
      ),
    ],
    doList: [
      'Mengikat rapat kantong sampah sebelum diletakkan di bak penampungan.',
      'Membungkus ujung benda tajam dengan pelindung kardus tebal.',
      'Membuang kotoran popok ke kloset terlebih dahulu.',
    ],
    dontList: [
      'Membakar sampah residu di lingkungan permukiman warga.',
      'Membuang kantong sampah ke aliran sungai atau saluran selokan air.',
      'Mencampur limbah baterai beracun ke dalam kantong sampah biasa.',
    ],
    reuseIdeas: [],
  );

  // DRAFT: perlu diverifikasi manusia
  static const WasteGuidance whiteGlass = WasteGuidance(
    title: 'Kaca Bening',
    description: 'Toples dan botol kaca transparan bening yang memiliki kemurnian tinggi serta dapat dilebur kembali.',
    summaryPoints: [
      'Bilas bersih sisa selai, sirup, atau bumbu dari dalam toples.',
      'Lepas penutup metal atau plastik pada mulut toples.',
      'Bungkus dengan kertas atau kardus tebal jika terdapat pecahan.',
    ],
    steps: [
      GuidanceStep(
        title: 'Kosongkan Sisa Isi',
        description: 'Keluarkan sisa makanan atau bumbu yang masih menempel di dinding wadah toples kaca.',
      ),
      GuidanceStep(
        title: 'Cuci dan Bilas',
        description: 'Bilas bagian dalam toples dengan sedikit air hangat hingga bebas dari sisa minyak atau aroma pekat.',
      ),
      GuidanceStep(
        title: 'Lepas Penutup dan Segel',
        description: 'Pisahkan tutup toples berbahan seng, aluminium, atau plastik ke wadah pemilahan masing-masing.',
      ),
      GuidanceStep(
        title: 'Lapisi Wadah Pecah',
        description: 'Jika toples retak atau pecah, bungkus rapat dengan lembaran kardus tebal dan beri tanda hati-hati.',
      ),
      GuidanceStep(
        title: 'Kumpulkan Terpisah',
        description: 'Satukan wadah kaca bening utuh ke dalam kardus sebelum disetorkan ke bank sampah.',
      ),
    ],
    doList: [
      'Mencuci bersih sisa saus atau minyak di dalam toples kaca.',
      'Melepas segel karet dan tutup toples berbahan selain kaca.',
      'Membungkus pecahan kaca dengan kardus pelindung yang aman.',
    ],
    dontList: [
      'Mencampur kaca botol bening dengan lampu bohlam, cermin, atau piring keramik.',
      'Membuang pecahan kaca bening terbuka tanpa pembungkus pengaman.',
      'Menumpuk toples kaca tinggi tanpa sekat penahan benturan.',
    ],
    reuseIdeas: [
      'Wadah penyimpan bumbu dapur kering atau kancing baju.',
      'Toples hias lilin aromaterapi meja belajar.',
      'Gelas minum estetik atau wadah puding hidangan penutup.',
    ],
  );

  /// Pemetaan 12 jenis sampah ke konten panduannya.
  static const Map<WasteType, WasteGuidance> byType = {
    WasteType.battery: battery,
    WasteType.biological: biological,
    WasteType.brownGlass: brownGlass,
    WasteType.cardboard: cardboard,
    WasteType.clothes: clothes,
    WasteType.greenGlass: greenGlass,
    WasteType.metal: metal,
    WasteType.paper: paper,
    WasteType.plastic: plastic,
    WasteType.shoes: shoes,
    WasteType.trash: trash,
    WasteType.whiteGlass: whiteGlass,
  };

  /// Mengambil panduan berdasarkan [WasteType].
  static WasteGuidance getGuidance(WasteType type) {
    return byType[type] ?? cardboard;
  }
}
