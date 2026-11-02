import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Baris tabel `users` dalam bentuk data class.
class DbUser {
  final String id;
  final String? email;
  final String? passwordHash;
  final String displayName;
  final bool isGuest;
  final int totalPoints;
  final int currentStreak;
  final int bestStreak;
  final String? lastActiveDate;
  final int createdAt;
  final int updatedAt;

  const DbUser({
    required this.id,
    this.email,
    this.passwordHash,
    required this.displayName,
    required this.isGuest,
    required this.totalPoints,
    required this.currentStreak,
    required this.bestStreak,
    this.lastActiveDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DbUser.fromMap(Map<String, dynamic> map) {
    return DbUser(
      id: map['id'] as String,
      email: map['email'] as String?,
      passwordHash: map['password_hash'] as String?,
      displayName: map['display_name'] as String,
      isGuest: (map['is_guest'] as int) == 1,
      totalPoints: map['total_points'] as int,
      currentStreak: map['current_streak'] as int,
      bestStreak: map['best_streak'] as int,
      lastActiveDate: map['last_active_date'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }
}

/// Akses tabel `users`.
class UsersRepository {
  final AppDatabase _appDb;

  UsersRepository(this._appDb);

  static const String guestId = 'guest_id';

  Future<DbUser?> findById(String id) async {
    final db = await _appDb.database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return DbUser.fromMap(rows.first);
  }

  /// Cari berdasarkan email (case-insensitive).
  Future<DbUser?> findByEmail(String email) async {
    final db = await _appDb.database;
    final rows = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DbUser.fromMap(rows.first);
  }

  /// Ambil baris tamu; buat bila belum ada (safety net, normalnya dari seed).
  Future<DbUser> getOrCreateGuest() async {
    final db = await _appDb.database;
    final existing = await findById(guestId);
    if (existing != null) return existing;

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('users', {
      'id': guestId,
      'email': null,
      'password_hash': null,
      'display_name': 'Tamu',
      'is_guest': 1,
      'total_points': 0,
      'current_streak': 0,
      'best_streak': 0,
      'last_active_date': null,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return (await findById(guestId))!;
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(appDatabaseProvider));
});
