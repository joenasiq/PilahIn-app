import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Kartu pemutar video panduan pengolahan sampah.
/// Mendukung poster, kontrol putar/jeda, progress bar,
/// penanganan loading/error, dan pause otomatis saat background/dispose.
class GuidanceVideoCard extends StatefulWidget {
  final String videoPath;
  final String? posterPath;

  const GuidanceVideoCard({
    super.key,
    required this.videoPath,
    this.posterPath,
  });

  @override
  State<GuidanceVideoCard> createState() => _GuidanceVideoCardState();
}

class _GuidanceVideoCardState extends State<GuidanceVideoCard>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Jika tidak ada poster, inisialisasi controller langsung agar menampilkan frame pertama
    if (widget.posterPath == null) {
      _initController(autoPlay: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_controller != null && _controller!.value.isPlaying) {
        _controller!.pause();
      }
    }
  }

  Future<void> _initController({required bool autoPlay}) async {
    if (_controller != null) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final controller = VideoPlayerController.asset(widget.videoPath);
      _controller = controller;
      await controller.initialize();
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      if (autoPlay) {
        await controller.play();
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null) {
      _initController(autoPlay: true);
      return;
    }
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: _isInitialized && _controller != null && _controller!.value.aspectRatio > 0
            ? _controller!.value.aspectRatio
            : 16 / 9,
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.grey.shade900,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 36),
              const SizedBox(height: 8),
              const Text(
                'Gagal memuat video panduan',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  _controller?.dispose();
                  _controller = null;
                  _initController(autoPlay: true);
                },
                icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                label: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Tampilkan poster jika belum diinisialisasi
    if (!_isInitialized && widget.posterPath != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            widget.posterPath!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey.shade900,
              child: const Icon(Icons.video_library, color: Colors.white54, size: 48),
            ),
          ),
          Container(color: Colors.black38),
          Center(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _initController(autoPlay: true),
                borderRadius: BorderRadius.circular(32),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(220),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(60),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 14,
            child: Row(
              children: const [
                Icon(Icons.play_circle_outline, color: Colors.white70, size: 16),
                SizedBox(width: 6),
                Text(
                  'Putar Video Panduan',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_isInitialized && _controller != null) {
      final isPlaying = _controller!.value.isPlaying;

      return GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_controller!),
            // Kontrol Overlay
            if (_showControls || !isPlaying)
              AnimatedOpacity(
                opacity: _showControls || !isPlaying ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Colors.black45,
                  child: Stack(
                    children: [
                      // Tombol Tengah Play / Pause
                      Center(
                        child: IconButton(
                          iconSize: 52,
                          icon: Icon(
                            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                            color: Colors.white,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                      ),
                      // Bar Bawah
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black87, Colors.transparent],
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              VideoProgressIndicator(
                                _controller!,
                                allowScrubbing: true,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                colors: const VideoProgressColors(
                                  playedColor: Colors.blue,
                                  bufferedColor: Colors.white38,
                                  backgroundColor: Colors.white24,
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(_controller!.value.position),
                                    style: const TextStyle(color: Colors.white, fontSize: 11),
                                  ),
                                  Text(
                                    _formatDuration(_controller!.value.duration),
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.grey.shade900,
      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
