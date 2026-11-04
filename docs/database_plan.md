# Rencana Penyimpanan Data PilahIn (Lokal + Firebase Cloud)

> Status: **Fase 1–3 selesai** (2026-11-04). Fase 4–5 belum diimplementasikan.
>
> **Log perubahan**: 2026-11-04 — Fase 3 selesai: pipeline gamifikasi cloud
> (recompute total poin/streak/badge/misi setelah tiap scan + auto-merge
> tamu→akun saat login), repository gamifikasi & home (Firebase + guest),
> reference data di kode, test `progress_calculator`.
> 2026-11-03 — arsitektur diganti dari "SQLite lokal 100%" menjadi
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

### `users/{uid}/scans/{docId}` (doc ID = scanKey tersanitasi: `/` & `\` → `_`; idempoten)
```
scan_key      : String  -- kunci idempotensi asli (bisa berisi '/')
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

### `users/{uid}/badges/{code}` (doc ID = code definisi, mis. `pahlawan_hijau`)
```
code        : String (== doc ID)
progress    : int       -- minimal target jika sudah terbuka (tidak pernah turun
                          di bawah target => badge terbuka tidak dikunci lagi)
unlocked_at : int?      -- millisecondsSinceEpoch
```

### `users/{uid}/missions/{code}_{periodStart}` (mis. `misi_harian_organik_2026-11-03`)
```
code         : String   -- disimpan eksplisit: kode misi mengandung '_',
                           tidak bisa di-parse andal dari doc ID
progress     : int      -- scan periode berjalan yang memenuhi metrik
status       : 'berjalan' | 'selesai-diklaim'   -- selesai = OTOMATIS diklaim
                                                     (UI tidak punya tombol klaim)
period_start : String   -- 'YYYY-MM-DD' (harian) / tanggal Senin (mingguan)
reward_points: int
claimed_at   : int?     -- diisi saat pertama kali mencapai 'selesai-diklaim'
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

## 4. Alur Bisnis Gamifikasi (recompute dari nol, satu batch write)

Setiap perubahan scan (scan baru, hapus/undo, merge tamu) memicu
`ProgressionService.recomputeAll()` — **seluruh** gamifikasi dihitung ulang
dari agregasi scan, bukan di-increment. Konsekuensi: data selalu konsisten
("self-healing"), tidak ada drift/ketagihan meskipun ada penghapusan scan.

1. `set users/{uid}/scans/{docId}` (tamu → lokal dulu, akun → Firestore).
2. **Recompute** (4 read + 1 `WriteBatch`):
   - `total_points = sum(scan.points_earned) + sum(hadiah badge terbuka)
     + sum(hadiah misi 'selesai-diklaim', semua periode)`
   - `current_streak` = hari lokal beruntun dengan scan, diakhiri hari ini
     (boleh kemarin); `best_streak = max(terimpan, terhitung)`.
   - Badge: progres per metrik (`total`/`kategori_*`/`jenis`/`streak`);
     baru terbuka → `unlocked_at = now`; **yang sudah terbuka tidak
     pernah terkunci lagi** (progress disimpan minimal `target`).
   - Misi: hanya periode berjalan yang di-recompute (harian: hari ini,
     mingguan: Senin ini); selesai → status `selesai-diklaim` + `claimed_at`
     (**auto-claim** — UI tidak punya tombol klaim); misi periode lama
     tidak disentuh (hadiahnya tetap terhitung).
   - `last_active_date` = tanggal scan terbaru (null jika tidak ada scan).
3. Gagal recompute tidak menggagalkan penyimpanan scan (dilog; scan tetap
   valid dan recompute berikutnya memperbaiki state).

Turunan:
- Level: `levelForPoints(total_points)` dari `kLevels`; `pointsToNextLevel = ambang(level berikut) − total_points` (0 jika level maks).
- Poin tamu (tanpa persistensi): poin scan + hadiah badge terbuka + hadiah misi periode berjalan — dihitung ulang tiap baca (`computeDerivedPoints`).
- Donut profil: `countByCategory` dari repository riwayat aktif.

## 5. Auto-Merge Tamu → Akun (Fase 3)

