import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/banner.dart';
import '../../../common/widgets/loaders/shimmer_box.dart';
import '../../../common/widgets/misc/app_network_image.dart';
import 'delivery_header.dart';

/// Header component where backend-provided video/media occupies the entire
/// header container background, with location, actions, search bar, and 10 Min badge
/// layered seamlessly on top of the video in a Stack.
class FullBackgroundVideoHeader extends StatefulWidget {
  const FullBackgroundVideoHeader({
    super.key,
    required this.banners,
    this.isLoading = false,
    this.onBannerTap,
    this.searchBar,
    this.deliveryBadge,
  });

  final List<PromoBanner> banners;
  final bool isLoading;
  final ValueChanged<PromoBanner>? onBannerTap;
  final Widget? searchBar;
  final Widget? deliveryBadge;

  @override
  State<FullBackgroundVideoHeader> createState() =>
      _FullBackgroundVideoHeaderState();
}

class _FullBackgroundVideoHeaderState
    extends State<FullBackgroundVideoHeader> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(FullBackgroundVideoHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.banners.length < 2) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextIndex = (_currentIndex + 1) % widget.banners.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasBanners = widget.banners.isNotEmpty;

    return Container(
      height: 345.0,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── Layer 1: Full-Bleed Video / Image Background ──────────────────
          Positioned.fill(
            child: widget.isLoading
                ? const ShimmerBox(
                    height: double.infinity,
                    radius: BorderRadius.zero,
                  )
                : hasBanners
                    ? PageView.builder(
                        controller: _pageController,
                        itemCount: widget.banners.length,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          final banner = widget.banners[index];
                          return GestureDetector(
                            onTap: () => widget.onBannerTap?.call(banner),
                            child: banner.isVideo
                                ? _FullBackgroundVideoPlayer(banner: banner)
                                : _FullBackgroundImage(banner: banner),
                          );
                        },
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [context.colors.primary, context.semantic.accent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
          ),

          // ── Layer 2: Subtle Contrast Gradient Overlay for Text Readability 
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: hasBanners ? 0.50 : 0.15),
                      Colors.transparent,
                      Colors.black.withValues(alpha: hasBanners ? 0.45 : 0.15),
                    ],
                    stops: const [0.0, 0.40, 1.0],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 3: Overlaid Header UI Elements ──────────────────────────
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // 1. Top Location, Address & Actions Bar
                  const DeliveryHeader(),

                  const Spacer(),

                  // 2. Banner Page Indicators (If multiple backend banners exist)
                  if (hasBanners && widget.banners.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          widget.banners.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: index == _currentIndex ? 22 : 7,
                            height: 5,
                            decoration: BoxDecoration(
                              color: index == _currentIndex
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 3. Search Bar + 10 Min Delivery Badge Row (Floating over Video)
                  if (widget.searchBar != null && widget.deliveryBadge != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                      child: Row(
                        children: [
                          Expanded(child: widget.searchBar!),
                          const SizedBox(width: 8),
                          widget.deliveryBadge!,
                        ],
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
}

/// Full-bleed Video Player Widget fitting 100% of header background.
class _FullBackgroundVideoPlayer extends StatefulWidget {
  const _FullBackgroundVideoPlayer({required this.banner});

  final PromoBanner banner;

  @override
  State<_FullBackgroundVideoPlayer> createState() =>
      __FullBackgroundVideoPlayerState();
}

class __FullBackgroundVideoPlayerState
    extends State<_FullBackgroundVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(_FullBackgroundVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banner.mediaUrl != widget.banner.mediaUrl) {
      _controller?.dispose();
      _isInitialized = false;
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final url = widget.banner.mediaUrl;
    if (url.isEmpty) return;

    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      } else {
        _controller = VideoPlayerController.asset(url);
      }

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0); // Muted autoplay background video
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Header video player initialization error for $url: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized && _controller != null) {
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }

    if (widget.banner.imageUrl.isNotEmpty) {
      return AppNetworkImage(
        url: widget.banner.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Container(
      color: context.colors.primary,
    );
  }
}

/// Full-bleed Image Banner Widget fitting 100% of header background.
class _FullBackgroundImage extends StatelessWidget {
  const _FullBackgroundImage({required this.banner});

  final PromoBanner banner;

  @override
  Widget build(BuildContext context) {
    return AppNetworkImage(
      url: banner.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}
