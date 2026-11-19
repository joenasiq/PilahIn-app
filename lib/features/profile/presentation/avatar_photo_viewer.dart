import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Penampil foto profil ukuran penuh.
///
/// Mendukung dua sumber: byte gambar dari Firestore (`fs:`) maupun URL lama
/// (`http`) untuk akun yang sempat memakai Firebase Storage.
class AvatarPhotoViewer extends StatelessWidget {
  const AvatarPhotoViewer({
    super.key,
    required this.title,
    this.bytes,
    this.networkUrl,
    this.onEdit,
  });

  /// Nama pengguna, ditampilkan sebagai judul.
  final String title;

  final Uint8List? bytes;
  final String? networkUrl;

  /// Bila tidak null, tombol "Ganti Foto" ditampilkan.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Center(child: _buildPhoto()),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Tutup',
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
            if (onEdit != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    onEdit!();
                  },
                  icon: const Icon(Icons.photo_camera_rounded, size: 18),
                  label: const Text('Ganti Foto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    final url = networkUrl?.trim() ?? '';
    if (url.isNotEmpty && url.startsWith('http')) {
      return _circle(
        Hero(
          tag: 'profile-avatar-photo',
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _error(),
          ),
        ),
      );
    }

    final data = bytes;
    if (data == null || data.isEmpty) return _error();

    return _circle(
      Hero(
        tag: 'profile-avatar-photo',
        child: Image.memory(
          data,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _error(),
        ),
      ),
    );
  }

  /// Foto dibingkai bulat agar konsisten dengan avatar kecil.
  ///
  /// Foto baru sudah PNG ber-alpha (sudut transparan), tapi foto lama bisa
  /// masih JPEG persegi — ClipOval membuat keduanya tampil sama.
  Widget _circle(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide * 0.86;
        return Center(
          child: Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: ClipOval(child: child),
          ),
        );
      },
    );
  }

  Widget _error() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          SizedBox(height: 12),
          Text(
            'Foto tidak dapat ditampilkan',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
