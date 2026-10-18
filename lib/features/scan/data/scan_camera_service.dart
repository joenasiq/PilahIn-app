import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

abstract class ScanCameraService {
  Future<void> initialize();
  Future<void> dispose();
  Future<String?> takePicture();
  Future<void> setFlash(bool isFlashOn);
  Widget getPreviewWidget();
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
    return file.path;
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
}
