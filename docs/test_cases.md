# Test Cases PilahIn

Bagian ini memuat skenario pengujian fungsional aplikasi. Status saat ini semuanya "Belum diuji" dan siap dieksekusi secara manual.

| ID | Modul | Skenario | Langkah | Hasil yang diharapkan | Status | Catatan |
|---|---|---|---|---|---|---|
| TC-01 | Autentikasi | Login dengan kredensial benar | 1. Buka aplikasi<br>2. Masukkan `user@polinema.ac.id` dan `pilahin123`<br>3. Tekan "Masuk" | Berhasil login dan masuk ke Beranda. | Belum diuji | |
| TC-02 | Autentikasi | Login dengan kredensial salah | 1. Buka aplikasi<br>2. Masukkan email salah dan sandi sembarang<br>3. Tekan "Masuk" | Tampil notifikasi pesan error "Kredensial tidak valid". | Belum diuji | |
| TC-03 | Autentikasi | Validasi form login kosong | 1. Buka aplikasi<br>2. Kosongkan email/password<br>3. Tekan "Masuk" | Form menampilkan teks peringatan error (validasi). | Belum diuji | |
| TC-04 | Autentikasi | Masuk sebagai tamu | 1. Buka aplikasi<br>2. Tekan "Lanjutkan sebagai Tamu" | Masuk ke Beranda dengan mode tamu (elemen profil/poin disesuaikan). | Belum diuji | |
| TC-05 | Autentikasi | Sesi tersimpan (Persistensi) | 1. Login berhasil<br>2. Tutup aplikasi paksa (kill)<br>3. Buka aplikasi kembali | Langsung diarahkan ke Beranda tanpa login ulang. | Belum diuji | |
| TC-06 | Profil | Keluar akun (Logout) | 1. Buka tab Profil<br>2. Tekan "Keluar"<br>3. Konfirmasi dialog | Sesi dihapus, pengguna diarahkan ke layar Login. | Belum diuji | |
| TC-07 | Navigasi | Navigasi Bottom Tab | 1. Di Beranda, tekan tab Pindai, lalu tab Profil, lalu Beranda | Layar berpindah sesuai tab tanpa error, *state* terjaga. | Belum diuji | |
| TC-08 | Navigasi | Perilaku tombol Back sistem | 1. Di tab Pindai/Profil, tekan Back sistem (Android) | Kembali ke tab Beranda. Jika di Beranda, tekan 2x untuk keluar. | Belum diuji | |
| TC-09 | Pindai | Izin kamera diizinkan | 1. Buka tab Pindai (pertama kali)<br>2. Izinkan akses kamera | Kamera langsung terbuka dan menampilkan *preview*. | Belum diuji | |
| TC-10 | Pindai | Izin kamera ditolak | 1. Buka tab Pindai<br>2. Tolak izin kamera | Menampilkan pesan agar mengaktifkan kamera melalui Pengaturan. | Belum diuji | |
| TC-11 | Pindai | Ambil Foto | 1. Buka tab Pindai<br>2. Arahkan ke objek<br>3. Tekan tombol ambil foto bulat | Menangkap gambar dan otomatis beralih ke layar Hasil. | Belum diuji | |
| TC-12 | Pindai | Pilih dari Galeri | 1. Buka tab Pindai<br>2. Tekan ikon Galeri<br>3. Pilih gambar | Beralih ke layar Hasil dengan gambar terpilih. | Belum diuji | |
| TC-13 | Pindai | Kontrol Flash | 1. Buka tab Pindai<br>2. Tekan ikon Flash | Status Flash kamera berubah (nyala/mati). | Belum diuji | |
| TC-14 | Hasil | Layar Hasil (Yakin) | 1. Lakukan pemindaian (mock Organik/Anorganik) | Menampilkan gambar, kategori (Organik/Anorganik), keyakinan tinggi, teks Panduan, dan tombol Panduan Lengkap. | Belum diuji | |
| TC-15 | Hasil | Layar Hasil (Tidak Yakin) | 1. Lakukan pemindaian (mock confidence < 60%) | Muncul *banner* kuning peringatan "Hasil Kurang Akurat". | Belum diuji | |
| TC-16 | Riwayat | Daftar Riwayat (Ada Data) | 1. Lakukan beberapa scan<br>2. Buka tab Beranda > Riwayat | Menampilkan *list* riwayat yang baru saja dipindai beserta tanggal. | Belum diuji | |
| TC-17 | Riwayat | Fitur Hapus dan Urungkan (Undo) | 1. Buka Riwayat<br>2. Geser item ke kiri (hapus)<br>3. Tekan Undo pada *Snackbar* | Item terhapus, lalu kembali muncul setelah di-Undo. | Belum diuji | |
| TC-18 | Profil | Tentang Aplikasi | 1. Buka tab Profil<br>2. Tekan "Tentang Aplikasi" | Menampilkan *dialog* informasi versi aplikasi. | Belum diuji | |
| TC-19 | Gamifikasi | Misi & Lencana (Tab Beralih) | 1. Buka Profil > Misi & Lencana<br>2. Buka tab Lencana | Layar menampilkan kisi-kisi badge koleksi pengguna. | Belum diuji | |
| TC-20 | Gamifikasi | Detail Lencana | 1. Di tab Lencana, tekan salah satu badge | Muncul *bottom sheet* dengan informasi progress target dan tombol bagikan/pindai. | Belum diuji | |
| TC-21 | Gamifikasi | Saklar *gamificationEnabled* = false | 1. Ubah nilai config `gamificationEnabled` ke false di kodingan, lalu *reload* | Seluruh elemen gamifikasi (level, misi, badge, poin di hasil) HILANG dari UI. | Belum diuji | |
| TC-22 | UI/UX | Orientasi *Portrait* Terkunci | 1. Putar fisik perangkat ke mode *Landscape* | Layar tetap dalam mode *Portrait*, tidak ikut berputar. | Belum diuji | |

## Dibutuhkan model asli
Skenario di bawah ini *menunggu model asli dari tim ML* dan tidak masuk dalam tanggung jawab validasi UI/UX.

| ID | Modul | Skenario | Hasil yang diharapkan | Status |
|---|---|---|---|---|
| ML-01 | Model | Akurasi klasifikasi botol plastik | Prediksi "Anorganik" dengan confidence > 85% | Menunggu model asli dari tim ML |
| ML-02 | Model | Waktu respons inferensi model | Klasifikasi selesai di bawah 1.5 detik | Menunggu model asli dari tim ML |

## Kompatibilitas Android
| Perangkat | Versi Android | Ukuran Layar | Hasil | Catatan |
|---|---|---|---|---|
| Emulator Pixel 7 | 14.0 | 1080 x 2400 | Belum diuji | |
