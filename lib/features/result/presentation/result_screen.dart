import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../scan/presentation/classification_controller.dart';
import '../../scan/domain/waste_category.dart';
import '../../scan/domain/classification_result.dart';
import '../../scan/data/scan_image_cropper.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/ml_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../gamification/domain/points_policy.dart';
import '../../gamification/presentation/widgets/streak_reward_dialog.dart';
import '../data/guidance_content.dart';
import '../../history/presentation/history_provider.dart';
import 'widgets/eco_impact_card.dart';

class ResultScreen extends ConsumerStatefulWidget {
  final String? imagePath;

  const ResultScreen({super.key, this.imagePath});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  ScanPointResult? _pointResult;
  int selectedObjectIndex = 0;
  double? _imageAspect; // lebar / tinggi gambar asli

  @override
  void initState() {
    super.initState();
    _loadImageAspect();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.imagePath != null) {
        ref
            .read(classificationControllerProvider.notifier)
            .classify(widget.imagePath!);
      }
    });
  }

  void _loadImageAspect() {
    final path = widget.imagePath;
    if (path == null) return;
    final stream = FileImage(File(path)).resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        stream.removeListener(listener);
        if (mounted && h > 0) setState(() => _imageAspect = w / h);
      },
      onError: (_, _) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ClassificationResult?>>(
      classificationControllerProvider,
      (previous, next) {
        if (next is AsyncData && next.value != null) {
          setState(() => selectedObjectIndex = 0);
          ref
              .read(historyNotifierProvider.notifier)
              .saveScanToHistory(next.value!)
              .then((outcome) async {
                if (!context.mounted) return;
                setState(() => _pointResult = outcome.points);

                // Rayakan streak yang bertambah (termasuk scan pertama).
                if (!AppConstants.gamificationEnabled) return;
                if (!outcome.streak.increased) return;
                await StreakRewardDialog.show(
                  context,
                  streakDays: outcome.streak.current,
                );
              })
              .catchError((e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Riwayat gagal disimpan'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              });

        }
      },
    );

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
        title: const Text(
          'Hasil Pemindaian',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryGreen),
          onPressed: () => context.go('/scan'),
        ),
        actions: [
          IconButton(
            tooltip: 'Riwayat Pemindaian',
            icon: const Icon(Icons.history, color: AppColors.primaryGreen),
            onPressed: () => context.push('/home/riwayat'),
          ),
        ],
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

  Widget _buildPointChip() {
    final pointResult = _pointResult;
    final text = pointResult?.message ?? 'Menghitung poin...';

    return Align(
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
            Flexible(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
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
                    ref
                        .read(classificationControllerProvider.notifier)
                        .classify(widget.imagePath!);
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

  Widget _buildImageFallback() {
    return Container(
      height: 250,
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image, size: 64, color: Colors.grey),
    );
  }

  Widget _buildImageWithBoxes(
    List<ClassificationResult> detections,
    int selectedIndex,
  ) {
    final file = File(widget.imagePath!);
    final aspect =
        (detections.isNotEmpty ? detections.first.imageAspectRatio : null) ??
        _imageAspect;

    Widget decorate(Widget child) => Container(
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
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: child),
    );

    // Ukuran gambar belum diketahui / gagal dibaca: tampilan lama.
    if (aspect == null) {
      return decorate(
        Image.file(
          file,
          height: 250,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildImageFallback(),
        ),
      );
    }

    return decorate(
      LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          // Foto sudah 3:4; batas tinggi mengikuti lebar agar mengisi penuh.
          final maxH = maxW / scanAspectRatio;
          var w = maxW;
          var h = w / aspect;
          if (h > maxH) {
            h = maxH;
            w = h * aspect;
          }
          return Container(
            width: double.infinity,
            color: Colors.black,
            alignment: Alignment.center,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImageFallback(),
                  ),
                  // Kotak terpilih digambar terakhir agar badge-nya di atas.
                  // Jika objek terbaik memiliki confidence < 0.15 (non-sampah),
                  // jangan gambar kotak bounding box di atas foto.
                  if (detections.isNotEmpty &&
                      detections.first.confidence >= 0.20)
                    for (final pass in [false, true])
                      for (var i = 0; i < detections.length; i++)
                        if (detections[i].boundingBox != null &&
                            detections[i].confidence >= 0.20 &&
                            (i == selectedIndex) == pass)
                          _buildBox(detections[i], i, pass, w, h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBox(
    ClassificationResult d,
    int index,
    bool selected,
    double w,
    double h,
  ) {
    final box = d.boundingBox!;
    // Fallback sangat tidak yakin (mis. foto bukan sampah): kotak oranye tipis.
    final weak = d.confidence < 0.25;
    return Positioned(
      left: box.left * w,
      top: box.top * h,
      width: box.width * w,
      height: box.height * h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => selectedObjectIndex = index),
        child: Container(
          decoration: BoxDecoration(
            color: weak
                ? null
                : (selected ? const Color(0xFF39FF14).withAlpha(36) : null),
            border: Border.all(
              color: weak
                  ? Colors.orange.withAlpha(140)
                  : (selected ? const Color(0xFF39FF14) : Colors.yellowAccent),
              width: weak ? 1.2 : (selected ? 3.0 : 2.0),
            ),
          ),
          alignment: Alignment.topLeft,
          child: (selected && !weak)
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  color: const Color(0xFF39FF14),
                  child: Text(
                    '${d.wasteType.displayName} '
                    '${(d.confidence * 100).toStringAsFixed(0)}%',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
  Widget _buildObjectChips(
    List<ClassificationResult> detections,
    int selectedIndex,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < detections.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  detections[i].confidence < 0.20
                      ? 'Objek sampah belum terdeteksi jelas '
                          '(${(detections[i].confidence * 100).toStringAsFixed(1)}%)'
                      : '${i + 1}. ${detections[i].wasteType.displayName} '
                          '(${(detections[i].confidence * 100).toStringAsFixed(1)}%)',
                ),
                selected: i == selectedIndex,
                selectedColor: AppColors.primaryGreen.withAlpha(60),
                onSelected: (_) => setState(() => selectedObjectIndex = i),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, ClassificationResult primary) {
    final theme = Theme.of(context);
    final detections = primary.detections;
    final selectedIndex = selectedObjectIndex.clamp(0, detections.length - 1);
    final result = detections[selectedIndex];
    final isOrganic = result.category == WasteCategory.organik;

    final categoryName = isOrganic ? 'Organik' : 'Anorganik';
    final confPercent = (result.confidence * 100).toStringAsFixed(1);

    // Warna sesuai tema
    final color = isOrganic ? AppColors.organicGreen : AppColors.primaryGreen;
    final progressColor = result.isUncertain ? Colors.grey : color;

    final guidance = GuidanceContent.getGuidance(result.wasteType);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gambar + bounding box objek terdeteksi
          _buildImageWithBoxes(detections, selectedIndex),
          if (detections.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildObjectChips(detections, selectedIndex),
          ],
          const SizedBox(height: 24),
          // Poin Pemindaian (Jika aktif) — poin aktual sesuai aturan
          if (MlConfig.showScanPoints) ...[
            _buildPointChip(),
            const SizedBox(height: 16),
          ],

          // Klasifikasi tingkat 1 (kategori) dan confidence
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kategori',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    categoryName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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
          const SizedBox(height: 12),

          // Sub-kategori (klasifikasi tingkat 2) & Tag B3
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Sub-kategori',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(result.wasteType.icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Text(
                      result.confidence < 0.15
                          ? 'Belum terdeteksi jelas (Mungkin: ${result.wasteType.displayName})'
                          : (result.isUncertain
                              ? 'Mungkin: ${result.wasteType.displayName}'
                              : result.wasteType.displayName),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.isHazardous)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.deepOrange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.deepOrange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Limbah B3 • Berbahaya',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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

          // Kartu Dampak Lingkungan (Eco-Impact)
          EcoImpactCard(wasteType: result.wasteType),
          const SizedBox(height: 24),

          // Panduan Pengelolaan (3 poin ringkasan per jenis sampah)
          Text(
            'Panduan Pengelolaan',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...guidance.summaryPoints.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6.0, right: 12.0),
                    child: CircleAvatar(radius: 4, backgroundColor: color),
                  ),
                  Expanded(child: Text(point)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Tombol Panduan Lengkap
          ElevatedButton(
            onPressed: () {
              context.push('/scan/panduan', extra: result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
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
          const SizedBox(height: 12),

          // Tombol Lihat Riwayat Pemindaian
          OutlinedButton.icon(
            onPressed: () {
              context.push('/home/riwayat');
            },
            icon: const Icon(Icons.history),
            label: const Text(
              'Lihat Riwayat Pemindaian',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
