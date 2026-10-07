# PilahIn

PilahIn adalah aplikasi klasifikasi sampah berbasis Flutter yang membantu pengguna memilah sampah organik dan anorganik.

## Fitur yang Tersedia
- **Autentikasi**: Login dan masuk sebagai Tamu. Sesi pengguna disimpan secara lokal.
- **Beranda & Navigasi**: Tab Beranda dengan kartu level & progres (Gamifikasi), tab navigasi bawah (Beranda, Pindai, Profil).
- **Pemindaian (Scan)**: Menggunakan kamera (beserta dukungan flash) dan galeri untuk memindai sampah.
- **Hasil & Panduan**: Menampilkan hasil klasifikasi (Organik/Anorganik) dengan persentase keyakinan. Tersedia juga panduan pengelolaan sampah yang spesifik.
- **Riwayat**: Menyimpan riwayat pemindaian secara lokal, menampilkan daftar hasil, detail, serta fitur hapus dengan _undo_.
- **Profil**: Menampilkan statistik poin dan tingkat akurasi (Gamifikasi), menu ke Misi & Lencana, Tentang Aplikasi, dan Keluar.
- **Misi & Lencana (Gamifikasi)**: Menampilkan progres misi harian, daftar koleksi lencana (badge) yang bisa terbuka jika syarat terpenuhi, dan _bottom sheet_ detail lencana.

## Teknologi Utama
- **Framework**: Flutter (v3.47.2) / Dart (v3.13.2)
- **State Management**: `flutter_riverpod`
- **Routing**: `go_router`
- **Penyimpanan Lokal**: `sqflite`, `shared_preferences`
- **Kamera & Pemilih Gambar**: `camera`, `image_picker`
- **Lainnya**: `google_fonts`, `intl`, `cupertino_icons`

## Cara Menjalankan
**Prasyarat**: Android Studio dan Android SDK sudah terpasang.
1. Klon repositori dan jalankan instalasi *dependency*:
   ```bash
   flutter pub get
   ```
2. Hubungkan perangkat fisik atau jalankan emulator.
3. Jalankan aplikasi:
   ```bash
   flutter run
   ```
4. Gunakan `r` untuk _Hot Reload_ atau `R` untuk _Hot Restart_.

**Akun Demo:**
- Email: `user@polinema.ac.id`
- Password: `pilahin123`

## Struktur Folder (Feature-First)
- `lib/core/`: Berisi konfigurasi, tema, rute, _constants_, dan komponen UI _shared_ (widget global).
- `lib/features/auth/`: Menangani alur login, status sesi pengguna, dan autentikasi tamu.
- `lib/features/home/`: Berisi antarmuka Beranda yang menggabungkan statistik ringkas dan pemicu pemindaian.
- `lib/features/scan/`: Mengatur akses kamera/galeri dan lapisan *domain/data* untuk klasifikasi sampah.
- `lib/features/result/`: Menampilkan hasil analisis klasifikasi dan panduan langkah pengelolaan.
- `lib/features/history/`: Menangani basis data lokal (SQLite) untuk menyimpan dan menampilkan riwayat pemindaian.
- `lib/features/profile/`: Menampilkan profil pengguna, ringkasan statistik, dan menu utama akun.
- `lib/features/gamification/`: Mengelola dan menampilkan fitur Misi (progres harian) dan koleksi Lencana (Badge).

## Saklar Konfigurasi (Constants)
Berada di `lib/core/constants/app_constants.dart` dan `ml_config.dart`.
- `gamificationEnabled` (default: `true`): Menghidupkan atau mematikan seluruh elemen gamifikasi di aplikasi (kartu di Beranda, Misi, statistik poin, rute profil, dll.).
- `showScanPoints` (default: `true` / mengikuti `gamificationEnabled`): Menampilkan _chip_ hadiah poin pada layar hasil jika diaktifkan.
- `seedDemoHistory` (default: `false`): Jika `true`, mengisi riwayat dengan data _dummy_ awal.
- `lowConfidenceThreshold` (default: `0.6`): Batas minimum _confidence_. Jika hasil di bawah batas ini, sistem menandainya dengan bendera `isUncertain` (tidak yakin).
- `scanPointsReward` (default: `15`): Jumlah poin standar yang diberikan per pemindaian.

## Status Klasifikasi (Mock Model)
Saat ini fitur klasifikasi menggunakan **classifier TIRUAN** (`MockWasteClassifier`) yang terletak di `lib/features/scan/data/mock_waste_classifier.dart`. Model ini bergilir memberikan hasil statis: (1) Organik (92,7%), (2) Anorganik (91,2%), (3) Tidak Yakin (48%).
Implementasi model asli nantinya cukup dipasang dengan membuat kelas baru yang meng-implementasi antarmuka `WasteClassifier` (dari `lib/features/scan/domain/waste_classifier.dart`), dan mengganti *return value* pada `wasteClassifierProvider` di `lib/features/scan/presentation/classification_controller.dart`.

## Troubleshooting
Berikut adalah catatan masalah yang pernah ditemui selama masa _build_ awal:
- **NDK tidak ditemukan**: Pastikan NDK telah terpasang melalui SDK Manager di Android Studio.
- **Drive Cache Berbeda (Windows)**: Jika *project* dan pub cache berada di drive Windows yang berbeda, tambahkan baris `kotlin.incremental=false` di file `android/gradle.properties` (Sudah diterapkan).
- **Peringatan JVM Target dari `tflite_flutter`**: Dikelola dengan menambahkan `kotlin.jvm.target.validation.mode=warning` di `android/gradle.properties` (Sudah diterapkan).

## Bekerja dalam Tim
- **Alur Git**: Gunakan _branch_ terpisah untuk setiap fitur (misal: `feature/home`, `feature/scan`). Buat _commit_ yang kecil dan sering (deskriptif).
- Selalu lakukan `git pull` dari _branch_ utama sebelum melakukan `git push` untuk menghindari _conflict_.
- Komunikasikan dengan rekan tim (khususnya *mobile developer* lain) untuk mencegah mengubah file *core* atau file yang sama pada waktu yang bersamaan.
