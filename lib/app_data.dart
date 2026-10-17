import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_engine.dart';

class AppData extends ChangeNotifier {
  final SharedPreferences prefs;
  bool sound, vibration;
  double volume;
  int bestLevel, bestNormal;
  Map<String, int> records;
  Set<int> completed;
  Future<void> _pending = Future.value();

  AppData._(
    this.prefs,
    this.sound,
    this.vibration,
    this.volume,
    this.bestLevel,
    this.bestNormal,
    this.records,
    this.completed,
  );

  static Future<AppData> load() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, int> records = {};
    try {
      final json =
          jsonDecode(prefs.getString('play_records_v2') ?? '{}')
              as Map<String, dynamic>;
      records = json.map((key, value) => MapEntry(key, (value as num).toInt()));
    } catch (_) {
      /* A corrupt optional record must not block launch. */
    }
    return AppData._(
      prefs,
      prefs.getBool('sound_enabled') ?? true,
      prefs.getBool('vibration_enabled') ?? true,
      (prefs.getDouble('sound_volume') ?? 0.6).clamp(0.0, 1.0),
      prefs.getInt('best_score_level') ?? 0,
      prefs.getInt('best_score_normal') ?? 0,
      records,
      (prefs.getStringList('completed_missions_v2') ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet(),
    );
  }

  int record(String key) => records[key] ?? 0;
  void startGame(GameMode mode) {
    records['games'] = record('games') + 1;
    if (mode == GameMode.level && record('level') < 1) records['level'] = 1;
    records['games_${mode.name}'] = record('games_${mode.name}') + 1;
    _persist();
  }

  // Called once per resolved placement/bomb. Deltas prevent duplicate totals.
  void recordStep(
    GameEngine game, {
    required int previousLines,
    required int previousFour,
  }) {
    records['lines'] = record('lines') + game.lines - previousLines;
    records['four'] = record('four') + game.fourLines - previousFour;
    if (game.maxCombo > record('combo')) records['combo'] = game.maxCombo;
    if (game.mode == GameMode.level) {
      if (game.level > record('level')) records['level'] = game.level;
      if (game.score > bestLevel) bestLevel = game.score;
    } else if (game.mode == GameMode.normal && game.score > bestNormal) {
      bestNormal = game.score;
    }
    _persist();
  }

  void clearMission(int index) {
    if (completed.add(index)) _persist();
  }

  void settings({
    bool? soundEnabled,
    bool? vibrationEnabled,
    double? soundVolume,
  }) {
    sound = soundEnabled ?? sound;
    vibration = vibrationEnabled ?? vibration;
    volume = soundVolume ?? volume;
    _persist();
  }

  void _persist() {
    // Snapshot before queuing so writes from an earlier move cannot win a race.
    final snapshot = jsonEncode(records);
    final missionSnapshot = completed.map((i) => '$i').toList();
    final levelSnapshot = bestLevel, normalSnapshot = bestNormal;
    final soundSnapshot = sound,
        vibrationSnapshot = vibration,
        volumeSnapshot = volume;
    _pending = _pending
        .then((_) async {
          await prefs.setString('play_records_v2', snapshot);
          await prefs.setStringList('completed_missions_v2', missionSnapshot);
          await prefs.setInt('best_score_level', levelSnapshot);
          await prefs.setInt('best_score_normal', normalSnapshot);
          await prefs.setBool('sound_enabled', soundSnapshot);
          await prefs.setBool('vibration_enabled', vibrationSnapshot);
          await prefs.setDouble('sound_volume', volumeSnapshot);
        })
        .catchError((Object error) {
          debugPrint('Local save failed: $error');
        });
    notifyListeners();
  }

  Future<void> flush() => _pending;
}
