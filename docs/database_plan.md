# Rencana Database PilahIn (SQLite lokal)

> Status: **Fase 1 selesai** (2026-11-02). Fase 2–3 belum diimplementasikan.
> DB: SQLite via `sqflite`, file `pilahin.db`, versi skema **3**.
> Satu-satunya titik akses DB adalah `lib/core/db/app_database.dart` (class `AppDatabase`) — semua repository wajib lewat sana agar skema & versi dikelola di satu tempat.

## 1. Skema (10 tabel)

### A. Reference data — di-seed sekali saat install (idempoten via `INSERT OR IGNORE`)

**`waste_types`** — 12 baris, dibuat dari enum `WasteType` (sumber kebenaran tunggal = enum; `label_key` harus sama dengan label dataset ML).

```sql
CREATE TABLE waste_types (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    label_key     TEXT NOT NULL UNIQUE,      -- 'battery', 'biological', dst.
    display_name  TEXT NOT NULL,
    category      TEXT NOT NULL CHECK (category IN ('organik','anorganik')),
    is_hazardous  INTEGER NOT NULL DEFAULT 0,
    icon_key      TEXT,                      -- nama ikon (IconData.iconName)
    is_active     INTEGER NOT NULL DEFAULT 1
);
```

**`eco_impact`** — 12 baris, 1:1 dengan `waste_types` (disalin dari `eco_impact.dart`).

```sql
CREATE TABLE eco_impact (
    waste_type_id             INTEGER PRIMARY KEY REFERENCES waste_types(id) ON DELETE CASCADE,
    co2_saved_kg              REAL NOT NULL,
    primary_metric_label      TEXT,
    primary_metric_value      TEXT,
    primary_metric_icon       TEXT,
    decomposition_time        TEXT,
    environmental_equivalence TEXT,
    action_tip                TEXT,
    highlight_fact            TEXT
);
```

**`levels`** — ambang level. Level 3 & ambang 1000 konsisten dengan mock lama (850 poin, sisa 150 → ambang berikutnya 1000).

```sql
CREATE TABLE levels (
    level      INTEGER PRIMARY KEY,
    name       TEXT NOT NULL,
    min_points INTEGER NOT NULL,
    icon_key   TEXT
);
```
Seed: (1, "Pemilah Pemula", 0), (2, "Juru Kompos", 300), (3, "Penyelamat Bumi", 700), (4, "Duta Daur Ulang", 1000), (5, "Dewa Ekosistem", 2000).

**`badges`** — definisi 15 lencana (dari `MockGamificationRepository`). Kolom `metric` + `waste_type_ids` menyatakan cara menghitung progres (dipakai Fase 2).

```sql
CREATE TABLE badges (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    code           TEXT NOT NULL UNIQUE,     -- slug, mis. 'raja_botol'
    name           TEXT NOT NULL,
    description    TEXT NOT NULL,
    category       TEXT NOT NULL CHECK (category IN ('organik','anorganik','streak','umum')),
    icon_key       TEXT NOT NULL,
    target         INTEGER NOT NULL,
    unit           TEXT NOT NULL,            -- 'organik', 'botol', 'hari', 'pemindaian'
    reward_points  INTEGER NOT NULL DEFAULT 0,
    metric         TEXT NOT NULL DEFAULT 'total'
                   CHECK (metric IN ('total','kategori_organik','kategori_anorganik','jenis','streak')),
    waste_type_ids TEXT,                     -- label_key dipisah ',' saat metric='jenis'
    is_active      INTEGER NOT NULL DEFAULT 1
);
```

**`missions`** — definisi misi. `metric` menentukan apa yang dihitung; `waste_type_id` hanya dipakai saat `metric='jenis'`.

