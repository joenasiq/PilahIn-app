/// Doc ID Firestore tidak boleh mengandung '/', '\', atau null char.
/// [scanKey] PilahIn berisi path gambar (mis. `/data/user/0/.../img.jpg_123`),
/// jadi harus disanitasi sebelum dipakai sebagai doc ID.
///
/// Deterministik: scanKey yang sama selalu menghasilkan doc ID yang sama,
/// sehingga idempotency (set merge) tetap terjaga.
String sanitizeScanDocId(String scanKey) =>
    scanKey.replaceAll('/', '_').replaceAll('\\', '_');
