import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The SDK's codec is required for the native-channel test double.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:ganbaro_game/ads.dart';
import 'package:ganbaro_game/banner_ad.dart';

class BannerTestAds extends Ads {
  bool ready = false;
  @override
  bool get supported => true;
  @override
  bool get canLoadBanner => ready;
  void becomeReady() {
    ready = true;
    notifyListeners();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final loads = <int>[];
  final disposals = <int>[];
  Completer<int>? pendingSize;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    loads.clear();
    disposals.clear();
    pendingSize = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      instanceManager.channel,
      (call) async {
        if (call.method == 'AdSize#getAnchoredAdaptiveBannerAdSize') {
          return pendingSize == null ? 50 : pendingSize!.future;
        }
        if (call.method == 'loadBannerAd') {
          loads.add((call.arguments as Map)['adId'] as int);
        }
        if (call.method == 'disposeAd') {
          disposals.add((call.arguments as Map)['adId'] as int);
        }
        return null;
      },
    );
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      instanceManager.channel,
      null,
    );
  });

  Future<void> show(WidgetTester tester, Ads ads, {double width = 375}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: width,
              child: AppBanner(ads: ads),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('waits for initialization and disposes on route removal', (
    tester,
  ) async {
    final ads = BannerTestAds();
    await show(tester, ads);
    expect(loads, isEmpty);
    ads.becomeReady();
    await tester.pumpAndSettle();
    expect(loads, hasLength(1));
    final banner = instanceManager.adFor(loads.single)! as BannerAd;
    expect(banner.adUnitId, 'ca-app-pub-3940256099942544/2435281174');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(disposals, loads);
    ads.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('no fill keeps the footer stable without retry loops', (
    tester,
  ) async {
    final ads = BannerTestAds()..becomeReady();
    await show(tester, ads);
    final height = tester.getSize(find.byType(AppBanner)).height;
    final banner = instanceManager.adFor(loads.single)! as BannerAd;
    banner.listener.onAdFailedToLoad!(
      banner,
      LoadAdError(3, 'test', 'No fill', null),
    );
    await tester.pumpAndSettle();
    expect(disposals, loads);
    expect(tester.getSize(find.byType(AppBanner)).height, height);
    ads.notifyListeners();
    await tester.pumpAndSettle();
    expect(loads, hasLength(1));
    expect(tester.takeException(), null);
    await tester.pumpWidget(const SizedBox());
    ads.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('leaving during size lookup never loads an offscreen ad', (
    tester,
  ) async {
    final ads = BannerTestAds()..becomeReady();
    pendingSize = Completer<int>();
    await show(tester, ads);
    await tester.pumpWidget(const SizedBox());
    pendingSize!.complete(50);
    await tester.pumpAndSettle();
    expect(loads, isEmpty);
    expect(tester.takeException(), null);
    ads.dispose();
    debugDefaultTargetPlatformOverride = null;
  });
}