```sql
CREATE TABLE missions (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    code          TEXT NOT NULL UNIQUE,
    title         TEXT NOT NULL,
    unit          TEXT NOT NULL,
    target        INTEGER NOT NULL,
    reward_points INTEGER NOT NULL DEFAULT 0,
    period        TEXT NOT NULL CHECK (period IN ('harian','mingguan')),
    metric        TEXT NOT NULL CHECK (metric IN ('total','kategori_organik','kategori_anorganik','jenis')),
    waste_type_id INTEGER REFERENCES waste_types(id),
    is_active     INTEGER NOT NULL DEFAULT 1
);
```
Seed:
- `misi_harian_organik` — "Pilah 3 Sampah Organik", target 3, hadiah 30, harian, `kategori_organik`.
- `misi_mingguan_plastik` — "Deteksi 10 Botol Plastik", target 10, hadiah 50, mingguan, `jenis` → plastic.

### B. Data pengguna

**`users`** — tamu = baris permanen (`guest_id`); akun = email + hash password (SHA-256 ber-garam email, fungsi di `core/db/password_hasher.dart`).

```sql
CREATE TABLE users (
    id               TEXT PRIMARY KEY,       -- 'guest_id' atau 'user_1', dst.
    email            TEXT UNIQUE,            -- NULL untuk tamu
    password_hash    TEXT,                   -- NULL untuk tamu
    display_name     TEXT NOT NULL,
    is_guest         INTEGER NOT NULL DEFAULT 0,
    total_points     INTEGER NOT NULL DEFAULT 0,   -- cache dari point_transactions
    current_streak   INTEGER NOT NULL DEFAULT 0,
    best_streak      INTEGER NOT NULL DEFAULT 0,
    last_active_date TEXT,                   -- 'YYYY-MM-DD' (zona waktu lokal)
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL
);
```

**`scan_history`** — pengembangan tabel v2: +`user_id`, +`waste_type_id`. Kolom lama `waste_type` (TEXT labelKey) dipertahankan agar skema install-migrasi dan install-fresh identik.

```sql
CREATE TABLE scan_history (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id       TEXT NOT NULL DEFAULT 'guest_id' REFERENCES users(id),
    scan_key      TEXT NOT NULL UNIQUE,      -- idempotency (sudah ada di v2)
    waste_type    TEXT,                      -- labelKey (kolom lama, tetap ditulis)
    waste_type_id INTEGER REFERENCES waste_types(id),
    category      TEXT NOT NULL,             -- denormalisasi utk query statistik cepat
    confidence    REAL NOT NULL,
    is_uncertain  INTEGER NOT NULL,
    item_name     TEXT,
    points_earned INTEGER NOT NULL,
    image_path    TEXT,
    created_at    INTEGER NOT NULL
);
CREATE INDEX idx_scan_user_created ON scan_history(user_id, created_at);
CREATE INDEX idx_scan_type ON scan_history(waste_type_id);
CREATE INDEX idx_scan_created ON scan_history(created_at);
```

**`user_badges`** — progres per user; `unlocked_at` NULL = masih terkunci.

```sql
CREATE TABLE user_badges (
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id    INTEGER NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    progress    INTEGER NOT NULL DEFAULT 0,
    unlocked_at INTEGER,
    PRIMARY KEY (user_id, badge_id)
);
```

**`user_missions`** — progres per user per periode; reset harian/mingguan via baris `period_start` baru.

```sql
CREATE TABLE user_missions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mission_id   INTEGER NOT NULL REFERENCES missions(id) ON DELETE CASCADE,
    period_start TEXT NOT NULL,              -- 'YYYY-MM-DD' (harian) / senin ISO (mingguan)
    progress     INTEGER NOT NULL DEFAULT 0,
    status       TEXT NOT NULL DEFAULT 'berjalan' CHECK (status IN ('berjalan','selesai','diklaim')),
    claimed_at   INTEGER,
    UNIQUE (user_id, mission_id, period_start)
);
```

**`point_transactions`** — ledger poin (sumber kebenaran total poin).

