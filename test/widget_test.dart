import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ganbaro_game/main.dart';
import 'package:ganbaro_game/app_data.dart';
import 'package:ganbaro_game/game_engine.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({
      'sound_enabled': false,
      'vibration_enabled': false,
    });
    final messenger = binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (_) async => 1,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return 1;
      },
    );
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> launch(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    final data = await AppData.load();
    await tester.pumpWidget(BlockPuzzleApp(data: data));
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  }

  testWidgets('small iPhone layout, pause, resume, long press and swipes', (
    tester,
  ) async {
    await launch(tester, const Size(375, 667));
    await tester.tap(find.text('通常モード'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    final dynamic state = tester.state(find.byType(GameScreen));
    final GameEngine g = state.game as GameEngine;
    expect(find.text('NEXT'), findsOneWidget);
    await tester.tap(find.byTooltip('一時停止'));
    await tester.pumpAndSettle();
    final pausedY = g.y, pausedX = g.x;
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.arrow_right_rounded));
    await tester.pump();
    expect(g.y, pausedY);
    expect(g.x, pausedX);
    await tester.tap(find.text('つづける'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 510));
    expect(g.y, greaterThan(pausedY));
    final x = g.x;
    final pointer = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.arrow_left_rounded)),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await pointer.up();
    await tester.pump();
    expect(g.x, lessThan(x));
    final board = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is BoardPainter,
    );
    await tester.drag(board, const Offset(60, 0));
    await tester.pump();
    final score = g.score;
    await tester.drag(board, const Offset(0, 75));
    await tester.pump();
    expect(
      g.board.expand((r) => r).whereType<Cell>().length,
      greaterThanOrEqualTo(4),
    );
    expect(g.score, greaterThanOrEqualTo(score));
    expect(tester.takeException(), null);
    await finish(tester);
  });

  testWidgets('app background pauses until manually resumed', (tester) async {
    await launch(tester, const Size(390, 844));
    await tester.tap(find.text('通常モード'));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(GameScreen));
    final GameEngine g = state.game as GameEngine;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    final y = g.y;
    await tester.pump(const Duration(seconds: 2));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('一時停止'), findsOneWidget);
    expect(g.y, y);
    await tester.tap(find.text('つづける'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 510));
    expect(g.y, greaterThan(y));
    await finish(tester);
  });

  testWidgets('pausing a line clear resolves it once after resume', (
    tester,
  ) async {
    await launch(tester, const Size(390, 844));
    await tester.tap(find.text('通常モード'));
    await tester.pumpAndSettle();
    final dynamic state = tester.state(find.byType(GameScreen));
    final GameEngine g = state.game as GameEngine;
    for (var row = 20; row < 24; row++) {
      for (var col = 0; col < 11; col++) {
        g.board[row][col] = const Cell(1);
      }
    }
    g.piece = [
      [1],
      [1],
      [1],
      [1],
    ];
    g.x = 11;
    g.y = 0;
    g.starX = -1;
    g.starY = -1;
    await tester.tap(find.byIcon(Icons.vertical_align_bottom_rounded));
    await tester.pump();
    expect(g.clearingRows.length, 4);
    await tester.tap(find.byTooltip('一時停止'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(g.score, 0);
    await tester.tap(find.text('つづける'));
    await tester.pump();
    expect(g.score, 1600);
    expect(g.lines, 4);
    await tester.pump(const Duration(milliseconds: 350));
    expect(g.score, 1600);
    await finish(tester);
  });

  testWidgets('landscape layout and mission menu have no overflow', (
    tester,
  ) async {
    await launch(tester, const Size(568, 320));
    await tester.ensureVisible(find.text('ミッションモード'));
    await tester.tap(find.text('ミッションモード'));
    await tester.pumpAndSettle();
    expect(find.text('1. はじめの10ライン'), findsOneWidget);
    await tester.tap(find.text('1. はじめの10ライン'));
    await tester.pumpAndSettle();
    expect(find.textContaining('合計10ラインを消そう'), findsOneWidget);
    expect(tester.takeException(), null);
    await finish(tester);
  });

  testWidgets('settings, records, and rendered board are available', (
    tester,
  ) async {
    await launch(tester, const Size(390, 844));
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    expect(find.text('効果音'), findsOneWidget);
    expect(find.text('振動'), findsOneWidget);
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('プレイ記録'));
    await tester.pumpAndSettle();
    expect(find.text('累計消去ライン'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('通常モード'));
    await tester.pumpAndSettle();
    // Save a local QA image only when explicitly running this test with the flag.
    if (const bool.fromEnvironment('BLOCKPOP_QA_IMAGE')) {
      final board = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BoardPainter,
      );
      final element = tester.element(board);
      final render = element.findRenderObject()!;
      RenderObject? ancestor = render;
      while (ancestor != null && ancestor is! RenderRepaintBoundary) {
        ancestor = ancestor.parent;
      }
      if (ancestor is RenderRepaintBoundary) {
        await tester.runAsync(() async {
          final image = await (ancestor as RenderRepaintBoundary).toImage(
            pixelRatio: 2,
          );
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/blockpop-qa.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        });
      }
    }
    expect(tester.takeException(), null);
    await finish(tester);
  });
}
