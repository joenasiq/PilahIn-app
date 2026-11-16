import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'scan_image_cropper.dart';

abstract class ScanCameraService {
  Future<void> initialize();
  Future<void> dispose();
  Future<String?> takePicture();
  Future<void> setFlash(bool isFlashOn);
  Widget getPreviewWidget();

  /// Rasio aspek (lebar / tinggi) preview kamera saat ini, atau null bila
  /// kamera belum siap.
  double? get previewAspectRatio;
}

class CameraPackageService implements ScanCameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];

  @override
  Future<void> initialize() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      throw Exception('Tidak ada kamera yang ditemukan di perangkat ini.');
    }

    final backCamera = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _controller!.initialize();
  }

  @override
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }

  @override
  Future<String?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return null;
    }
    
    if (_controller!.value.isTakingPicture) {
      return null;
    }

    final XFile file = await _controller!.takePicture();
    return cropImageToScanAspect(file.path);
  }

  @override
  Future<void> setFlash(bool isFlashOn) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    await _controller!.setFlashMode(
      isFlashOn ? FlashMode.torch : FlashMode.off,
    );
  }

  @override
  Widget getPreviewWidget() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(_controller!);
  }

  @override
  double? get previewAspectRatio {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    final size = controller.value.previewSize;
    if (size == null || size.width <= 0 || size.height <= 0) return null;
    // previewSize selalu dalam orientasi sensor (landscape). App dikunci
    // portrait, sehingga rasio tampilan = sisi pendek / sisi panjang.
    final longSide = math.max(size.width, size.height);
    final shortSide = math.min(size.width, size.height);
    if (longSide <= 0) return null;
    return shortSide / longSide;
  }
}
