import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

class Ads extends ChangeNotifier {
  RewardedAd? _reward;
  InterstitialAd? _interstitial;
  bool _disposed = false, _ready = false, busy = false;
  bool get available => _reward != null && !busy;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> initialize() async {
    if (!supported) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
      await MobileAds.instance.initialize();
      if (_disposed) return;
      _ready = true;
      _loadReward();
      _loadInterstitial();
    } catch (error) {
      debugPrint('Ads initialization failed: $error');
    }
  }

  void _loadReward() {
    if (_disposed || !_ready) return;
    RewardedAd.load(
      adUnitId: 'ca-app-pub-9003840415284448/5493879760',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _reward = ad;
          notifyListeners();
        },
        onAdFailedToLoad: (_) {
          if (!_disposed) {
            _reward = null;
            notifyListeners();
          }
        },
      ),
    );
  }

  void _loadInterstitial() {
    if (_disposed || !_ready) return;
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-9003840415284448/6721545961',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
          } else {
            _interstitial = ad;
          }
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
        },
      ),
    );
  }

  void showReward(VoidCallback earn) {
    final ad = _reward;
    if (ad == null || busy) {
      if (_ready) _loadReward();
      return;
    }
    _reward = null;
    busy = true;
    notifyListeners();
    void finish() {
      ad.dispose();
      busy = false;
      if (!_disposed) {
        notifyListeners();
        _loadReward();
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) => finish(),
    );
    ad.show(
      onUserEarnedReward: (_, reward) {
        if (!_disposed) earn();
      },
    );
  }

  Future<void> beforeRestart() async {
    final ad = _interstitial;
    if (ad == null || busy) {
      if (_ready) _loadInterstitial();
      return;
    }
    _interstitial = null;
    busy = true;
    final done = Completer<void>();
    void finish() {
      ad.dispose();
      busy = false;
      if (!_disposed) _loadInterstitial();
      if (!done.isCompleted) done.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) => finish(),
    );
    try {
      await ad.show();
    } catch (_) {
      finish();
    }
    await done.future;
  }

  @override
  void dispose() {
    _disposed = true;
    _reward?.dispose();
    _interstitial?.dispose();
    super.dispose();
  }
}
