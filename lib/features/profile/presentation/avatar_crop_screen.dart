import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/avatar_cropper.dart';
import '../data/avatar_service.dart';

/// Layar pengaturan crop foto profil.
///
/// Panduan memakai kotak persegi dengan garis lingkaran di dalamnya, supaya
/// pengguna melihat hasil akhir yang akan tampil sebagai avatar bulat.
/// Mengembalikan byte JPEG 512x512 lewat `Navigator.pop`, atau null bila
/// dibatalkan.
class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.source});

  final AvatarCropSource source;

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  double _scale = minAvatarCropScale;
  Offset _offset = Offset.zero;
  bool _isProcessing = false;

  // Status awal gesture.
  double _startScale = minAvatarCropScale;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  /// Sisi area crop; dihitung dari lebar layar dikurangi margin.
  double _viewportSide = 0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Area crop memakai sisi terkecil layar supaya selalu muat.
    final available = media.size.width - 48;
    _viewportSide = available.clamp(200.0, 420.0);

    final coverScale = avatarCoverScale(
      imageSize: widget.source.size,
      viewportSide: _viewportSide,
    );
    final displayScale = coverScale * _scale;
    final displayedWidth = widget.source.width * displayScale;
    final displayedHeight = widget.source.height * displayScale;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text(
          'Atur Foto Profil',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _reset,
            child: const Text(
              'Reset',
              style: TextStyle(color: Color(0xFF6EE7B7)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: _viewportSide,
                height: _viewportSide,
                child: ClipRect(
                  child: GestureDetector(
                    onScaleStart: _isProcessing ? null : _onScaleStart,
                    onScaleUpdate: _isProcessing ? null : _onScaleUpdate,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Positioned(
                          left: _viewportSide / 2 + _offset.dx - displayedWidth / 2,
                          top: _viewportSide / 2 + _offset.dy - displayedHeight / 2,
                          width: displayedWidth,
                          height: displayedHeight,
                          child: Image.memory(
                            widget.source.bytes,
                            fit: BoxFit.fill,
                            gaplessPlayback: true,
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _CropOverlayPainter(
                                viewportSide: _viewportSide,
                              ),
                            ),
                          ),
                        ),
                        if (_isProcessing)
                          const Positioned.fill(
                            child: ColoredBox(
                              color: Color(0x990B1220),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF34D399),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Geser dan cubit untuk mengatur posisi foto. '
              'Area di dalam lingkaran akan menjadi foto profil bulat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, media.padding.bottom + 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF475569)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Gunakan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      _scale = minAvatarCropScale;
      _offset = Offset.zero;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _startScale = _scale;
    _startOffset = _offset;
    _startFocal = details.localFocalPoint - Offset(_viewportSide / 2, _viewportSide / 2);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final focal =
        details.localFocalPoint - Offset(_viewportSide / 2, _viewportSide / 2);
    final newScale = (_startScale * details.scale).clamp(
      minAvatarCropScale,
      maxAvatarCropScale,
    );

    // Jaga titik di bawah jari tetap di tempat saat zoom berubah.
    final ratio = newScale / _startScale;
    final nextOffset = Offset(
      focal.dx - (_startFocal.dx - _startOffset.dx) * ratio,
      focal.dy - (_startFocal.dy - _startOffset.dy) * ratio,
    );

    setState(() {
      _scale = newScale;
      _offset = clampAvatarOffset(
        imageSize: widget.source.size,
        viewportSide: _viewportSide,
        scale: newScale,
        offset: nextOffset,
      );
    });
  }

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);
    try {
      final cropRect = computeAvatarCropRect(
        imageSize: widget.source.size,
        viewportSide: _viewportSide,
        scale: _scale,
        offset: _offset,
      );
      final bytes = await cropAvatarCircle(
        source: widget.source,
        cropRect: cropRect,
        maxBytes: AvatarService.maxPayloadBytes,
      );
      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto tidak dapat diproses. Coba foto lain.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }
}

/// Menggelapkan area di luar lingkaran crop.
///
/// Panduan berbentuk lingkaran penuh karena hasil foto profil disimpan
/// sebagai PNG dengan sudut transparan (bulat).
class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({required this.viewportSide});

  final double viewportSide;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = viewportSide / 2 - 1;

    // Area di luar lingkaran diredupkan.
    final overlay = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawPath(
      overlay,
      Paint()..color = const Color(0x99000000),
    );

    // Ring luar tipis sebagai penegas batas.
    canvas.drawCircle(
      center,
      radius + 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.25),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) =>
      oldDelegate.viewportSide != viewportSide;
}
