import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider SharedPreferences terpusat (dipakai auth, guest store, dll.).
/// Dipindah dari auth_controller agar tidak terjadi import melingkar.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});
