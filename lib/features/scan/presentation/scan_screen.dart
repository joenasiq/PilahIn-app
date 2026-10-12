import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/main_wrapper.dart';
import 'scan_controller.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final currentIndex = ref.read(currentBottomNavIndexProvider);
    // Index 1 adalah tab Pindai
    if (currentIndex == 1) {
      if (state == AppLifecycleState.resumed) {
        ref.read(scanControllerProvider.notifier).initializeCamera();
      } else if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
        ref.read(scanControllerProvider.notifier).disposeCamera();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);

    // Otomatis init/dispose saat tab berubah
    ref.listen(currentBottomNavIndexProvider, (previous, next) {
      if (next == 1) {
        ref.read(scanControllerProvider.notifier).initializeCamera();
      } else {
        ref.read(scanControllerProvider.notifier).disposeCamera();
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_ios, color: Colors.blue),
          onPressed: () {
            // Kembali ke tab beranda
            ref.read(currentBottomNavIndexProvider.notifier).setIndex(0);
            context.go('/home');
          },
        ),
        title: const Text('Pindai Sampah', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildCameraPreview(context, ref, scanState),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Arahkan Kamera ke Sampah',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            _buildBottomControls(context, ref, scanState),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(BuildContext context, WidgetRef ref, ScanState state) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.hardEdge,
      child: _buildPreviewContent(context, ref, state),
    );
  }

  Widget _buildPreviewContent(BuildContext context, WidgetRef ref, ScanState state) {
    switch (state.status) {
      case ScanStatus.initial:
      case ScanStatus.loading:
        return const Center(child: CircularProgressIndicator());
      
      case ScanStatus.permissionDenied:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_photography, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Izin kamera diperlukan untuk memindai sampah',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aktifkan lewat Pengaturan > Aplikasi > PilahIn > Izin',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(scanControllerProvider.notifier).initializeCamera();
                  },
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        );
        
      case ScanStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage ?? 'Terjadi kesalahan',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.read(scanControllerProvider.notifier).initializeCamera();
                  },
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        );
        
      case ScanStatus.ready:
      case ScanStatus.takingPicture:
        final cameraService = ref.read(scanCameraServiceProvider);
        return Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 3, // Dummy aspect ratio, FitBox cover will scale it
                height: 4,
                child: cameraService.getPreviewWidget(),
              ),
            ),
            if (state.status == ScanStatus.takingPicture)
              Container(
                color: Colors.white.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        );
    }
  }

  Widget _buildBottomControls(BuildContext context, WidgetRef ref, ScanState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Buka galeri',
            icon: const Icon(Icons.image_outlined, size: 32, color: Colors.grey),
            onPressed: () async {
              final path = await ref.read(scanControllerProvider.notifier).pickFromGallery();
              if (path != null && context.mounted) {
                context.go('/scan/hasil', extra: path);
              }
            },
          ),
          GestureDetector(
            onTap: state.status == ScanStatus.ready
                ? () async {
                    final path = await ref.read(scanControllerProvider.notifier).takePicture();
                    if (path != null && context.mounted) {
                      context.go('/scan/hasil', extra: path);
                    }
                  }
                : null,
            child: Semantics(
              label: 'Ambil foto',
              button: true,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: state.isFlashOn ? 'Matikan flash' : 'Nyalakan flash',
            icon: Icon(
              state.isFlashOn ? Icons.flash_on : Icons.flash_off,
              size: 32,
              color: state.isFlashOn ? Colors.amber : Colors.grey,
            ),
            onPressed: state.status == ScanStatus.ready
                ? () {
                    ref.read(scanControllerProvider.notifier).toggleFlash();
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
