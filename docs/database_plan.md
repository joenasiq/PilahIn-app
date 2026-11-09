# Rencana Penyimpanan Data PilahIn (Lokal + Firebase Cloud)

> Status: **Fase 1–5 selesai** (2026-11-05). Sisa tugas sebelum demo/sidang:
> **deploy security rules** ke Firebase Console (deadline test mode: 2026-12-03)
> + uji skenario perangkat (multi-user, tamu→akun, ganti perangkat).
>
> **Log perubahan**: 2026-11-05 — Fase 5 (pembersihan arsitektur lama): hapus
> SQLite (`lib/core/db/` — app_database, seeds, users_repository,
> password_hasher — + `sqflite_history_repository`) dan `local_auth_repository`
> + test keduanya (auth lokal tidak dipakai lagi sejak Fase 2); dependency
> `sqflite` + `path_provider` dikeluarkan dari pubspec (`crypto` tersisa sebagai
> transitive); tambah `firebase/firestore.rules` (aturan final §8).
> `flutter analyze` bersih.
> 2026-11-04 (perbaikan pasca-merge) — merge branch `bgsa`
> (PR #7) menimbulkan conflict dua arsitektur data; resolusi manual merusak
> `history_entry.dart` (duplikat `userId`) dan memutus 3 implementasi interface
> baru. Diperbaiki: (1) deduplikasi `history_entry.dart`; (2)
> `FirebaseAuthRepository.register` (Fase 4 aktif); (3) 4 method baru
> `HistoryRepository` (`getBetween`, `countByWasteType`, `sumPointsEarned`,
> `hasScannedWasteTypeOn`) diimplementasi di repo Firebase + guest; (4) **routing
> riwayat dipulihkan ke cloud (Opsi A)**: akun → Firestore, tamu → lokal,
> hook recompute kembali berfungsi. Mesin gamifikasi lokal tim (PointsPolicy +
> PointsLedgerService) **dipertahankan**: `PointsPolicy` menentukan
> `points_earned` per scan sebelum ditulis ke Firestore; UI misi/beranda tetap
> versi tim yang kini membaca riwayat dari Firestore (lihat §4.1).
> 2026-11-04 — Fase 3 selesai: pipeline gamifikasi cloud
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

### 4.1 Koeksistensi dengan Mesin Gamifikasi Lokal Tim (pasca-merge `bgsa`)

Merge branch `bgsa` membawa mesin gamifikasi **lokal** (SharedPreferences).
Keputusan perbaikan (Opsi A, 2026-11-04): **jalur data = cloud, UI & aturan
per-scan = versi tim**. Pembagian peran:

| Komponen | Pemilik | Sumber data |
|---|---|---|
| `points_earned` per scan (`10/5/3`, batas 150/hari) | **Tim** — `PointsPolicy` | dihitung di `saveScanToHistory`, ditulis ke doc scan Firestore |
| `HistoryRepository` (4 method baru: `getBetween`, `countByWasteType`, `sumPointsEarned`, `hasScannedWasteTypeOn`) | **Juan** | repo Firebase + guest (akun → Firestore, tamu → lokal) |
| Tab Misi & klaim misi | **Tim** — `MissionService` + `PointsLedgerService` | progres dari riwayat (akun kini Firestore); status klaim di ledger **lokal** |
| Poin beranda/profil yang ditampilkan | **Tim** — `userProgressProvider` | poin dasar (dummy, khusus demo/tamu) + poin scan (akun kini dari Firestore) + hadiah login & misi (ledger lokal) |
| Tab Lencana | **Juan** — `badgesProvider` (+overlay klaim tim) | Firestore `users/{uid}/badges` |
| `total_points`/streak/badge/misi di `users/{uid}` | **Juan** — `ProgressionService` | recompute dari scan Firestore + hadiah badge/misi **cloud** (auto-claim) |

**Konsekuensi (divergensi yang disadari):** `users/{uid}.total_points`
(mengikutkan hadiah badge & misi engine cloud) tidak selalu sama dengan angka
poin yang ditampilkan UI (mengikutkan hadiah ledger lokal + poin dasar demo).
Kedua-duanya diturunkan dari **scan Firestore yang sama**, jadi inti data
(riwayat + poin per scan) konsisten. Penyatuan menjadi satu engine (Opsi C)
disarankan sebagai tahap pembersihan sebelum sidang.

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
- Registrasi memakai alur yang sama — **sudah diimplementasikan** di
  `FirebaseAuthRepository.register` (Fase 4): validasi (nama/email/panjang
  sandi) → `createUserWithEmailAndPassword` → `updateDisplayName` →
  `_ensureUserDocument(display_name)` → `_mergeGuestProgress` → sesi.

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
  firebase_auth_repository.dart                  -- login/**register**/guest/logout/getCurrentUser
                                                   + _ensureUserDocument + _mergeGuestProgress
lib/features/auth/domain/
  auth_validators.dart                           -- isValidEmail dkk (dipakai register)
lib/features/auth/presentation/
  register_screen.dart                           -- layar registrasi tim (Fase 4) -> AuthController.register
lib/features/gamification/domain/
  reference_data.dart                            -- kLevels, kBadges (15, +metric), kMissions (2)
  points_policy.dart                             -- [TIM] aturan poin per scan (10/5/3, limit 150/hari)
  progress_calculator.dart                       -- fungsi murni: dateKey/mondayKey/computeStreak/
                                                   aggregateScans/badgeProgress/missionProgress/
                                                   computeDerivedPoints (unit-testable)
lib/features/gamification/data/
  progression_service.dart                       -- recomputeAll(): 4 read + 1 WriteBatch (akun)
  firebase_gamification_repository.dart          -- baca badge & misi dari Firestore
  guest_gamification_repository.dart             -- turunan dari GuestProgressStore
  points_ledger_service.dart                     -- [TIM] ledger poin lokal (daily/login/klaim)
  mission_service.dart                           -- [TIM] misi harian/mingguan dari riwayat + klaim
  mock_gamification_repository.dart              -- test double (hanya dipakai test)
lib/features/home/data/
  firebase_home_repository.dart                  -- HomeSummary dari Firestore (akun)
  guest_home_repository.dart                     -- HomeSummary turunan (tamu)
  mock_home_repository.dart                      -- test double (hanya dipakai test)
lib/features/history/data/
  firebase_history_repository.dart               -- Firestore users/{uid}/scans (+4 method agregasi)
  guest_history_repository.dart                  -- GuestProgressStore (+4 method agregasi)
lib/features/history/presentation/
  history_provider.dart                          -- routing (tamu/akun) + saveScanToHistory (PointsPolicy)
                                                   + hook recompute post-scan + historyStatsProvider
lib/features/gamification/presentation/
  gamification_provider.dart                     -- routing repo + progressionServiceProvider + badges
  user_progress_provider.dart                    -- [TIM] total poin untuk UI (base + scan + ledger)
  mission_provider.dart                          -- [TIM] provider misi (harian/mingguan/klaim)
lib/features/home/presentation/
  home_provider.dart                             -- routing home repository + poin UI (userProgress)
firebase/
  firestore.rules                                -- security rules final (deploy via Console, §8)
```

Interface: `AuthRepository.register` (Fase 4) dan 4 method agregasi
`HistoryRepository` (branch tim: `getBetween`, `countByWasteType`,
`sumPointsEarned`, `hasScannedWasteTypeOn`) sudah diimplementasi di semua
repo yang ada (Firebase, guest, dan fake test). SQLite & auth lokal dihapus
di Fase 5 — arsitektur sekarang **satu jalur**: tamu → lokal, akun → Firestore.

## 7. Tahapan

| Fase | Isi | Status |
|---|---|---|
| **1 – Fondasi DB lokal** | Schema v3, seed, auth SQLite, riwayat per-user | ✅ 2026-11-02 (peran berubah: jadi fondasi guest + reference) |
| **2 – Fondasi Firebase** | Dependency Firebase, `Firebase.initializeApp`, `FirebaseAuthRepository` (login/sesi via uid, pesan error konsisten), `FirebaseHistoryRepository` + `GuestHistoryRepository` + `GuestProgressStore`, routing provider, test guest repository, `late final` fix | ✅ 2026-11-03 |
| **3 – Gamifikasi cloud** | `reference_data` (level/badge/misi di kode), `progress_calculator` (fungsi murni + test), `ProgressionService.recomputeAll` (recompute total poin/streak/badge/misi, 1 batch), repo gamifikasi & home (Firebase + guest), routing provider, hook recompute post-scan, **auto-merge tamu→akun** | ✅ 2026-11-04 |
| **4 – Integrasi registrasi** | Layar registrasi tim → `AuthRepository.register` + `users/{uid}` + auto-merge. `FirebaseAuthRepository.register` diimplementasi pasca-merge (validasi konsisten, `email-already-in-use` → 'Email sudah terdaftar', `_ensureUserDocument` + `_mergeGuestProgress`) | ✅ 2026-11-04 (pasca-merge) |
| **5 – Bersihkan & uji** | Hapus SQLite + local auth (`lib/core/db/`, sqflite repo, `local_auth_repository`, 2 test terkait, dep `sqflite`+`path_provider`), `firebase/firestore.rules`. **Sisa di sisi user**: deploy rules ke Console (sebelum 2026-12-03) + uji skenario perangkat (multi-user, tamu→akun, ganti perangkat) + test emulator (terblokir di mesin ini, §9) | ✅ 2026-11-05 (kodingan) |

## 8. Keamanan Firestore

Selama development: **test mode** (berlaku sampai **2026-12-03**). Rules final
sudah ada di `firebase/firestore.rules`; **WAJIB deploy sebelum test mode habis**
(Console → Firestore Database → Rules → paste isi file, atau
`firebase deploy --only firestore:rules`):

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
  valid setelah bloker diperbaiki; test Firestore sungguhan via emulator (sebelum demo).
