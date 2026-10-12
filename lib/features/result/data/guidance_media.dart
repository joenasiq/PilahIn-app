import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/waste/waste_types.dart';

/// Model untuk media panduan pengolahan sampah (video & foto langkah).
class GuidanceMedia {
  final String? videoPath;
  final String? posterPath;
  final Map<int, String> stepImages;

  const GuidanceMedia({
    this.videoPath,
    this.posterPath,
    this.stepImages = const {},
  });

  bool get hasVideo => videoPath != null;
  bool get hasPoster => posterPath != null;
  bool hasStepImage(int stepNumber) => stepImages.containsKey(stepNumber);
  String? getStepImage(int stepNumber) => stepImages[stepNumber];
}

/// Kontrak untuk mendeteksi media panduan per jenis sampah.
abstract class GuidanceMediaResolver {
  Future<GuidanceMedia> resolve(WasteType type);
}

/// Implementasi resolver menggunakan asset bundle Flutter.
class FlutterAssetGuidanceMediaResolver implements GuidanceMediaResolver {
  final AssetBundle _bundle;
  final Map<WasteType, GuidanceMedia> _cache = {};

  FlutterAssetGuidanceMediaResolver({AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  @override
  Future<GuidanceMedia> resolve(WasteType type) async {
    if (_cache.containsKey(type)) {
      return _cache[type]!;
    }

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
      final allAssets = manifest.listAssets();
      final media = parseAssetsForType(type, allAssets);
      _cache[type] = media;
      return media;
    } catch (_) {
      const fallback = GuidanceMedia();
      _cache[type] = fallback;
      return fallback;
    }
  }

  /// Mem-parse daftar aset untuk menemukan media yang cocok dengan [WasteType].
  static GuidanceMedia parseAssetsForType(WasteType type, List<String> allAssets) {
    final prefix = 'assets/guidance/${type.labelKey}/';
    String? videoPath;
    String? posterPath;
    final stepImages = <int, String>{};

    final stepRegex = RegExp(r'^step_(\d+)\.(jpg|jpeg|png|webp)$', caseSensitive: false);
    final posterRegex = RegExp(r'^poster\.(jpg|jpeg|png|webp)$', caseSensitive: false);
    final videoRegex = RegExp(r'^video\.mp4$', caseSensitive: false);

    for (final asset in allAssets) {
      if (!asset.toLowerCase().startsWith(prefix.toLowerCase())) continue;
      final filename = asset.substring(prefix.length);

      if (videoRegex.hasMatch(filename)) {
        videoPath = asset;
      } else if (posterRegex.hasMatch(filename)) {
        posterPath = asset;
      } else {
        final match = stepRegex.firstMatch(filename);
        if (match != null) {
          final stepNum = int.tryParse(match.group(1)!);
          if (stepNum != null) {
            stepImages[stepNum] = asset;
          }
        }
      }
    }

    return GuidanceMedia(
      videoPath: videoPath,
      posterPath: posterPath,
      stepImages: stepImages,
    );
  }
}

/// Resolver tiruan untuk keperluan pengujian (testing).
class FakeGuidanceMediaResolver implements GuidanceMediaResolver {
  final Map<WasteType, GuidanceMedia> data;

  FakeGuidanceMediaResolver([this.data = const {}]);

  @override
  Future<GuidanceMedia> resolve(WasteType type) async {
    return data[type] ?? const GuidanceMedia();
  }
}

/// Provider untuk instance resolver media.
final guidanceMediaResolverProvider = Provider<GuidanceMediaResolver>((ref) {
  return FlutterAssetGuidanceMediaResolver();
});

/// Provider yang mengembalikan media panduan per [WasteType] dengan caching.
final guidanceMediaProvider = FutureProvider.family<GuidanceMedia, WasteType>((ref, type) async {
  final resolver = ref.watch(guidanceMediaResolverProvider);
  return resolver.resolve(type);
});