```sql
CREATE TABLE point_transactions (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delta      INTEGER NOT NULL,             -- +15 scan, +30 misi, +100 lencana, -n penyesuaian
    reason     TEXT NOT NULL CHECK (reason IN ('scan','misi','lencana','penyesuaian')),
    ref_type   TEXT,                         -- 'scan' | 'user_mission' | 'user_badge' | NULL
    ref_id     INTEGER,
    created_at INTEGER NOT NULL
);
CREATE INDEX idx_points_user ON point_transactions(user_id, created_at);
```

Catatan: `PRAGMA foreign_keys = ON` dijalankan tiap koneksi dibuka (default sqflite OFF).

## 2. Data Seed

| Tabel | Sumber | Jumlah |
|---|---|---|
| `waste_types` | Enum `WasteType` (`core/waste/waste_types.dart`) | 12 |
| `eco_impact` | `getEcoImpactForWasteType()` (`features/result/domain/eco_impact.dart`) | 12 |
| `levels` | Definisi di atas (PM bisa revisi nama/ambang) | 5 |
| `badges` | `MockGamificationRepository.getBadges()` + kolom metric baru | 15 |
| `missions` | Mock misi + misi harian beranda | 2 |
| `users` | Baris `guest_id` + akun demo (`kel5pbl@gmail.com`, hash `pilahln123`) | 2 |

Konten `guidance_content.dart` (panduan) **tetap di code** — konten statis; baru dipindah ke asset JSON bila PM ingin diubah tanpa rilis.

## 3. Migrasi v2 → v3 (`onUpgrade`)

1. Buat 9 tabel baru + index (`CREATE ... IF NOT EXISTS`).
2. Seed semua tabel reference + `users` (idempoten).
3. `ALTER TABLE scan_history ADD COLUMN user_id TEXT NOT NULL DEFAULT 'guest_id'` dan `ADD COLUMN waste_type_id INTEGER`.
4. Backfill: `UPDATE scan_history SET waste_type_id = (SELECT id FROM waste_types WHERE label_key = scan_history.waste_type) WHERE waste_type IS NOT NULL`.
5. Riwayat lama otomatis jadi milik akun tamu — tidak ada data hilang.

(Jalur `onUpgrade` juga menangani install era v1: kolom `waste_type` dulu ditambahkan di langkah v1→v2, lalu v2→v3.)

## 4. Alur Bisnis Fase 2 (pipeline setelah tiap scan, satu transaksi)

1. `INSERT scan_history` (user aktif: tamu atau login).
2. `INSERT point_transactions` (+`MlConfig.scanPointsReward`, reason `scan`).
3. `UPDATE users`: `total_points` + aturan streak:
   - `last_active_date == hari ini` → streak tetap
   - `== kemarin` → `current_streak + 1`
   - selain itu → `current_streak = 1`; `best_streak = max(...)`; `last_active_date = hari ini`.
4. **Rekomputasi** `user_badges` & `user_missions` dari agregasi `scan_history`:
   - `jenis` → `COUNT(*) WHERE waste_type_id IN (daftar)` / `kategori_*` → `COUNT(*) WHERE category = ?` / `total` → `COUNT(*)` / `streak` → ambil `users.current_streak`.
   - Misi harian `period_start = hari ini`, mingguan = Senin ISO.
5. Badge baru terbuka → `unlocked_at = now` + `INSERT point_transactions` (reason `lencana`); misi selesai → status `selesai` (→ `diklaim` + transaksi saat user menekan klaim).

Turunan:
- Level: `SELECT * FROM levels WHERE min_points <= total_points ORDER BY level DESC LIMIT 1`; `pointsToNextLevel = min_points(level berikutnya) − total_points`.
- Donut profil: `GROUP BY category` dari `scan_history` difilter `user_id`.
- Hapus/undo riwayat: `INSERT point_transactions` delta negatif (reason `penyesuaian`) + kurangi `total_points`; badge yang sudah terbuka **tidak** dikunci lagi.

