import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../scan/presentation/classification_controller.dart';
import '../../scan/domain/waste_category.dart';
import '../../scan/domain/classification_result.dart';
import '../../../core/constants/ml_config.dart';
import '../data/guidance_content.dart';
import '../../history/presentation/history_provider.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String? imagePath;

  const ResultScreen({super.key, this.imagePath});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.imagePath != null) {
        ref.read(classificationControllerProvider.notifier).classify(widget.imagePath!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ClassificationResult?>>(classificationControllerProvider, (previous, next) {
      if (next is AsyncData && next.value != null) {
        ref.read(historyNotifierProvider.notifier).saveScanToHistory(next.value!).catchError((e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Riwayat gagal disimpan'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }
    });

    if (widget.imagePath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hasil Pemindaian')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Tidak ada gambar yang dipilih'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/scan'),
                child: const Text('Kembali'),
              ),
            ],
          ),
        ),
      );
    }

    final classificationState = ref.watch(classificationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Pemindaian', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => context.go('/scan'),
        ),
      ),
      body: classificationState.when(
        data: (result) {
          if (result == null) return const SizedBox.shrink();
          return _buildResultView(context, result);
        },
        error: (err, stack) => _buildErrorView(context),
        loading: () => _buildLoadingView(),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Menganalisis sampah...'),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Maaf, terjadi kesalahan saat mengklasifikasi gambar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ref.read(classificationControllerProvider.notifier).classify(widget.imagePath!);
                  },
                  child: const Text('Coba Lagi'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => context.go('/scan'),
                  child: const Text('Pindai Lagi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(BuildContext context, ClassificationResult result) {
    final theme = Theme.of(context);
    final isOrganic = result.category == WasteCategory.organik;
    
    final categoryName = isOrganic ? 'Organik' : 'Anorganik';
    final confPercent = (result.confidence * 100).toStringAsFixed(1);
    
    // Warna sesuai tema
    final color = isOrganic ? Colors.green : Colors.blue;
    final progressColor = result.isUncertain ? Colors.grey : color;

    final guidance = GuidanceContent.getGuidance(result.category);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gambar
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(widget.imagePath!),
                height: 250,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 250,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Poin Pemindaian (Jika aktif)
          if (MlConfig.showScanPoints) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.blue, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '+${MlConfig.scanPointsReward} Poin Pemindaian',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Kategori dan Confidence
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                categoryName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$confPercent%',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar (Animated)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: result.confidence),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  color: progressColor,
                  backgroundColor: Colors.grey[200],
                  minHeight: 8,
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Banner Tidak Yakin
          if (result.isUncertain) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Hasil kurang yakin. Coba pindai ulang dengan pencahayaan lebih terang dan objek lebih dekat.',
                          style: TextStyle(color: Colors.deepOrange),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/scan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
                      ),
                      child: const Text('Pindai Ulang'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (!result.isUncertain) const SizedBox(height: 8),

          // Panduan Pengelolaan
          Text(
            'Panduan Pengelolaan',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...guidance.summaryPoints.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, right: 12.0),
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: color,
                  ),
                ),
                Expanded(
                  child: Text(point),
                ),
              ],
            ),
          )),
          
          const SizedBox(height: 24),

          // Tombol Panduan Lengkap
          ElevatedButton(
            onPressed: () {
              context.push('/scan/panduan', extra: result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text(
              'Panduan Lengkap',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
