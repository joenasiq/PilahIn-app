import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gallery_picker_service.dart';
import '../data/scan_camera_service.dart';

final scanCameraServiceProvider = Provider<ScanCameraService>((ref) {
  return CameraPackageService();
});

final galleryPickerServiceProvider = Provider<GalleryPickerService>((ref) {
  return GalleryPickerService();
});

// Enum untuk status scan
enum ScanStatus {
  initial,
  loading,
  ready,
  permissionDenied,
  error,
  takingPicture,
}

// State untuk ScanController
class ScanState {
  final ScanStatus status;
  final bool isFlashOn;
  final String? errorMessage;

  const ScanState({
    this.status = ScanStatus.initial,
    this.isFlashOn = false,
    this.errorMessage,
  });

  ScanState copyWith({
    ScanStatus? status,
    bool? isFlashOn,
    String? errorMessage,
  }) {
    return ScanState(
      status: status ?? this.status,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ScanController extends Notifier<ScanState> {
  late final ScanCameraService _cameraService;
  late final GalleryPickerService _galleryService;

  @override
  ScanState build() {
    _cameraService = ref.watch(scanCameraServiceProvider);
    _galleryService = ref.watch(galleryPickerServiceProvider);
    
    // Kita tidak bisa memanggil initializeCamera() langsung di build 
    // karena bisa memicu side effects yang kompleks secara sinkron.
    // Tetapi karena ScanScreen akan memanggil initializeCamera() secara eksplisit 
    // saat tab aktif, kita biarkan inisialisasi awal kosong.
    return const ScanState();
  }

  Future<void> initializeCamera() async {
    if (state.status == ScanStatus.ready || state.status == ScanStatus.loading) {
      return;
    }

    state = state.copyWith(status: ScanStatus.loading);

    try {
      await _cameraService.initialize();
      state = state.copyWith(status: ScanStatus.ready, errorMessage: null);
    } on CameraException catch (e) {
      if (e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt') {
        state = state.copyWith(status: ScanStatus.permissionDenied);
      } else {
        state = state.copyWith(
          status: ScanStatus.error,
          errorMessage: 'Gagal menginisialisasi kamera: ${e.description}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: ScanStatus.error,
        errorMessage: 'Terjadi kesalahan: $e',
      );
    }
  }

  Future<void> disposeCamera() async {
    if (state.status == ScanStatus.initial || state.status == ScanStatus.error || state.status == ScanStatus.permissionDenied) {
      return;
    }
    await _cameraService.dispose();
    state = state.copyWith(status: ScanStatus.initial);
  }

  Future<void> toggleFlash() async {
    if (state.status != ScanStatus.ready) return;
    
    final newFlashState = !state.isFlashOn;
    await _cameraService.setFlash(newFlashState);
    state = state.copyWith(isFlashOn: newFlashState);
  }

  Future<String?> takePicture() async {
    if (state.status != ScanStatus.ready) return null;

    state = state.copyWith(status: ScanStatus.takingPicture);
    try {
      final path = await _cameraService.takePicture();
      // Matikan flash setelah foto jika menyala (opsional, tapi baik untuk UX)
      if (state.isFlashOn) {
        await toggleFlash();
      }
      state = state.copyWith(status: ScanStatus.ready);
      return path;
    } catch (e) {
      state = state.copyWith(
        status: ScanStatus.ready,
        errorMessage: 'Gagal mengambil foto: $e',
      );
      return null;
    }
  }

  Future<String?> pickFromGallery() async {
    return await _galleryService.pickImage();
  }
}

final scanControllerProvider = NotifierProvider<ScanController, ScanState>(ScanController.new);
