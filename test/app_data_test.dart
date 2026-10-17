import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ganbaro_game/app_data.dart';
import 'package:ganbaro_game/game_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy best scores migrate, settings and records survive reload',
    () async {
      SharedPreferences.setMockInitialValues({
        'best_score_normal': 4321,
        'best_score_level': 999,
      });
      final data = await AppData.load();
      expect(data.bestNormal, 4321);
      expect(data.bestLevel, 999);
      data.settings(
        soundEnabled: false,
        vibrationEnabled: false,
        soundVolume: 0.3,
      );
      data.startGame(GameMode.normal);
      final g = GameEngine(mode: GameMode.normal);
      g.lines = 4;
      g.fourLines = 1;
      g.maxCombo = 2;
      g.score = 6000;
      data.recordStep(g, previousLines: 0, previousFour: 0);
      data.recordStep(g, previousLines: 4, previousFour: 1);
      data.clearMission(0);
      data.clearMission(0);
      await data.flush();
      final restored = await AppData.load();
      expect(restored.bestNormal, 6000);
      expect(restored.bestLevel, 999);
      expect(restored.record('lines'), 4);
      expect(restored.record('four'), 1);
      expect(restored.record('games'), 1);
      expect(restored.record('combo'), 2);
      expect(restored.completed, {0});
      expect(restored.sound, false);
      expect(restored.vibration, false);
      expect(restored.volume, 0.3);
    },
  );

  test('mission score never overwrites normal-mode record', () async {
    SharedPreferences.setMockInitialValues({'best_score_normal': 500});
    final data = await AppData.load();
    final g = GameEngine(mode: GameMode.mission, mission: missions[0]);
    g.score = 99999;
    data.recordStep(g, previousLines: 0, previousFour: 0);
    await data.flush();
    expect(data.bestNormal, 500);
  });
}
