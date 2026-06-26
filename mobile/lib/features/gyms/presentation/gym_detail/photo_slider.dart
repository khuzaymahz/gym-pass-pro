import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/gp_tokens.dart';
import '../../data/gym_photo.dart';
import 'gym_detail_helpers.dart';

class PhotoSlider extends StatefulWidget {
  const PhotoSlider({
    super.key,
    required this.photos,
    required this.isAr,
    required this.fadeColor,
    required this.mediaBase,
  });
  final List<GymPhoto> photos;
  final bool isAr;
  final Color fadeColor;
  final String mediaBase;

  @override
  State<PhotoSlider> createState() => _PhotoSliderState();
}

class _PhotoSliderState extends State<PhotoSlider> {
  final PageController _controller = PageController();
  int _index = 0;
  bool _firstPrefetchDone = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Decoded-bitmap target width. The page hero is the device width
  /// rendered at the device pixel ratio — anything bigger than that
  /// is wasted RAM and decode time. Capped at 1600 px so a 4K phone
  /// with 3.5× DPR (≈1400 logical × 3.5 = 4900 raw) doesn't try to
  /// keep a 50 MB bitmap in cache; the cap is well above any sane
  /// hero JPEG.
  int _targetCacheWidth(BuildContext context) {
    final mq = MediaQuery.of(context);
    final raw = (mq.size.width * mq.devicePixelRatio).round();
    return raw.clamp(360, 1600);
  }

  /// `precacheImage` decodes the JPEG into the image-cache so when
  /// `PageView` builds the neighbour child, the bitmap is already
  /// ready and the swipe doesn't wait on network → decode. We do
  /// this on first frame for the visible page + the next one, then
  /// chase the user as they swipe.
  void _prefetchNeighbours(BuildContext context, int center) {
    final w = _targetCacheWidth(context);
    final candidates = <int>{center - 1, center + 1};
    for (final i in candidates) {
      if (i < 0 || i >= widget.photos.length) continue;
      final url = resolvePhotoUrl(widget.mediaBase, widget.photos[i].url);
      final provider = ResizeImage(
        CachedNetworkImageProvider(url),
        width: w,
      );
      // `precacheImage` is a no-op if the provider is already in the
      // cache, so calling it on every page change is cheap.
      precacheImage(provider, context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cacheW = _targetCacheWidth(context);
    if (!_firstPrefetchDone) {
      _firstPrefetchDone = true;
      // Defer to post-frame so the surrounding Scaffold has a chance
      // to lay out — `precacheImage` reads the size from MediaQuery,
      // which is stable by then.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _prefetchNeighbours(context, _index);
      });
    }
    return Stack(
      children: [
        Positioned.fill(
          // Two stacked ShaderMasks composite their alphas (each runs
          // BlendMode.dstIn on its child), so the photo's final
          // opacity at any pixel is `linearAlpha × radialAlpha`.
          //   * Outer (radial): keeps the center fully opaque, fades
          //     only the four corner pixels. Wide radius + late fade
          //     stop so the falloff stays tight to the corners and
          //     doesn't read as a global vignette.
          //   * Inner (linear): existing bottom-edge softening into
          //     the white card. Untouched.
          child: ShaderMask(
            shaderCallback: (rect) => const RadialGradient(
              center: Alignment.center,
              radius: 0.95,
              colors: [Colors.black, Colors.black, Colors.transparent],
              stops: [0.0, 0.75, 1.0],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.9, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.photos.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _prefetchNeighbours(context, i);
                },
                itemBuilder: (_, i) {
                  final photo = widget.photos[i];
                  final alt = widget.isAr
                      ? (photo.altTextAr ?? photo.altTextEn ?? '')
                      : (photo.altTextEn ?? photo.altTextAr ?? '');
                  return Semantics(
                    label: alt,
                    image: true,
                    // `CachedNetworkImage` adds three things `Image.network`
                    // doesn't:
                    //   1. `flutter_cache_manager`-backed disk cache —
                    //      cold launches no longer re-fetch every photo.
                    //   2. `memCacheWidth` — the JPEG decodes to the
                    //      display width, not the source width, so a
                    //      4000-px hero doesn't sit in RAM as a
                    //      4000×3000 ARGB bitmap (≈48 MB) for a
                    //      400-px slot.
                    //   3. `fadeInDuration` — the new photo crossfades
                    //      from the placeholder, which masks the brief
                    //      decode pause when paging.
                    child: CachedNetworkImage(
                      imageUrl: resolvePhotoUrl(widget.mediaBase, photo.url),
                      fit: BoxFit.cover,
                      memCacheWidth: cacheW,
                      maxWidthDiskCache: cacheW,
                      fadeInDuration: const Duration(milliseconds: 200),
                      fadeOutDuration: const Duration(milliseconds: 80),
                      placeholder: (_, __) =>
                          Container(color: widget.fadeColor),
                      errorWidget: (_, __, ___) =>
                          Container(color: widget.fadeColor),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 76,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.photos.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? GP.lime : Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
