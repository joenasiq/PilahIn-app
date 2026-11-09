import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/history/domain/history_entry.dart';
import '../providers/shared_preferences_provider.dart';

/// Penyimpanan sementara progres pengguna tamu (lokal saja).
///
/// Data disimpan sebagai JSON di SharedPreferences. Kehilangan data saat
/// uninstall adalah perilaku yang diharapkan untuk tamu. Tujuan utama
/// store ini: saat tamu login/registrasi (Fase 3), progres bisa
/// dimigrasi ke akun cloud (auto-merge).
class GuestProgressStore {
  GuestProgressStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _scansKey = 'guest_scans_v1';

  /// Muat semua scan tamu. `id` di-assign sesuai urutan list agar
  /// konsisten dengan [HistoryRepository] yang memakai `int` id.
  List<HistoryEntry> loadScans() {
    final raw = _prefs.getString(_scansKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final entries = list
          .map((e) => HistoryEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      for (var i = 0; i < entries.length; i++) {
        entries[i] = entries[i].copyWith(id: i + 1);
      }
      return entries;
    } catch (_) {
      // JSON korup: mulai dari kosong (data tamu tidak kritis).
      return [];
    }
  }

  /// Simpan seluruh daftar scan tamu.
  Future<void> saveScans(List<HistoryEntry> entries) async {
    final list = entries.map((e) => e.toMap()).toList();
    await _prefs.setString(_scansKey, jsonEncode(list));
  }

  bool hasScans() => loadScans().isNotEmpty;

  /// Kosongkan progres tamu (dipanggil setelah merge ke akun berhasil).
  Future<void> clear() async {
    await _prefs.remove(_scansKey);
  }
}

/// Provider terpusat store progres tamu (dipakai routing repository,
/// auto-merge saat login, dan home/gamification tamu).
final guestProgressStoreProvider = Provider<GuestProgressStore>((ref) {
  return GuestProgressStore(ref.watch(sharedPreferencesProvider));
});
