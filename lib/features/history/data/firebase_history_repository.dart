import 'package:cloud_firestore/cloud_firestore.dart';

import '../../scan/domain/waste_category.dart';
import '../domain/history_entry.dart';
import '../domain/history_repository.dart';

/// Repository riwayat pengguna akun, berbasis Cloud Firestore.
///
/// Lokasi data: `users/{uid}/scans/{docId}`
/// - Doc ID = `scanKey` -> idempotency scan yang sama otomatis (set merge).
/// - Gambar TIDAK diunggah; field `image_path` hanya menyimpan path file
///   lokal di perangkat (sesuai keputusan tim: gambar lokal saja).
/// - `HistoryEntry.id` (int, dipakai UI untuk hapus/restore) adalah posisi
///   urut saat list dimuat (terbaru dulu). Pemetaan intId -> docId
///   disimpan di [_docIdsByIntId]; bila basi, [delete] memuat ulang.
class FirebaseHistoryRepository implements HistoryRepository {
  FirebaseHistoryRepository(this._firestore, {required this._uid});

  final FirebaseFirestore _firestore;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _scans =>
      _firestore.collection('users').doc(_uid).collection('scans');

  final Map<int, String> _docIdsByIntId = {};

  @override
  Future<void> add(HistoryEntry entry) async {
    final doc = _scans.doc(entry.scanKey);
    await doc.set(_toData(entry), SetOptions(merge: true));
  }

  @override
  Future<List<HistoryEntry>> getAll(
      {WasteCategory? category, String? userId}) async {
    Query<Map<String, dynamic>> query = _scans;
    if (category != null) {
      final label = category == WasteCategory.organik ? 'organik' : 'anorganik';
      query = query.where('category', isEqualTo: label);
    }
    final snapshot = await query.orderBy('created_at', descending: true).get();

    _docIdsByIntId.clear();
    final entries = <HistoryEntry>[];
    for (var i = 0; i < snapshot.docs.length; i++) {
      final doc = snapshot.docs[i];
      _docIdsByIntId[i + 1] = doc.id;
      entries.add(_fromDoc(doc, id: i + 1));
    }
    return entries;
  }

  @override
  Future<void> delete(int id) async {
    var docId = _docIdsByIntId[id];
    if (docId == null) {
      // Pemetaan basi (mis. repository baru dibuat): muat ulang dulu.
      await getAll();
      docId = _docIdsByIntId[id];
      if (docId == null) return;
    }
    await _scans.doc(docId).delete();
  }

  @override
  Future<void> restore(HistoryEntry entry) async {
    // Pulihkan berdasarkan scanKey (doc ID = scanKey).
    final doc = _scans.doc(entry.scanKey);
    await doc.set(_toData(entry), SetOptions(merge: true));
  }

  @override
  Future<int> count({String? userId}) async {
    final snapshot = await _scans.get();
    return snapshot.docs.length;
  }

  @override
  Future<Map<WasteCategory, int>> countByCategory({String? userId}) async {
    final snapshot = await _scans.get();
    var organik = 0;
    var anorganik = 0;
    for (final doc in snapshot.docs) {
      if (doc.data()['category'] == 'organik') {
        organik++;
      } else {
        anorganik++;
      }
    }
    return {
      WasteCategory.organik: organik,
      WasteCategory.anorganik: anorganik,
    };
  }

  Map<String, dynamic> _toData(HistoryEntry entry) {
    final map = entry.toMap();
    map.remove('id'); // doc ID Firestore = scanKey
    map['user_id'] = _uid;
    return map;
  }

  HistoryEntry _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc,
      {required int id}) {
    final data = doc.data()!;
    data['id'] = id;
    data['user_id'] ??= _uid;
    return HistoryEntry.fromMap(data);
  }
}
