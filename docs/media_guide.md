# Panduan Media Panduan Pengolahan Sampah (PilahIn)

Dokumen ini memuat panduan penamaan, penempatan, dan spesifikasi aset media (foto dan video) untuk fitur panduan pengolahan sampah per jenis.

---

## 1. Struktur Folder

Semua aset media diletakkan di dalam folder `assets/guidance/<labelKey>/` sesuai dengan kelas dataset (12 jenis sampah):

```text
assets/
└── guidance/
    ├── battery/
    ├── biological/
    ├── brown-glass/
    ├── cardboard/
    ├── clothes/
    ├── green-glass/
    ├── metal/
    ├── paper/
    ├── plastic/
    ├── shoes/
    ├── trash/
    └── white-glass/
```

> **Penting**: Setiap folder didaftarkan secara eksplisit di `pubspec.yaml` karena Flutter tidak memuat aset subfolder secara rekursif.

---

## 2. Aturan Penamaan File

Aplikasi mendeteksi aset secara otomatis berdasarkan konvensi nama file berikut (tidak ada path yang di-hardcode di kode):

1. **Video Panduan**:
   - `video.mp4` : Video demonstrasi langkah pengolahan.
   - `poster.jpg` / `poster.png` / `poster.webp` : Gambar sampul (poster/thumbnail) sebelum video diputar. (Opsional)
2. **Foto Langkah Pengolahan**:
   - `step_1.jpg` sampai `step_N.jpg` : Foto panduan untuk langkah ke-N.
   - Format gambar yang didukung: `.jpg`, `.jpeg`, `.png`, `.webp`.
   - Contoh: `step_1.jpg`, `step_2.png`, `step_3.webp`.

---

## 3. Spesifikasi yang Disarankan

Untuk menjaga kinerja aplikasi dan meminimalkan ukuran paket instalasi (APK/IPA):

### A. Foto Langkah & Poster
- **Dimensi**: Lebar maksimal disarankan sekitar **1080 px** (skala 1:1, 4:3, atau 16:9).
- **Ukuran File**: Di bawah **300 KB** per gambar.
- **Format Rekomendasi**: JPEG dengan kompresi 80-85% atau WebP.

### B. Video Panduan
- **Format**: MP4 (Video codec: **H.264 / AVC**, Audio: **AAC**).
- **Resolusi**: **720p** (1280x720) atau **480p** (854x480).
- **Durasi**: Maksimal sekitar **30 – 60 detik**.
- **Bitrate**: Video bitrate 1.0 – 1.5 Mbps, audio bitrate 96 – 128 kbps.
- **Ukuran File**: Di bawah **5 – 8 MB** per video.

> ⚠️ **PERINGATAN**: Setiap video yang dimasukkan ke dalam folder aset akan langsung menambah ukuran bundle APK / App Bundle. Pastikan video selalu dikompresi sebelum dimasukkan ke dalam repositori.

---

## 4. Contoh Perintah Kompresi dengan FFmpeg

Jika Anda memiliki file video mentah (`input.mp4`), gunakan perintah FFmpeg berikut untuk mengoptimalkannya:

```bash
# Mengecilkan video ke 720p, codec H.264, bitrate teroptimasi (~1.2 Mbps)
ffmpeg -i input.mp4 -vf "scale=-2:720" -c:v libx264 -crf 26 -preset slow -c:a aac -b:a 128k video.mp4

# Membuat gambar poster dari detik pertama video
ffmpeg -ss 00:00:01 -i video.mp4 -vframes 1 -q:v 2 poster.jpg

# Mengecilkan gambar foto langkah menjadi lebar 1080px dan kompresi JPEG
ffmpeg -i raw_step1.jpg -vf "scale=1080:-1" -q:v 3 step_1.jpg
```