- Progres tamu (list scan) ada di `GuestProgressStore` (SharedPreferences JSON).
- Saat login/registrasi berhasil **dan** store berisi data
  (`FirebaseAuthRepository._mergeGuestProgress`):
  1. Batch-write semua scan tamu → `users/{uid}/scans/{docId}`
     (doc ID = `sanitizeScanDocId(scanKey)`; `set(merge)` → aman diulang).
  2. `ProgressionService.recomputeAll()` — scan tamu ikut terhitung.
  3. `GuestProgressStore.clear()`.
- Tamu tanpa progres → tidak ada yang di-merge. Gagal merge → login tetap
  berhasil; data tamu aman di lokal (dicoba lagi saat login berikutnya).
- Registrasi (Fase 4) memakai alur yang sama: `register` → `_ensureUserDocument`
  → `_mergeGuestProgress`.

## 6. Pemetaan ke Kode

```
lib/main.dart                                    -- Firebase.initializeApp() (Android)
lib/core/firebase/
  firebase_providers.dart                        -- firebaseAuthProvider, firebaseFirestoreProvider
  scan_doc_id.dart                               -- sanitizeScanDocId (dipakai semua repo scan)
lib/core/providers/
  shared_preferences_provider.dart               -- sharedPreferencesProvider (netral, hindari import melingkar)
lib/core/guest/
  guest_progress_store.dart                      -- GuestProgressStore + guestProgressStoreProvider
lib/features/auth/data/
  firebase_auth_repository.dart                  -- login/guest/logout/getCurrentUser + _mergeGuestProgress
  local_auth_repository.dart                     -- [DIHAPUS FASE 5] versi SQLite
lib/features/gamification/domain/
  reference_data.dart                            -- kLevels, kBadges (15, +metric), kMissions (2)
  progress_calculator.dart                       -- fungsi murni: dateKey/mondayKey/computeStreak/
                                                   aggregateScans/badgeProgress/missionProgress/
                                                   computeDerivedPoints (unit-testable)
lib/features/gamification/data/
  progression_service.dart                       -- recomputeAll(): 4 read + 1 WriteBatch (akun)
  firebase_gamification_repository.dart          -- baca badge & misi dari Firestore
  guest_gamification_repository.dart             -- turunan dari GuestProgressStore
  mock_gamification_repository.dart              -- [DIHAPUS FASE 5] hanya dipakai test
lib/features/home/data/
  firebase_home_repository.dart                  -- HomeSummary dari Firestore (akun)
  guest_home_repository.dart                     -- HomeSummary turunan (tamu)
  mock_home_repository.dart                      -- [DIHAPUS FASE 5] hanya dipakai test
lib/features/history/data/
  firebase_history_repository.dart               -- Firestore users/{uid}/scans
  guest_history_repository.dart                  -- GuestProgressStore
  sqflite_history_repository.dart                -- [DIHAPUS FASE 5]
lib/features/history/presentation/
  history_provider.dart                          -- routing repository + hook recompute post-scan
lib/features/gamification/presentation/
  gamification_provider.dart                     -- routing repo + progressionServiceProvider
lib/features/home/presentation/
  home_provider.dart                             -- routing home repository
lib/core/db/                                     -- [DIHAPUS FASE 5] app_database, seeds, users_repository, password_hasher
[FASE 4] layar registrasi (dibuat tim)          -- dihubungkan ke FirebaseAuthRepository.register
```

Interface `AuthRepository`, `HistoryRepository`, `GamificationRepository`,
`HomeRepository` tidak berubah (`register` ditambahkan ke `AuthRepository` di Fase 4).

## 7. Tahapan

| Fase | Isi | Status |
|---|---|---|
| **1 – Fondasi DB lokal** | Schema v3, seed, auth SQLite, riwayat per-user | ✅ 2026-11-02 (peran berubah: jadi fondasi guest + reference) |
| **2 – Fondasi Firebase** | Dependency Firebase, `Firebase.initializeApp`, `FirebaseAuthRepository` (login/sesi via uid, pesan error konsisten), `FirebaseHistoryRepository` + `GuestHistoryRepository` + `GuestProgressStore`, routing provider, test guest repository, `late final` fix | ✅ 2026-11-03 |
| **3 – Gamifikasi cloud** | `reference_data` (level/badge/misi di kode), `progress_calculator` (fungsi murni + test), `ProgressionService.recomputeAll` (recompute total poin/streak/badge/misi, 1 batch), repo gamifikasi & home (Firebase + guest), routing provider, hook recompute post-scan, **auto-merge tamu→akun** | ✅ 2026-11-04 |
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
