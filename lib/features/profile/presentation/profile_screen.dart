import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/waste/waste_types.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../gamification/domain/reference_data.dart';
import '../../gamification/domain/user_progress.dart';
import '../../gamification/presentation/user_progress_provider.dart';
import '../../gamification/presentation/widgets/points_info_sheet.dart';
import '../../home/presentation/home_provider.dart';
import '../../history/domain/history_stats.dart';
import '../../history/presentation/history_provider.dart';
import '../../scan/domain/waste_category.dart';
import '../data/avatar_cropper.dart';
import '../data/avatar_service.dart';
import 'avatar_crop_screen.dart';
import 'avatar_photo_viewer.dart';

class DonutData {
  final int organic;
  final int anorganic;

  DonutData({required this.organic, required this.anorganic});

  int get total => organic + anorganic;
  double get organicRatio => total == 0 ? 0 : organic / total;
  double get anorganicRatio => total == 0 ? 0 : anorganic / total;
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isUploadingPhoto = false;

  /// Progress unggah 0..1, null bila tidak sedang mengunggah.
  double? _uploadProgress;

  /// Byte foto hasil crop yang belum berhasil diunggah, dipakai untuk
  /// "Coba lagi" tanpa perlu memilih & memotong foto ulang.
  Uint8List? _pendingAvatarBytes;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final user = authState.value;
    final homeState = ref.watch(homeSummaryProvider);
    final statsAsync = ref.watch(historyStatsProvider);
    final progressAsync = ref.watch(userProgressProvider);
    final isGuest = user?.isGuest ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F5),
      appBar: AppBar(
        title: const Text(
          'Profil',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF064E3B),
        elevation: 0,
        foregroundColor: Colors.white,
        leading: (ModalRoute.of(context)?.canPop == true)
            ? IconButton(
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    try {
                      context.go('/home');
                    } catch (_) {}
                  }
                },
              )
            : null,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(theme, user, homeState.value),
            const SizedBox(height: 22),

            if (AppConstants.gamificationEnabled &&
                homeState.value != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('PENCAPAIANMU'),
                    const SizedBox(height: 9),
                    _buildStatsRow(homeState.value!, progressAsync),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('AKTIVITAS PEMILAHAN'),
                  const SizedBox(height: 9),
                  _buildDonutCard(theme, statsAsync),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('LAINNYA'),
                  const SizedBox(height: 9),
                  _buildMenu(isGuest),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: const Color(0xFF047857).withValues(alpha: 0.8),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppUser? user, dynamic summary) {
    final name = user?.displayName ?? 'Tamu';
    final email = user?.email ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isGuest = user?.isGuest ?? true;
    final level = (summary?.level as int?) ?? 1;
    final isAvatarUnlocked = level >= AppConstants.avatarUnlockLevel;

    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF064E3B), Color(0xFF022C22)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF064E3B),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Lingkaran dekoratif latar belakang
          Positioned(
            right: -25,
            top: -15,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              children: [
                // Avatar Modern (bisa diketuk untuk ganti foto bila login
                // dan sudah mencapai level minimum)
                _buildAvatar(
                  user,
                  isGuest: isGuest,
                  initial: initial,
                  isUnlocked: isAvatarUnlocked,
                  level: level,
                  points: (summary?.points as int?) ?? 0,
                ),
                const SizedBox(height: 12),

                // Nama Pengguna
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 5),
                Text(
                  isGuest
                      ? 'Simpan aktivitasmu dengan masuk ke akun'
                      : 'Terima kasih sudah memilah hari ini',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),

                if (email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],

                // Badge Level
                if (AppConstants.gamificationEnabled && summary != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          size: 14,
                          color: Color(0xFFFBBF24),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Level ${summary.level}: ${summary.levelName}',
                          style: const TextStyle(
                            color: Color(0xFFECFDF5),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(AppUser? user, {
    required bool isGuest,
    required String initial,
    required bool isUnlocked,
    required int level,
    required int points,
  }) {
    final photoUrl = user?.photoUrl?.trim();
    final hasPhoto = !isGuest && photoUrl != null && photoUrl.isNotEmpty;

    return GestureDetector(
      onTap: () => _onAvatarTap(
        isGuest: isGuest,
        isUnlocked: isUnlocked,
        level: level,
        points: points,
        hasPhoto: hasPhoto,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFF34D399)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 38,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: _isUploadingPhoto
                      ? Center(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  // Tahap kompresi tidak punya progres nyata,
                                  // jadi tampilkan spinner berputar dulu.
                                  value: (_uploadProgress ?? 0) > 0
                                      ? _uploadProgress
                                      : null,
                                  strokeWidth: 2.4,
                                  color: const Color(0xFF059669),
                                  backgroundColor: const Color(0xFFD1FAE5),
                                ),
                                if ((_uploadProgress ?? 0) > 0)
                                  Text(
                                    '${((_uploadProgress ?? 0) * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : hasPhoto
                      ? _buildAvatarImage(
                          user: user,
                          photoUrl: photoUrl,
                          isGuest: isGuest,
                          initial: initial,
                        )
                      : _buildAvatarPlaceholder(isGuest, initial),
                ),
              ),
            ),
          ),
          if (!isGuest)
            Positioned(
              right: -10,
              bottom: -10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onAvatarEditTap(
                  isUnlocked: isUnlocked,
                  level: level,
                  points: points,
                ),
                child: Padding(
                  // Padding memperbesar area sentuh badge kamera tanpa
                  // mengubah posisi visualnya.
                  padding: const EdgeInsets.all(8),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? const Color(0xFF059669)
                          : const Color(0xFF64748B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      isUnlocked
                          ? Icons.photo_camera_rounded
                          : Icons.lock_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Menampilkan foto profil dari Firestore (base64).
  ///
  /// Nilai `photoUrl` lama yang masih berupa URL http tetap didukung agar
  /// akun yang sempat memakai Firebase Storage tidak kehilangan fotonya.
  Widget _buildAvatarImage({
    required AppUser? user,
    required String photoUrl,
    required bool isGuest,
    required String initial,
  }) {
    if (photoUrl.startsWith('http')) {
      return Hero(
        tag: 'profile-avatar-photo',
        child: Image.network(
          photoUrl,
          key: const ValueKey('profile-avatar-photo'),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildAvatarPlaceholder(isGuest, initial),
        ),
      );
    }

    final userId = user?.id ?? '';
    final bytesAsync = ref.watch(
      avatarBytesProvider((userId: userId, marker: photoUrl)),
    );

    return bytesAsync.when(
      data: (bytes) {
        if (bytes == null || bytes.isEmpty) {
          return _buildAvatarPlaceholder(isGuest, initial);
        }
        return Hero(
          tag: 'profile-avatar-photo',
          child: Image.memory(
            bytes,
            key: const ValueKey('profile-avatar-photo'),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) =>
                _buildAvatarPlaceholder(isGuest, initial),
          ),
        );
      },
      loading: () => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Color(0xFF059669),
          ),
        ),
      ),
      error: (_, _) => _buildAvatarPlaceholder(isGuest, initial),
    );
  }

  Widget _buildAvatarPlaceholder(bool isGuest, String initial) {
    if (isGuest) {
      return const Icon(Icons.person, size: 40, color: Color(0xFF059669));
    }
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: Color(0xFF065F46),
        ),
      ),
    );
  }

  void _onAvatarTap({
    required bool isGuest,
    required bool isUnlocked,
    required int level,
    required int points,
    required bool hasPhoto,
  }) {
    if (isGuest) {
      _showSnack('Masuk ke akun untuk menambahkan foto profil');
      return;
    }
    if (_isUploadingPhoto) return;
    if (!isUnlocked) {
      _showAvatarLockedDialog(level: level, points: points);
      return;
    }
    // Sudah punya foto: ketukan pada avatar membuka tampilan besar.
    if (hasPhoto) {
      _openPhotoViewer();
      return;
    }
    _showAvatarOptionsSheet();
  }

  /// Ketukan pada badge kamera/lock di pojok avatar: langsung ke menu foto.
  void _onAvatarEditTap({
    required bool isUnlocked,
    required int level,
    required int points,
  }) {
    if (_isUploadingPhoto) return;
    if (!isUnlocked) {
      _showAvatarLockedDialog(level: level, points: points);
      return;
    }
    _showAvatarOptionsSheet();
  }

  /// Membuka foto profil ukuran penuh.
  Future<void> _openPhotoViewer() async {
    final user = ref.read(authControllerProvider).value;
    final marker = user?.photoUrl?.trim() ?? '';
    if (user == null || marker.isEmpty) return;

    final isNetwork = marker.startsWith('http');
    final bytes = isNetwork
        ? null
        : ref
            .read(avatarBytesProvider((userId: user.id, marker: marker)))
            .value;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AvatarPhotoViewer(
          title: user.displayName,
          bytes: bytes,
          networkUrl: isNetwork ? marker : null,
          onEdit: _showAvatarOptionsSheet,
        ),
      ),
    );
  }

  /// Ambang poin level minimum untuk membuka foto profil.
  LevelInfo get _avatarUnlockLevelInfo => kLevels.firstWhere(
    (lvl) => lvl.level == AppConstants.avatarUnlockLevel,
    orElse: () => kLevels.last,
  );

  void _showAvatarLockedDialog({required int level, required int points}) {
    final target = _avatarUnlockLevelInfo;
    final remaining = target.minPoints - points;
    final progress = (points / target.minPoints).clamp(0.0, 1.0);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFF64748B)),
            SizedBox(width: 8),
            Text(
              'Foto Profil Terkunci',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kumpulkan ${target.minPoints} poin untuk mencapai '
              'Level ${target.level} (${target.name}) dan membuka foto profil.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF059669)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$points / ${target.minPoints} poin'
              '${remaining > 0 ? ' • kurang $remaining poin' : ''}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Level kamu sekarang: Level $level',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Mengerti',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              try {
                context.push('/profile/misi');
              } catch (_) {}
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Lihat Misi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarOptionsSheet() {
    final user = ref.read(authControllerProvider).value;
    final hasPhoto = (user?.photoUrl ?? '').isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Foto Profil',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: Color(0xFF059669)),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_camera_rounded, color: Color(0xFF059669)),
              title: const Text('Ambil dari Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.camera);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626)),
                title: const Text(
                  'Hapus Foto',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAvatar();
                },
              ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    XFile? picked;
    try {
      picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 95,
      );
    } catch (_) {
      _showSnack('Tidak dapat membuka kamera/galeri');
      return;
    }
    if (picked == null) return;

    // Siapkan gambar (decode + orientasi + perkecil) sebelum layar crop.
    setState(() {
      _isUploadingPhoto = true;
      _uploadProgress = 0;
    });

    AvatarCropSource cropSource;
    try {
      cropSource = await prepareAvatarCropSource(picked.path);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          _uploadProgress = null;
        });
      }
      _showSnack('Foto tidak dapat dibaca. Coba foto lain.', isError: true);
      return;
    }

    if (!mounted) return;
    setState(() {
      _isUploadingPhoto = false;
      _uploadProgress = null;
    });

    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        builder: (_) => AvatarCropScreen(source: cropSource),
      ),
    );
    if (cropped == null || cropped.isEmpty) return;
    await _uploadAvatarBytes(cropped);
  }

  Future<void> _uploadAvatarBytes(Uint8List bytes) async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;
    if (_isUploadingPhoto) return;

    setState(() {
      _isUploadingPhoto = true;
      _uploadProgress = 0;
      _pendingAvatarBytes = bytes;
    });

    String? uploadedUrl;
    try {
      uploadedUrl = await ref
          .read(avatarServiceProvider)
          .uploadBytes(
            userId: user.id,
            bytes: bytes,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() => _uploadProgress = progress);
            },
          );

      // Foto sudah tersimpan di Firestore; tahap ini hanya mencatat penanda
      // versi ke dokumen profil.
      try {
        await ref
            .read(authControllerProvider.notifier)
            .updatePhotoUrl(uploadedUrl);
      } catch (e) {
        _showUploadError(
          'Foto sudah tersimpan, tetapi gagal dicatat ke profil. Coba lagi.',
          retryable: true,
        );
        return;
      }

      if (mounted) setState(() => _pendingAvatarBytes = null);
      _showSnack('Foto profil diperbarui');
    } on AvatarUploadException catch (e) {
      _showUploadError(e.message, retryable: e.retryable);
    } catch (e) {
      _showUploadError(
        e.toString().replaceFirst('Exception: ', ''),
        retryable: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
          _uploadProgress = null;
        });
      }
    }
  }

  /// Menampilkan error unggah dengan aksi "Coba lagi" bila memungkinkan.
  void _showUploadError(String message, {bool retryable = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final pending = _pendingAvatarBytes;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 8),
        action: retryable && pending != null
            ? SnackBarAction(
                label: 'Coba lagi',
                textColor: Colors.white,
                onPressed: () => _uploadAvatarBytes(pending),
              )
            : null,
      ),
    );
  }

  Future<void> _removeAvatar() async {
    final user = ref.read(authControllerProvider).value;
    if (user == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      await ref.read(avatarServiceProvider).delete(user.id);
      await ref.read(authControllerProvider.notifier).updatePhotoUrl(null);
      _showSnack('Foto profil dihapus');
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? const Color(0xFFDC2626) : null,
      ),
    );
  }

  Widget _buildStatsRow(
    dynamic summary,
    AsyncValue<UserProgress> progressAsync,
  ) {
    // Total poin dinamis: dasar (demo/tamu) + scan + hadiah login.
    final progress = progressAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final totalPoints = progress?.totalPoints ?? (summary.points as int);
    final scanPoints = progress?.scanPoints ?? 0;
    final loginPoints = progress?.loginPoints ?? 0;
    final pointsToday = progress?.pointsToday ?? 0;
    final dailyLimit = progress?.dailyLimit ?? 150;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCEBE4), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.stars_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  iconBgColor: const Color(0xFFFEF3C7),
                  label: 'Poin',
                  value: totalPoints.toString(),
                ),
              ),
              Container(height: 36, width: 1, color: Colors.grey.shade200),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFEA580C),
                  iconBgColor: const Color(0xFFFFEDD5),
                  label: 'Hari Beruntun',
                  value: summary.streakDays.toString(),
                ),
              ),
              Container(height: 36, width: 1, color: Colors.grey.shade200),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: const Color(0xFF059669),
                  iconBgColor: const Color(0xFFD1FAE5),
                  label: 'Badge',
                  value: summary.unlockedBadges.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                'Scan $scanPoints • Login $loginPoints • Hari ini $pointsToday/$dailyLimit',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              GestureDetector(
                onTap: () => PointsInfoSheet.show(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Color(0xFF059669),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Cara Mendapatkan Poin',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: iconBgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDonutCard(ThemeData theme, AsyncValue<HistoryStats> statsAsync) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCEBE4), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  size: 18,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Statistik Pemilahan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Perbandingan sampah terdeteksi',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          statsAsync.when(
            data: (stats) {
              final org = stats.organicCount;
              final anorg = stats.anorganicCount;
              final data = DonutData(organic: org, anorganic: anorg);

              if (data.total == 0) {
                return _buildEmptyDonut();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Kategori Utama',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Total ${data.total} pemindaian',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      // Donut Chart dengan Total di Tengah
                      SizedBox(
                        width: 120,
                        height: 120,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _animation,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: const Size(120, 120),
                                  painter: DonutPainter(
                                    organicRatio: data.organicRatio,
                                    anorganicRatio: data.anorganicRatio,
                                    animationValue: _animation.value,
                                  ),
                                );
                              },
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${data.total}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Total Item',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 18),

                      // Keterangan Legend yang Rapi
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(
                              'Organik',
                              org,
                              data.organicRatio,
                              const Color(0xFF10B981),
                              const Color(0xFFECFDF5),
                            ),
                            const SizedBox(height: 10),
                            _buildLegendItem(
                              'Anorganik',
                              anorg,
                              data.anorganicRatio,
                              const Color(0xFF0284C7),
                              const Color(0xFFF0F9FF),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Rincian Sub-kategori',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (stats.typedTotal > 0)
                        Text(
                          '${stats.typedTotal} terklasifikasi',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (stats.sortedWasteTypes.isEmpty)
                    Text(
                      'Rincian sub-kategori belum tersedia',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade500,
                      ),
                    )
                  else
                    ...stats.sortedWasteTypes.map(
                      (entry) => _buildWasteTypeStatItem(
                        entry.key,
                        entry.value,
                        stats.typedTotal,
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, st) => Column(
              children: [
                const Text('Gagal memuat statistik'),
                TextButton(
                  onPressed: () => ref.refresh(historyStatsProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Satu baris rincian klasifikasi tingkat kedua (jenis sampah).
  Widget _buildWasteTypeStatItem(WasteType wasteType, int count, int total) {
    final isOrganic = wasteType.category == WasteCategory.organik;
    final color = isOrganic ? const Color(0xFF10B981) : const Color(0xFF0284C7);
    final ratio = total == 0 ? 0.0 : count / total;
    final pct = (ratio * 100).toStringAsFixed(1);
    final categoryLabel = isOrganic
        ? 'Organik'
        : (wasteType.isHazardous ? 'Anorganik • B3' : 'Anorganik');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(wasteType.icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        wasteType.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$categoryLabel • $count item',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 5,
                    color: color,
                    backgroundColor: color.withAlpha(30),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDonut() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CustomPaint(
              painter: DonutPainter(
                organicRatio: 0,
                anorganicRatio: 0,
                animationValue: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Belum ada data',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mulai pindai sampah untuk melihat statistik pemilahanmu.',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
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

  Widget _buildLegendItem(
    String label,
    int count,
    double ratio,
    Color color,
    Color bgColor,
  ) {
    final pct = (ratio * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  '$count item',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$pct%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenu(bool isGuest) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCEBE4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            if (AppConstants.gamificationEnabled) ...[
              _buildMenuItem(
                icon: Icons.emoji_events_rounded,
                iconColor: const Color(0xFFF59E0B),
                iconBgColor: const Color(0xFFFEF3C7),
                label: 'Misi & Lencana',
                subtitle: 'Misi harian & koleksi lencana',
                onTap: () {
                  try {
                    context.push('/profile/misi');
                  } catch (_) {}
                },
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade100,
                indent: 64,
              ),
            ],
            _buildMenuItem(
              icon: Icons.history_rounded,
              iconColor: const Color(0xFF0284C7),
              iconBgColor: const Color(0xFFE0F2FE),
              label: 'Riwayat Pemindaian',
              subtitle: 'Daftar riwayat sampah yang dipilah',
              onTap: () {
                try {
                  context.push('/home/riwayat');
                } catch (_) {}
              },
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade100,
              indent: 64,
            ),
            _buildMenuItem(
              icon: Icons.info_outline_rounded,
              iconColor: const Color(0xFF059669),
              iconBgColor: const Color(0xFFD1FAE5),
              label: 'Tentang Aplikasi',
              subtitle: 'Informasi versi & pengembang PBL',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.eco, color: Color(0xFF059669)),
                        SizedBox(width: 8),
                        Text(
                          'Tentang PilahIn',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aplikasi klasifikasi sampah Organik dan Anorganik berbasis AI.',
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Proyek PBL Politeknik Negeri Malang',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Versi 1.0.0',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade100,
              indent: 64,
            ),
            _buildMenuItem(
              icon: Icons.logout_rounded,
              iconColor: const Color(0xFFEF4444),
              iconBgColor: const Color(0xFFFEE2E2),
              label: 'Keluar',
              subtitle: 'Keluar dari sesi akun saat ini',
              textColor: const Color(0xFFDC2626),
              showArrow: false,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    title: const Text(
                      'Keluar dari akun?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    content: Text(
                      isGuest
                          ? 'Anda akan kembali ke halaman masuk.'
                          : 'Anda harus masuk kembali untuk melanjutkan misi dan melihat profil Anda.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(authControllerProvider.notifier).logout();
                          try {
                            context.go('/login');
                          } catch (_) {}
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Keluar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
    Color? textColor,
    bool showArrow = true,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: textColor ?? const Color(0xFF0F172A),
          fontSize: 14.5,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
            )
          : null,
      trailing: showArrow
          ? Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 22,
            )
          : null,
      onTap: onTap,
    );
  }
}

class DonutPainter extends CustomPainter {
  final double organicRatio;
  final double anorganicRatio;
  final double animationValue;

  DonutPainter({
    required this.organicRatio,
    required this.anorganicRatio,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2);
    final strokeWidth = radius * 0.32;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (organicRatio == 0 && anorganicRatio == 0) {
      paint.color = Colors.grey.shade200;
      paint.strokeCap = StrokeCap.butt;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    // Background track ring
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFF1F5F9);
    canvas.drawCircle(center, radius - strokeWidth / 2, trackPaint);

    // organic (Vibrant Emerald)
    if (organicRatio > 0) {
      final orgSweep = 2 * pi * organicRatio * animationValue;
      paint.color = const Color(0xFF10B981);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        -pi / 2,
        orgSweep,
        false,
        paint,
      );
    }

    // anorganic (Sky Blue / Teal)
    if (anorganicRatio > 0) {
      final anorgSweep = 2 * pi * anorganicRatio * animationValue;
      paint.color = const Color(0xFF0284C7);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        -pi / 2 + (2 * pi * organicRatio),
        anorgSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) {
    return oldDelegate.organicRatio != organicRatio ||
        oldDelegate.anorganicRatio != anorganicRatio ||
        oldDelegate.animationValue != animationValue;
  }
}
