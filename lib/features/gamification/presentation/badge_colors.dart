import 'package:flutter/material.dart';

/// Pasangan warna gradient untuk badge.
typedef BadgeColors = ({Color start, Color end});

/// Palet gradient per badge agar setiap lencana punya identitas warna sendiri
/// (bukan hanya per kategori, yang membuat semua badge "umum" tampak sama).
const Map<String, BadgeColors> _badgePalette = {
  'pahlawan_hijau': (start: Color(0xFF34D399), end: Color(0xFF047857)),
  'pemilah_pemula': (start: Color(0xFFFBBF24), end: Color(0xFFD97706)),
  'api_semangat': (start: Color(0xFFFB923C), end: Color(0xFFEA580C)),
  'raja_botol': (start: Color(0xFF38BDF8), end: Color(0xFF0369A1)),
  'pengumpul_kertas': (start: Color(0xFF2DD4BF), end: Color(0xFF0F766E)),
  'pejuang_lingkungan': (start: Color(0xFF818CF8), end: Color(0xFF4338CA)),
  'master_kompos': (start: Color(0xFF84CC16), end: Color(0xFF4D7C0F)),
  'dewa_daur_ulang': (start: Color(0xFF22D3EE), end: Color(0xFF0E7490)),
  'legenda_streak': (start: Color(0xFFF87171), end: Color(0xFFB91C1C)),
  'penyelamat_bumi': (start: Color(0xFFA78BFA), end: Color(0xFF6D28D9)),
  'ksatria_kaca': (start: Color(0xFF94A3B8), end: Color(0xFF475569)),
  'pecinta_sayur': (start: Color(0xFF4ADE80), end: Color(0xFF15803D)),
  'pemilah_setia': (start: Color(0xFFFCD34D), end: Color(0xFFB45309)),
  'guardian': (start: Color(0xFF64748B), end: Color(0xFF1E293B)),
  'organik_spesialis': (start: Color(0xFF6EE7B7), end: Color(0xFF059669)),
  'login_streak_7': (start: Color(0xFFFDBA74), end: Color(0xFFC2410C)),
};

/// Palet cadangan untuk badge yang belum terdaftar (mis. badge baru dari
/// backend). Dipilih deterministik dari id agar tidak berubah tiap rebuild.
const List<BadgeColors> _fallbackPalette = [
  (start: Color(0xFF34D399), end: Color(0xFF047857)),
  (start: Color(0xFF38BDF8), end: Color(0xFF0369A1)),
  (start: Color(0xFFFBBF24), end: Color(0xFFD97706)),
  (start: Color(0xFFA78BFA), end: Color(0xFF6D28D9)),
  (start: Color(0xFFFB923C), end: Color(0xFFEA580C)),
  (start: Color(0xFF2DD4BF), end: Color(0xFF0F766E)),
  (start: Color(0xFFF87171), end: Color(0xFFB91C1C)),
  (start: Color(0xFF84CC16), end: Color(0xFF4D7C0F)),
  (start: Color(0xFF22D3EE), end: Color(0xFF0E7490)),
  (start: Color(0xFF818CF8), end: Color(0xFF4338CA)),
];

/// Warna gradient badge berdasarkan id badge. Setiap badge punya warna
/// sendiri sehingga lencana di Beranda tidak tampak seragam.
BadgeColors badgeColorFor(String badgeId) {
  final known = _badgePalette[badgeId];
  if (known != null) return known;

  var hash = 0;
  for (final unit in badgeId.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return _fallbackPalette[hash % _fallbackPalette.length];
}
