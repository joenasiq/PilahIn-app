# Rencana Penyimpanan Data PilahIn (Lokal + Firebase Cloud)

> Status: **Fase 1 & 2 selesai** (2026-11-03). Fase 3–5 belum diimplementasikan.
>
> **Log perubahan**: 2026-11-03 — arsitektur diganti dari "SQLite lokal 100%" menjadi
> **hibrida lokal + cloud** berdasarkan diskusi dengan dosen:
> data akun, riwayat scan (teks/log), poin, badge, dan achievement disimpan di **cloud
> (Firebase)** agar aman dari logout/ganti perangkat/uninstall; **file gambar hasil
> scan tetap lokal** (tidak diupload). SQLite dihapus (Fase 5).

## 1. Arsitektur Penyimpanan (Lokal vs Cloud)

| Data | Disimpan di | Catatan |
|---|---|---|
| Akun user (email, password) | **Firebase Auth** | Kelolaan Firebase; hash password tidak disimpan kita |
| Profil, poin, streak | **Firestore** `users/{uid}` | Cache total poin |
| Riwayat scan (teks/log) | **Firestore** `users/{uid}/scans/{scanKey}` | `image_path` hanya path file lokal |
| Badge & misi per user | **Firestore** `users/{uid}/badges/{code}`, `.../missions/...` | Fase 3 |
| File gambar hasil scan | **Lokal** (file di app directory) | Tidak diupload; jika file tidak ada di perangkat, UI menampilkan fallback (`history_screen` sudah cek `existsSync`) |
| Progres tamu (scan) | **Lokal** (JSON di SharedPreferences) | `GuestProgressStore`; di-merge ke akun saat login/registrasi (Fase 3) |
| Reference data (12 jenis sampah, eco-impact, 5 level, 15 badge, 2 misi) | **Kode Dart** (enum + konstanta yang sudah ada) | Data statis, tidak perlu penyimpanan |

## 2. Model Data Firestore

### `users/{uid}`
```
display_name     : String
total_points     : int    -- cache dari seluruh event poin
current_streak   : int
best_streak      : int
last_active_date : String? -- 'YYYY-MM-DD' (zona waktu lokal)
created_at       : Timestamp
```

### `users/{uid}/scans/{scanKey}` (doc ID = scanKey → idempoten)
```
scan_key      : String (== doc ID)
user_id       : String (== uid)
waste_type    : String?   -- labelKey, mis. 'plastic'
category      : String    -- 'organik' | 'anorganik'
confidence    : double
is_uncertain  : int       -- 0/1
item_name     : String?
points_earned : int
image_path    : String?   -- path file LOKAL (bukan URL cloud)
created_at    : int       -- millisecondsSinceEpoch
```

### `users/{uid}/badges/{code}` (Fase 3)
```
progress    : int
unlocked_at : int?        -- millisecondsSinceEpoch
```

### `users/{uid}/missions/{code}_{periodStart}` (Fase 3)
```
progress     : int
status       : 'berjalan' | 'selesai' | 'diklaim'
period_start : String     -- 'YYYY-MM-DD' (harian) / Senin ISO (mingguan)
claimed_at   : int?
```

Catatan: ledger `point_transactions` **tidak** dibuat — penyesuaian poin (hapus/undo)
langsung memperbarui `users/{uid}.total_points` (cukup untuk skala PBL).

## 3. Data Reference (tetap di kode Dart)

| Data | Sumber di kode | Jumlah |
|---|---|---|
| Jenis sampah | Enum `WasteType` (`core/waste/waste_types.dart`) | 12 |
| Eco-impact | `getEcoImpactForWasteType()` (`features/result/domain/eco_impact.dart`) | 12 |
| Level | `Pemilah Pemula` 0, `Juru Kompos` 300, `Penyelamat Bumi` 700, `Duta Daur Ulang` 1000, `Dewa Ekosistem` 2000 | 5 |
| Badge | Definisi 15 lencana (diambil dari `MockGamificationRepository` lama; kolom `metric` menentukan cara hitung: `total`/`kategori_organik`/`kategori_anorganik`/`jenis`/`streak`) | 15 |
| Misi | `misi_harian_organik` (3 organik/hari, +30) & `misi_mingguan_plastik` (10 botol/minggu, +50) | 2 |

Konten panduan (`guidance_content.dart`) tetap di code/asset — konten statis.

## 4. Alur Bisnis Fase 3 (pipeline setelah tiap scan, satu batch write)

1. `set users/{uid}/scans/{scanKey}` (user aktif: tamu → lokal dulu, akun → Firestore).
2. Update `users/{uid}`: `total_points + MlConfig.scanPointsReward` + aturan streak:
   - `last_active_date == hari ini` → streak tetap
   - `== kemarin` → `current_streak + 1`
   - selain itu → `current_streak = 1`; `best_streak = max(...)`; `last_active_date = hari ini`.
3. **Rekomputasi** `users/{uid}/badges/*` & `missions/*` dari agregasi scans:
   - `jenis` → jumlah scans dengan `waste_type` dalam daftar labelKey
   - `kategori_*` → jumlah scans dengan `category = ?`
   - `total` → jumlah semua scans
   - `streak` → ambil `users/{uid}.current_streak`
   - Misi harian `period_start = hari ini`, mingguan = Senin ISO.
