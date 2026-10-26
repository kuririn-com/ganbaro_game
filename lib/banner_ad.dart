import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads.dart';

/// A separate, fixed footer so ads never cover content or action buttons.
/// Mount only on the visible title screen and after a game has ended.
class AppBanner extends StatefulWidget {
  final Ads ads;
  const AppBanner({super.key, required this.ads});

  @override
  State<AppBanner> createState() => _AppBannerState();
}

class _AppBannerState extends State<AppBanner> {
  BannerAd? _banner;
  bool _loaded = false;
  int? _requestedWidth;
  int _generation = 0;

  void _request(int width) {
    _requestedWidth = width;
    final generation = ++_generation;
    // Defer platform calls and disposal until the old AdWidget is unmounted.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || generation != _generation) return;
      final previous = _banner;
      setState(() {
        _banner = null;
        _loaded = false;
      });
      if (previous != null) await previous.dispose();
      try {
        final size =
            await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
              width,
            );
        if (!mounted || generation != _generation || size == null) return;
        final banner = BannerAd(
          adUnitId: widget.ads.bannerAdUnitId,
          request: const AdRequest(),
          size: size,
          listener: BannerAdListener(
            onAdLoaded: (ad) {
              if (!mounted || generation != _generation) {
                unawaited(ad.dispose());
                return;
              }
              setState(() => _loaded = true);
            },
            onAdFailedToLoad: (ad, error) {
              unawaited(ad.dispose());
              if (!mounted || generation != _generation) return;
              setState(() {
                _banner = null;
                _loaded = false;
              });
            },
          ),
        );
        _banner = banner;
        await banner.load();
      } catch (error) {
        if (!mounted || generation != _generation) return;
        final banner = _banner;
        setState(() {
          _banner = null;
          _loaded = false;
        });
        if (banner != null) unawaited(banner.dispose());
        debugPrint('Banner loading failed: $error');
      }
    });
  }

  @override
  void dispose() {
    _generation++;
    final banner = _banner;
    if (banner != null) unawaited(banner.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.ads,
    builder: (context, _) {
      if (!widget.ads.supported || widget.ads.bannerAdUnitId.isEmpty) {
        return const SizedBox.shrink();
      }
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = min(728, constraints.maxWidth).floor();
              if (width < 320) return const SizedBox.shrink();
              if (widget.ads.canLoadBanner && _requestedWidth != width) {
                _request(width);
              }
              final banner = _banner;
              final current = _requestedWidth == width;
              return SizedBox(
                // Standard anchored adaptive banners are at most 90dp high.
                // Reserve room while loading to keep the controls stationary.
                height: max(90, banner?.size.height ?? 0).toDouble(),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: current && _loaded && banner != null
                      ? Semantics(
                          label: '広告',
                          child: SizedBox(
                            width: banner.size.width.toDouble(),
                            height: banner.size.height.toDouble(),
                            child: AdWidget(ad: banner),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
