/// Perubahan streak scan sebelum dan sesudah sebuah pemindaian disimpan.
///
/// Dipakai layar Hasil untuk memutuskan apakah popup "streak bertambah"
/// perlu ditampilkan.
class StreakUpdate {
  const StreakUpdate({required this.previous, required this.current});

  /// Streak tidak diketahui (mis. recompute gagal). Popup tidak ditampilkan.
  const StreakUpdate.unknown()
    : previous = -1,
      current = -1;

  final int previous;
  final int current;

  /// True bila streak benar-benar bertambah pada pemindaian ini.
  ///
  /// Scan pertama (0 -> 1) juga dianggap bertambah.
  bool get increased => current > previous && current > 0;

  @override
  String toString() => 'StreakUpdate($previous -> $current)';

  @override
  bool operator ==(Object other) =>
      other is StreakUpdate &&
      other.previous == previous &&
      other.current == current;

  @override
  int get hashCode => Object.hash(previous, current);
}