4. Badge baru terbuka → `unlocked_at = now` + tambah `total_points` (hadiah badge);
   misi selesai → status `selesai` (→ `diklaim` saat user menekan klaim).

Turunan:
- Level: `min_points <= total_points ORDER BY level DESC LIMIT 1`; `pointsToNextLevel = ambang(level berikut) − total_points`.
- Donut profil: `GROUP BY category` dari scans user.
- Hapus/undo riwayat: hapus doc scan + kurangi `total_points`; badge yang sudah terbuka **tidak** dikunci lagi.

## 5. Auto-Merge Tamu → Akun (Fase 3)

- Progres tamu (list scan) ada di `GuestProgressStore` (SharedPreferences JSON).
- Saat login/registrasi berhasil **dan** store berisi data:
  1. Batch-write semua scan tamu → `users/{uid}/scans/{scanKey}` (doc ID = scanKey; yang sudah ada di-skip via merge).
  2. Rekomputasi poin/streak/badge/misi user (langkah 3 di atas) — data tamu ikut terhitung.
  3. `GuestProgressStore.clear()`.
- Tamu tanpa progres → tidak ada yang di-merge.

## 6. Pemetaan ke Kode

```
lib/main.dart                                    -- Firebase.initializeApp() (Android)
lib/core/firebase/
  firebase_providers.dart                        -- firebaseAuthProvider, firebaseFirestoreProvider
lib/core/guest/
  guest_progress_store.dart                      -- GuestProgressStore (SharedPreferences JSON)
lib/features/auth/data/
  firebase_auth_repository.dart                  -- login/guest/logout/getCurrentUser (Firebase)
  local_auth_repository.dart                     -- [DIHAPUS FASE 5] versi SQLite
lib/features/history/data/
  firebase_history_repository.dart               -- Firestore users/{uid}/scans
  guest_history_repository.dart                  -- GuestProgressStore
  sqflite_history_repository.dart                -- [DIHAPUS FASE 5]
lib/features/history/presentation/
  history_provider.dart                          -- routing repository (tamu <-> akun) + HistoryNotifier
lib/core/db/                                     -- [DIHAPUS FASE 5] app_database, seeds, users_repository, password_hasher
[FASE 4] layar registrasi (dibuat tim)          -- dihubungkan ke FirebaseAuthRepository.register
[FASE 3] firebase_gamification_repository.dart  -- pipeline poin/badge/misi
```

Interface `AuthRepository`, `HistoryRepository`, `GamificationRepository` tidak berubah
(`register` ditambahkan ke `AuthRepository` di Fase 4).

## 7. Tahapan

| Fase | Isi | Status |
|---|---|---|
| **1 – Fondasi DB lokal** | Schema v3, seed, auth SQLite, riwayat per-user | ✅ 2026-11-02 (peran berubah: jadi fondasi guest + reference) |
| **2 – Fondasi Firebase** | Dependency Firebase, `Firebase.initializeApp`, `FirebaseAuthRepository` (login/sesi via uid, pesan error konsisten), `FirebaseHistoryRepository` + `GuestHistoryRepository` + `GuestProgressStore`, routing provider, test guest repository, `late final` fix | ✅ 2026-11-03 |
| **3 – Gamifikasi cloud** | Pipeline post-scan (batch write), recompute badge/misi, `FirebaseGamificationRepository` + home repository, **auto-merge tamu→akun** | ⏳ |
| **4 – Integrasi registrasi** | Layar registrasi tim → `AuthRepository.register` + `users/{uid}` + auto-merge (menunggu push dari anggota tim) | ⏳ |
| **5 – Bersihkan & uji** | Hapus SQLite (`lib/core/db/`, sqflite repo, `local_auth_repository`, dep `sqflite`+`crypto`), security rules Firestore, uji skenario (multi-user, tamu→akun, ganti perangkat), test dengan Firestore emulator | ⏳ |

## 8. Keamanan Firestore

Selama development: **test mode** (berlaku ~30 hari). Sebelum demo/sidang, ganti:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## 9. Catatan Lingkungan & Operasional

- **Firebase project**: `pilahin-98b19`. Android app terdaftar (`com.example.pilahin_app`),
  Authentication Email/Password aktif, Firestore dibuat (test mode).
- **Akun demo**: `kel5pbl@gmail.com` / `pilahln123` — WAJIB dibuat di konsol Firebase
  (Authentication → Users → Add user) agar login demo berfungsi.
- **Target app: Android**. `Firebase.initializeApp()` tanpa options membaca
  `google-services.json` otomatis di Android; di desktop inisialisasi gagal dengan pesan jelas.
- **Offline**: Firestore punya cache offline bawaan; `get()` default `serverAndCache`
  sehingga profil/riwayat tetap terbaca tanpa internet (data yang pernah dimuat).
- **`flutter test` terblokir di mesin ini** (pre-existing): path instalasi Flutter
  mengandung spasi (`C:\Users\H P\flutter`) sehingga build hook native asset
  (`objective_c`) gagal (`'C:\Users\H' is not recognized...`). Solusi: pindahkan Flutter
  ke path tanpa spasi. Test yang sudah ada memakai fake (tanpa Firebase) sehingga tetap
  valid setelah bloker diperbaiki; test Firestore sungguhan via emulator (Fase 5).
