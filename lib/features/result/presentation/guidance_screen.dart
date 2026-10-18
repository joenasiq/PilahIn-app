import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/ml_config.dart';
import '../../scan/domain/classification_result.dart';
import '../../scan/domain/waste_category.dart';
import '../data/guidance_content.dart';
import '../data/guidance_media.dart';
import 'widgets/guidance_video_card.dart';

/// Layar Panduan Pengolahan Sampah per jenis sampah.
class GuidanceScreen extends ConsumerWidget {
  final ClassificationResult? result;

  const GuidanceScreen({super.key, this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panduan Pengelolaan')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Data hasil tidak ditemukan'),
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

    final wasteType = result!.wasteType;
    final guidance = GuidanceContent.getGuidance(wasteType);
    final binInfo = getWasteBinInfo(wasteType);
    final isOrganic = result!.category == WasteCategory.organik;
    final primaryColor = isOrganic ? Colors.green : Colors.blue;
    final iconData = isOrganic ? Icons.eco : Icons.recycling;

    final mediaAsync = ref.watch(guidanceMediaProvider(wasteType));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panduan Pengelolaan', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Gambar Hasil Pindai
            _buildHeaderImage(result!.imagePath),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Baris Chips (Kategori + Jenis + B3 jika ada + Poin jika aktif)
                  _buildChipsRow(
                    isOrganic: isOrganic,
                    primaryColor: primaryColor,
                    categoryIcon: iconData,
                    isHazardous: result!.isHazardous,
                  ),
                  const SizedBox(height: 16),

                  // 3. Judul (Nama Jenis)
                  Text(
                    wasteType.displayName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),

                  // 4. Deskripsi
                  Text(
                    guidance.description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Kartu Tempat Sampah
                  _buildWasteBinCard(binInfo),
                  const SizedBox(height: 20),

                  // 6. Banner Peringatan B3 (jika jenis limbah berbahaya)
                  if (result!.isHazardous) ...[
                    _buildHazardousBanner(),
                    const SizedBox(height: 20),
                  ],

                  // 7. Bagian "Cara Pengolahan"
                  Text(
                    'Cara Pengolahan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Media & Langkah-langkah
                  mediaAsync.when(
                    data: (media) => _buildGuidanceStepsWithMedia(context, guidance, media),
                    loading: () => _buildGuidanceStepsWithMedia(
                      context,
                      guidance,
                      const GuidanceMedia(),
                      isLoadingMedia: true,
                    ),
                    error: (error, stackTrace) => _buildGuidanceStepsWithMedia(
                      context,
                      guidance,
                      const GuidanceMedia(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 8. Dua Kartu "Boleh dilakukan" dan "Hindari" berdampingan tanpa overflow
                  _buildDoAndDontCards(context, guidance),

                  // 9. Bagian "Ide Pemanfaatan Kembali" (jika ada)
                  if (guidance.reuseIdeas.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildReuseIdeasSection(context, guidance.reuseIdeas),
                  ],

                  const SizedBox(height: 24),

                  // 10. Tombol Lihat Riwayat Pemindaian
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.push('/home/riwayat');
                      },
                      icon: const Icon(Icons.history),
                      label: const Text(
                        'Lihat Riwayat Pemindaian',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gambar Header Hasil Pindai
  Widget _buildHeaderImage(String imagePath) {
    return Image.file(
      File(imagePath),
      height: 250,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        height: 250,
        color: Colors.grey[300],
        child: const Icon(Icons.broken_image, size: 64, color: Colors.grey),
      ),
    );
  }

  /// Baris Chips
  Widget _buildChipsRow({
    required bool isOrganic,
    required Color primaryColor,
    required IconData categoryIcon,
    required bool isHazardous,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Chip Kategori
        Chip(
          avatar: Icon(categoryIcon, color: primaryColor, size: 18),
          label: Text(
            isOrganic ? 'Organik' : 'Anorganik',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: primaryColor.withAlpha(25),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
        // Chip Jenis
        Chip(
          avatar: Icon(result!.wasteType.icon, color: primaryColor, size: 18),
          label: Text(
            result!.wasteType.displayName,
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: primaryColor.withAlpha(25),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
        // Chip B3 jika berbahaya
        if (isHazardous)
          Chip(
            avatar: Icon(Icons.warning_amber_rounded, color: Colors.deepOrange.shade700, size: 18),
            label: Text(
              'Limbah B3 • Berbahaya',
              style: TextStyle(color: Colors.deepOrange.shade800, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.deepOrange.shade50,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
        // Chip Poin Pemindaian
        if (MlConfig.showScanPoints)
          Chip(
            avatar: const Icon(Icons.auto_awesome, color: Colors.blue, size: 18),
            label: Text(
              '+${MlConfig.scanPointsReward} Poin Pemindaian',
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.blue.withAlpha(25),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
      ],
    );
  }

  /// Kartu "Buang ke: tempat sampah {warna}"
  Widget _buildWasteBinCard(WasteBinInfo binInfo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: binInfo.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: binInfo.borderColor),
      ),
      child: Row(
        children: [
          Icon(binInfo.icon, color: binInfo.color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              binInfo.actionText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: binInfo.color,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Banner Peringatan Limbah B3
  Widget _buildHazardousBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.deepOrange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Perhatian: Limbah Berbahaya (B3)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Jangan dibakar, dibongkar, atau ditekan. Simpan di wadah kering non-logam dan serahkan ke titik pengumpulan resmi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepOrange.shade800,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Langkah-langkah Pengolahan Lengkap dengan Slot Media
  Widget _buildGuidanceStepsWithMedia(
    BuildContext context,
    WasteGuidance guidance,
    GuidanceMedia media, {
    bool isLoadingMedia = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Kartu Video Panduan di bagian atas
        if (media.hasVideo)
          GuidanceVideoCard(
            videoPath: media.videoPath!,
            posterPath: media.posterPath,
          )
        else if (AppConstants.showMediaPlaceholders)
          _buildVideoPlaceholder()
        else
          const SizedBox.shrink(),

        // Langkah-langkah bernomor
        ...List.generate(guidance.steps.length, (index) {
          final stepNumber = index + 1;
          final step = guidance.steps[index];
          final stepImagePath = media.getStepImage(stepNumber);

          return Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lingkaran angka biru
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(25),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$stepNumber',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Foto Langkah N atau Placeholder
                Padding(
                  padding: const EdgeInsets.only(left: 40.0, top: 10.0),
                  child: stepImagePath != null
                      ? _buildStepImageThumbnail(context, stepImagePath, step.title)
                      : (AppConstants.showMediaPlaceholders
                          ? _buildStepImagePlaceholder()
                          : const SizedBox.shrink()),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Placeholder halus untuk video saat media belum tersedia
  Widget _buildVideoPlaceholder() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.videocam_outlined, size: 22, color: Colors.grey.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Video panduan belum tersedia',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder halus untuk foto langkah saat media belum tersedia
  Widget _buildStepImagePlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_outlined, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 8),
          Text(
            'Foto langkah belum tersedia',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// Thumbnail foto langkah dengan interaksi zoom fullscreen
  Widget _buildStepImageThumbnail(BuildContext context, String imagePath, String title) {
    return GestureDetector(
      onTap: () => _showFullscreenImageViewer(context, imagePath, title),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Image.asset(
              imagePath,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                color: Colors.grey.shade200,
                child: const Center(
                  child: Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Ketuk untuk perbesar',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tampilan Layar Penuh dengan InteractiveViewer
  void _showFullscreenImageViewer(BuildContext context, String imagePath, String title) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.asset(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Kartu "Boleh dilakukan" dan "Hindari" berdampingan tanpa overflow di layar sempit
  Widget _buildDoAndDontCards(BuildContext context, WasteGuidance guidance) {
    final doCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Boleh dilakukan',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...guidance.doList.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: CircleAvatar(radius: 3, backgroundColor: Colors.green.shade400),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(fontSize: 13, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );

    final dontCard = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hindari',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...guidance.dontList.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: CircleAvatar(radius: 3, backgroundColor: Colors.red.shade400),
                    ),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              doCard,
              const SizedBox(height: 12),
              dontCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: doCard),
            const SizedBox(width: 12),
            Expanded(child: dontCard),
          ],
        );
      },
    );
  }

  /// Bagian "Ide Pemanfaatan Kembali"
  Widget _buildReuseIdeasSection(BuildContext context, List<String> reuseIdeas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 22),
            const SizedBox(width: 8),
            Text(
              'Ide Pemanfaatan Kembali',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...reuseIdeas.map((idea) => Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: Icon(Icons.eco, size: 16, color: Colors.amber.shade800),
                  ),
                  Expanded(
                    child: Text(
                      idea,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.brown.shade800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