## 5. Pemetaan ke Kode

```
lib/core/db/
  app_database.dart      -- AppDatabase: openDatabase, PRAGMA, version 3, onCreate/onUpgrade, provider
  seeds.dart             -- insertSeedData(): 12 waste types, 12 eco, 5 levels, 15 badges, 2 misi, 2 users
  password_hasher.dart   -- hashPassword(email, password) SHA-256 ber-garam email
  users_repository.dart  -- DbUser + UsersRepository (findById/findByEmail/getOrCreateGuest)
lib/features/auth/data/        -- LocalAuthRepository: login & sesi dibaca dari tabel users
lib/features/gamification/data/
  sqflite_gamification_repository.dart  -- [FASE 2] implementasi nyata interface yang sudah ada
lib/features/home/data/
  sqflite_home_repository.dart          -- [FASE 2] HomeSummary dihitung dari users+levels+user_missions
```

Interface `GamificationRepository`, `HomeRepository`, `AuthRepository` tidak berubah; `HistoryRepository` ditambah parameter opsional `userId` (filter per akun).

## 6. Tahapan

| Fase | Isi | Status |
|---|---|---|
| **1 – Fondasi DB** | `app_database.dart` (v3 + seed + migrasi), auth dari tabel `users`, penyatuan akses DB dengan `SqfliteHistoryRepository` (+ filter riwayat per user), `HistoryEntry.userId` | ✅ Selesai 2026-11-02 |
| **2 – Pipeline gamifikasi** | Transaksi post-scan (poin, streak, recompute badge/misi), `SqfliteGamificationRepository` & `SqfliteHomeRepository` menggantikan mock | ⏳ |
| **3 – Rapikan & uji** | Layar Beranda/Profil/Misi/Lencana membaca data nyata; uji hapus+undo; unit test repository (lihat catatan lingkungan test di bawah) | ⏳ |

## 7. Catatan Lingkungan Test (known issue)

- **`flutter test` saat ini TIDAK bisa dijalankan di mesin ini** — masalah *pre-existing*, bukan efek Fase 1:
  build hook native asset (`objective_c`, dependensi transitive yang sudah ada di `pubspec.lock` HEAD) gagal
  karena path instalasi Flutter SDK mengandung spasi (`C:\Users\H P\flutter\...`) dan tooling Dart
  tidak meng-quote path `dart.exe` saat mem-compile hook-nya
  (`'C:\Users\H' is not recognized as an internal or external command`).
- **Solusi permanen**: pindah instalasi Flutter ke path tanpa spasi (mis. `C:\flutter`), lalu `flutter test`
  akan berfungsi normal. Aplikasi di perangkat **tidak** terpengaruh (produksi memakai `sqflite` via
  platform channel, bukan native asset).
- **Mitigasi sementara (sudah diterapkan)**:
  - `sqflite_common_ffi` **tidak** dipakai (ditambah lalu dihapus) — dependensinya `sqlite3` memaksa build
    native asset di semua test dan memperburuk error di atas.
  - `LocalAuthRepository` diuji dengan **`FakeUsersRepository`** in-memory
    (`test/features/auth/data/local_auth_repository_test.dart`) — logika login/sesi tetap teruji tanpa DB.
  - `hashPassword`/`verifyPassword` diuji langsung (pure Dart, `test/core/db/password_hasher_test.dart`).
  - Widget/integration test memakai `FakeAuthRepository` + `FakeHistoryRepository`
    (`test/features/auth/helpers/fake_auth_repository.dart`) — hermetic, tanpa SQLite.
- **Yang belum teruji otomatis**: eksekusi DDL/migrasi/seed sungguhan (baris SQL `AppDatabase` +
  `seeds.dart`). Sudah di-review manual; verifikasi akhir lewat menjalankan app di perangkat
  (install baru = `onCreate`; atau upgrade dari build lama = jalur `onUpgrade` v2→v3).
