import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'ads.dart';
import 'app_data.dart';
import 'game_engine.dart';

const blockColors = <Color>[
  Colors.cyan,
  Colors.yellow,
  Colors.purple,
  Colors.orange,
  Colors.blue,
  Colors.green,
  Colors.pink,
];
const accent = Color(0xffffb454);
const background = Color(0xff10141e);
const panel = Color(0xff1d2433);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final data = await AppData.load();
  runApp(BlockPuzzleApp(data: data));
}

class BlockPuzzleApp extends StatelessWidget {
  final AppData data;
  const BlockPuzzleApp({super.key, required this.data});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Block Pop',
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(color: panel),
    ),
    home: TitleScreen(data: data),
  );
}

Widget infoCard(
  Widget child, {
  EdgeInsets padding = const EdgeInsets.all(16),
}) => Container(
  padding: padding,
  decoration: BoxDecoration(
    color: panel,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.white10),
  ),
  child: child,
);

class TitleScreen extends StatefulWidget {
  final AppData data;
  const TitleScreen({super.key, required this.data});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  final Ads ads = Ads();
  int bombs = 0;
  bool _adInitStarted = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_adInitStarted) {
        _adInitStarted = true;
        ads.initialize();
      }
    });
  }

  @override
  void dispose() {
    ads.dispose();
    super.dispose();
  }

  Future<void> _start(GameMode mode, {int? missionIndex}) async {
    // Mission scores use a separate challenge with no ad-earned starting items.
    final carry = mode == GameMode.mission ? 0 : bombs;
    if (mode != GameMode.mission) setState(() => bombs = 0);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          data: widget.data,
          ads: ads,
          mode: mode,
          initialBombs: carry,
          missionIndex: missionIndex,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.data, ads]),
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'プレイ記録',
                        icon: const Icon(Icons.bar_chart_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => RecordsScreen(data: widget.data),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '設定',
                        icon: const Icon(Icons.settings_rounded),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SettingsScreen(data: widget.data),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.grid_view_rounded, size: 72, color: accent),
                  const SizedBox(height: 12),
                  const Text(
                    'Block Pop',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const Text(
                    'つなげて、消して、もう一回。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 24),
                  infoCard(
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _best('レベルモード BEST', widget.data.bestLevel, accent),
                        _best(
                          '通常モード BEST',
                          widget.data.bestNormal,
                          Colors.cyanAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _mode(
                    'レベルアップモード',
                    'レベル50を目指して挑戦',
                    Icons.local_fire_department,
                    accent,
                    () => _start(GameMode.level),
                  ),
                  const SizedBox(height: 12),
                  _mode(
                    '通常モード',
                    '一定の速さでじっくりプレイ',
                    Icons.grid_on,
                    Colors.cyanAccent,
                    () => _start(GameMode.normal),
                  ),
                  const SizedBox(height: 12),
                  _mode(
                    'ミッションモード',
                    '${widget.data.completed.length} / ${missions.length} クリア',
                    Icons.flag_rounded,
                    Colors.purpleAccent,
                    _missions,
                  ),
                  const SizedBox(height: 24),
                  infoCard(
                    Column(
                      children: [
                        Text(
                          'スタート用ボム：$bombs 個',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: ads.available
                              ? () => ads.showReward(() {
                                  if (mounted) setState(() => bombs += 3);
                                })
                              : null,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('動画を見てボム +3'),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ads.available
                              ? '通常・レベルアップモードで使えます'
                              : '広告の準備ができると利用できます',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'タップで回転 ／ スワイプで移動\n下へ素早くスワイプで一気に落下',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      height: 1.6,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _best(String label, int value, Color color) => Column(
    children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
      const SizedBox(height: 4),
      Text(
        '$value',
        style: TextStyle(
          fontSize: 25,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
  Widget _mode(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) => Material(
    color: panel,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    ),
  );

  void _missions() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('ミッション')),
          body: AnimatedBuilder(
            animation: widget.data,
            builder: (context, _) => ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: missions.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final done = widget.data.completed.contains(index);
                final unlocked =
                    index == 0 || widget.data.completed.contains(index - 1);
                return infoCard(
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: done ? Colors.green : Colors.white10,
                      child: Icon(
                        done
                            ? Icons.check
                            : unlocked
                            ? Icons.flag
                            : Icons.lock,
                        color: Colors.white,
                      ),
                    ),
                    title: Text('${index + 1}. ${missions[index].title}'),
                    subtitle: Text(missions[index].description),
                    trailing: const Icon(Icons.chevron_right),
                    enabled: unlocked,
                    onTap: unlocked
                        ? () => _start(GameMode.mission, missionIndex: index)
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final AppData data;
  const SettingsScreen({super.key, required this.data});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('設定')),
    body: AnimatedBuilder(
      animation: data,
      builder: (_, child) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          infoCard(
            Column(
              children: [
                SwitchListTile(
                  title: const Text('効果音'),
                  subtitle: const Text('移動・配置・ライン消去の音'),
                  value: data.sound,
                  onChanged: (v) => data.settings(soundEnabled: v),
                ),
                ListTile(
                  title: Text('効果音の音量　${(data.volume * 100).round()}%'),
                  subtitle: Slider(
                    value: data.volume,
                    divisions: 10,
                    onChanged: data.sound
                        ? (v) => data.settings(soundVolume: v)
                        : null,
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('振動'),
                  subtitle: const Text('配置・ライン消去・ボム使用時'),
                  value: data.vibration,
                  onChanged: (v) => data.settings(vibrationEnabled: v),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '振動は対応端末で動作します。\n設定とプレイ記録はこの端末に保存されます。',
              style: TextStyle(color: Colors.white54, height: 1.7),
            ),
          ),
        ],
      ),
    ),
  );
}

class RecordsScreen extends StatelessWidget {
  final AppData data;
  const RecordsScreen({super.key, required this.data});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('プレイ記録')),
    body: AnimatedBuilder(
      animation: data,
      builder: (_, child) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          infoCard(
            Column(
              children: [
                _row('通常モード 最高スコア', '${data.bestNormal}'),
                _row('レベルモード 最高スコア', '${data.bestLevel}'),
                _row('最高到達レベル', '${data.record('level')} / 50'),
                _row('合計プレイ回数', '${data.record('games')} 回'),
                _row('累計消去ライン', '${data.record('lines')} ライン'),
                _row('4ライン同時消去', '${data.record('four')} 回'),
                _row('最大コンボ', '${data.record('combo')} 回'),
                _row(
                  'ミッションクリア',
                  '${data.completed.length} / ${missions.length}',
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '累計記録はこのアップデート後から集計します。\n以前の最高スコアはそのまま引き継がれます。\nボムで消した段は、消去ライン数に含みません。',
              style: TextStyle(color: Colors.white54, height: 1.7),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class GameScreen extends StatefulWidget {
  final AppData data;
  final Ads ads;
  final GameMode mode;
  final int initialBombs;
  final int? missionIndex;
  const GameScreen({
    super.key,
    required this.data,
    required this.ads,
    required this.mode,
    this.initialBombs = 0,
    this.missionIndex,
  });
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late GameEngine game;
  Timer? _timer, _repeatDelay, _repeat, _effectTimer, _toastTimer;
  late final AnimationController _effect;
  final _moveAudio = AudioPlayer(),
      _placeAudio = AudioPlayer(),
      _clearAudio = AudioPlayer();
  bool _paused = false,
      _resolving = false,
      _effectReady = false,
      _bombEffect = false;
  bool _restarting = false, _exitOpen = false, _allowExit = false;
  String _toast = '';
  double _dragX = 0, _dragY = 0, _cellSize = 20;
  int _dragAxis = 0;
  bool _droppedInGesture = false;
  int _moveSoundAt = 0;
  bool get _canInput =>
      !_paused && !_resolving && !game.over && !game.won && !_restarting;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _effect = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _newGame(widget.initialBombs);
  }

  void _newGame(int bombs) {
    _timer?.cancel();
    _effectTimer?.cancel();
    _toastTimer?.cancel();
    _stopRepeat();
    game = GameEngine(
      mode: widget.mode,
      initialBombs: bombs,
      mission: widget.missionIndex == null
          ? null
          : missions[widget.missionIndex!],
    );
    _paused = false;
    _resolving = false;
    _effectReady = false;
    _bombEffect = false;
    _toast = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.data.startGame(widget.mode);
    });
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_paused || _resolving || game.over || game.won) return;
    _timer = Timer.periodic(Duration(milliseconds: game.speedMs), (_) {
      if (!_canInput) return;
      if (game.step()) {
        _lock();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  void _pause() {
    _stopRepeat();
    _timer?.cancel();
    if (!mounted || _paused || game.over || game.won) return;
    _effect.stop();
    setState(() => _paused = true);
    _moveAudio.stop();
    _placeAudio.stop();
    _clearAudio.stop();
  }

  void _resume() {
    if (!_paused || _exitOpen) return;
    setState(() => _paused = false);
    if (_resolving && _effectReady) {
      _completeEffect();
    } else if (_resolving) {
      _effect.forward();
    } else {
      _schedule();
    }
  }

  Future<void> _sound(AudioPlayer player, String file) async {
    if (!widget.data.sound || widget.data.volume <= 0) return;
    try {
      await player.setVolume(widget.data.volume);
      await player.play(AssetSource('audio/$file.mp3'));
    } catch (error) {
      debugPrint('Audio unavailable: $error');
    }
  }

  void _moveSound() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _moveSoundAt < 90) return;
    _moveSoundAt = now;
    _sound(_moveAudio, 'fall');
  }

  void _vibrate({bool strong = false}) {
    if (!widget.data.vibration || kIsWeb) return;
    if (strong) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _move(int dx) {
    if (!_canInput) return;
    if (game.move(dx)) {
      _moveSound();
      setState(() {});
    }
  }

  void _rotate() {
    if (!_canInput) return;
    if (game.rotate()) {
      _moveSound();
      setState(() {});
    }
  }

  void _drop() {
    if (!_canInput) return;
    game.drop();
    _lock();
  }

  void _lock() {
    if (!_canInput) return;
    _timer?.cancel();
    _stopRepeat();
    game.lock();
    _sound(_placeAudio, 'place');
    _vibrate();
    if (game.clearingRows.isEmpty) {
      _resolvePlacement();
    } else {
      _beginEffect(false);
    }
  }

  void _beginEffect(bool bomb) {
    _timer?.cancel();
    _stopRepeat();
    setState(() {
      _resolving = true;
      _effectReady = false;
      _bombEffect = bomb;
    });
    _sound(_clearAudio, 'clear');
    _vibrate(strong: true);
    _effect.forward(from: 0);
    _effectTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _effectReady = true;
      if (!_paused) _completeEffect();
    });
  }

  void _completeEffect() {
    if (!_resolving || !_effectReady || _paused) return;
    final wasBomb = _bombEffect;
    setState(() {
      _resolving = false;
      _bombEffect = false;
      _effectReady = false;
    });
    if (wasBomb) {
      final oldLines = game.lines, oldFour = game.fourLines;
      game.useBomb();
      widget.data.recordStep(
        game,
        previousLines: oldLines,
        previousFour: oldFour,
      );
      _message('BOMB!  +${game.lastPoints}');
      _checkEnd();
      setState(() {});
      _schedule();
    } else {
      _resolvePlacement();
    }
  }

  void _resolvePlacement() {
    final oldLines = game.lines, oldFour = game.fourLines;
    game.resolve();
    widget.data.recordStep(
      game,
      previousLines: oldLines,
      previousFour: oldFour,
    );
    if (game.lastCleared > 0) {
      final label = game.lastCleared == 4
          ? '4 LINE CLEAR!'
          : '${game.lastCleared} LINE CLEAR!';
      _message(
        '$label\n${game.combo > 1 ? '${game.combo} COMBO!  ' : ''}+${game.lastPoints}',
      );
    }
    _checkEnd();
    setState(() {});
    _schedule();
  }

  void _checkEnd() {
    if (game.won && widget.missionIndex != null) {
      widget.data.clearMission(widget.missionIndex!);
    }
    if (game.over || game.won) {
      _timer?.cancel();
      _stopRepeat();
    }
  }

  void _message(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 1250), () {
      if (mounted) setState(() => _toast = '');
    });
  }

  void _bomb() {
    if (!_canInput || game.bombs <= 0) return;
    _beginEffect(true);
  }

  void _startRepeat(int dx) {
    _stopRepeat();
    if (!_canInput) return;
    _move(dx);
    _repeatDelay = Timer(const Duration(milliseconds: 220), () {
      if (!_canInput) return;
      _repeat = Timer.periodic(
        const Duration(milliseconds: 75),
        (_) => _move(dx),
      );
    });
  }

  void _stopRepeat() {
    _repeatDelay?.cancel();
    _repeat?.cancel();
  }

  Future<void> _confirmExit() async {
    if (_exitOpen || _restarting) return;
    _pause();
    _exitOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ゲームを終了しますか？'),
        content: const Text('現在の盤面は終了します。獲得済みの記録は保存されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('終了する'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _exitOpen = false;
    if (leave == true) _leave();
  }

  Future<void> _leave() async {
    _timer?.cancel();
    _stopRepeat();
    await widget.data.flush();
    if (!mounted) return;
    setState(() => _allowExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _restart() async {
    if (_restarting) return;
    setState(() => _restarting = true);
    await widget.ads.beforeRestart();
    if (!mounted) return;
    setState(() {
      _restarting = false;
      _newGame(0);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _effectTimer?.cancel();
    _toastTimer?.cancel();
    _stopRepeat();
    _effect.dispose();
    _moveAudio.dispose();
    _placeAudio.dispose();
    _clearAudio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _confirmExit();
    },
    child: Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > constraints.maxHeight;
            return Column(
              children: [
                _header(),
                Expanded(
                  child: wide
                      ? Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: _board(),
                              ),
                            ),
                            SizedBox(
                              width: min(280, constraints.maxWidth * 0.4),
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    _status(),
                                    const SizedBox(height: 16),
                                    _next(),
                                    const SizedBox(height: 12),
                                    _controls(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: _status(),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 4,
                              ),
                              child: _next(),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  12,
                                  4,
                                ),
                                child: _board(),
                              ),
                            ),
                            _controls(),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: '終了',
          icon: const Icon(Icons.close),
          onPressed: _confirmExit,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                widget.mode == GameMode.level
                    ? 'LEVEL ${game.level} / 50'
                    : widget.mode == GameMode.mission
                    ? 'MISSION ${(widget.missionIndex ?? 0) + 1}'
                    : 'NORMAL MODE',
                style: const TextStyle(
                  fontSize: 12,
                  color: accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${game.score}',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '一時停止',
          onPressed: game.over || game.won ? null : _pause,
          icon: const Icon(Icons.pause_circle_outline, size: 30),
        ),
        const SizedBox(width: 4),
        FilledButton.tonalIcon(
          onPressed: _canInput && game.bombs > 0 ? _bomb : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          icon: const Icon(Icons.bolt, color: accent),
          label: Text('×${game.bombs}'),
        ),
      ],
    ),
  );

  Widget _status() {
    if (game.mission != null) {
      final mission = game.mission!;
      return Column(
        children: [
          Text(
            '${mission.description}　${min(game.missionProgress, mission.target)} / ${mission.target}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (game.missionProgress / mission.target).clamp(0.0, 1.0),
              minHeight: 5,
              color: Colors.purpleAccent,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text(
          'BEST ${widget.mode == GameMode.level ? widget.data.bestLevel : widget.data.bestNormal}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        Text(
          'LINES ${game.lines}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _next() => FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'NEXT',
          style: TextStyle(
            fontSize: 10,
            color: Colors.white54,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(width: 12),
        ...game.next.map(
          (index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: SizedBox(
              width: 44,
              height: 24,
              child: CustomPaint(painter: PreviewPainter(index)),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _controls() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children:
              [
                    _direction(-1, Icons.arrow_left_rounded, '左へ移動（長押しで連続）'),
                    _action(Icons.rotate_right_rounded, '回転', _rotate),
                    _action(
                      Icons.vertical_align_bottom_rounded,
                      '一気に落下',
                      _drop,
                    ),
                    _direction(1, Icons.arrow_right_rounded, '右へ移動（長押しで連続）'),
                  ]
                  .map(
                    (child) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: child,
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 5),
        const Text(
          '左右長押しで連続移動',
          style: TextStyle(fontSize: 10, color: Colors.white38),
        ),
      ],
    ),
  );

  Widget _direction(int dx, IconData icon, String label) => Semantics(
    label: label,
    button: true,
    enabled: _canInput,
    onTap: () => _move(dx),
    child: Listener(
      onPointerDown: (_) => _startRepeat(dx),
      onPointerUp: (_) => _stopRepeat(),
      onPointerCancel: (_) => _stopRepeat(),
      child: _buttonFace(icon),
    ),
  );
  Widget _action(IconData icon, String label, VoidCallback tap) => Semantics(
    label: label,
    button: true,
    enabled: _canInput,
    child: GestureDetector(
      onTap: _canInput ? tap : null,
      child: _buttonFace(icon),
    ),
  );
  Widget _buttonFace(IconData icon) => Container(
    width: 52,
    height: 50,
    decoration: BoxDecoration(
      color: _canInput ? panel : panel.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white12),
    ),
    child: Icon(
      icon,
      color: _canInput ? Colors.white : Colors.white24,
      size: 33,
    ),
  );

  Widget _board() => LayoutBuilder(
    builder: (context, constraints) {
      final w = min(
        constraints.maxWidth,
        constraints.maxHeight * GameEngine.width / GameEngine.height,
      );
      final h = w * GameEngine.height / GameEngine.width;
      _cellSize = w / GameEngine.width;
      return Center(
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _rotate,
                onPanStart: (_) {
                  _dragX = 0;
                  _dragY = 0;
                  _dragAxis = 0;
                  _droppedInGesture = false;
                },
                onPanUpdate: (details) {
                  if (!_canInput || _droppedInGesture) return;
                  _dragX += details.delta.dx;
                  _dragY += details.delta.dy;
                  final threshold = max(12.0, _cellSize * 0.7);
                  if (_dragAxis == 0 &&
                      max(_dragX.abs(), _dragY.abs()) > threshold) {
                    _dragAxis = _dragX.abs() >= _dragY.abs() ? 1 : 2;
                  }
                  if (_dragAxis == 1) {
                    while (_dragX.abs() >= threshold) {
                      final dx = _dragX > 0 ? 1 : -1;
                      _move(dx);
                      _dragX -= dx * threshold;
                    }
                  } else if (_dragAxis == 2 &&
                      _dragY > max(42, _cellSize * 2.5)) {
                    _droppedInGesture = true;
                    _drop();
                  }
                },
                child: AnimatedBuilder(
                  animation: _effect,
                  builder: (_, child) => CustomPaint(
                    painter: BoardPainter(
                      game,
                      resolving: _resolving,
                      bomb: _bombEffect,
                      effect: _effect.value,
                    ),
                  ),
                ),
              ),
              if (_toast.isNotEmpty && !_paused && !game.over && !game.won)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _toast,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: game.combo >= 2
                              ? Colors.yellowAccent
                              : Colors.white,
                          fontSize: w < 220 ? 16 : 22,
                          fontWeight: FontWeight.w900,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_paused && !game.over && !game.won) _pauseOverlay(),
              if (game.over || game.won) _endOverlay(),
            ],
          ),
        ),
      );
    },
  );

  Widget _overlay(Widget child) => Container(
    color: background.withValues(alpha: 0.95),
    child: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    ),
  );

  Widget _pauseOverlay() => _overlay(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.pause_circle, size: 48, color: accent),
        const SizedBox(height: 12),
        const Text(
          '一時停止',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _resume,
          icon: const Icon(Icons.play_arrow),
          label: const Text('つづける'),
        ),
        TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => SettingsScreen(data: widget.data),
            ),
          ),
          icon: const Icon(Icons.settings),
          label: const Text('設定'),
        ),
        TextButton(onPressed: _confirmExit, child: const Text('ゲームを終了')),
      ],
    ),
  );

  Widget _endOverlay() => _overlay(
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          game.won ? Icons.emoji_events : Icons.grid_view_rounded,
          size: 48,
          color: game.won ? accent : Colors.white54,
        ),
        const SizedBox(height: 12),
        Text(
          game.won ? 'MISSION CLEAR!' : 'GAME OVER',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: game.won ? accent : Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'SCORE  ${game.score}',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          '${game.lines} LINES  /  MAX ${game.maxCombo} COMBO',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        if (widget.mode == GameMode.level)
          Text('LEVEL ${game.level}', style: const TextStyle(color: accent)),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _restarting ? null : _restart,
          child: Text(_restarting ? '準備中…' : 'もう一回'),
        ),
        TextButton(
          onPressed: _restarting ? null : _leave,
          child: Text(widget.mode == GameMode.mission ? 'ミッション一覧へ' : 'タイトルへ'),
        ),
      ],
    ),
  );
}

class PreviewPainter extends CustomPainter {
  final int index;
  PreviewPainter(this.index);
  @override
  void paint(Canvas canvas, Size size) {
    final shape = GameEngine.shapes[index];
    final cell = min(size.width / 4, size.height / 2);
    final left = (size.width - shape[0].length * cell) / 2;
    final top = (size.height - shape.length * cell) / 2;
    for (var r = 0; r < shape.length; r++) {
      for (var c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                left + c * cell + 1,
                top + r * cell + 1,
                cell - 2,
                cell - 2,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = blockColors[index],
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PreviewPainter oldDelegate) =>
      oldDelegate.index != index;
}

class BoardPainter extends CustomPainter {
  final GameEngine game;
  final bool resolving, bomb;
  final double effect;
  BoardPainter(
    this.game, {
    required this.resolving,
    required this.bomb,
    required this.effect,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / GameEngine.width;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xff161d29),
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.6;
    for (var c = 0; c <= GameEngine.width; c++) {
      canvas.drawLine(Offset(c * cell, 0), Offset(c * cell, size.height), grid);
    }
    for (var r = 0; r <= GameEngine.height; r++) {
      canvas.drawLine(Offset(0, r * cell), Offset(size.width, r * cell), grid);
    }
    void drawCell(
      int x,
      int y,
      int color, {
      bool ghost = false,
      bool star = false,
    }) {
      if (y < 0) return;
      final rect = Rect.fromLTWH(
        x * cell + 1,
        y * cell + 1,
        cell - 2,
        cell - 2,
      );
      final radius = Radius.circular(cell * 0.12);
      final paint = Paint()
        ..color = blockColors[color].withValues(alpha: ghost ? 0.15 : 1);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      if (ghost) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, radius),
          Paint()
            ..color = blockColors[color].withValues(alpha: 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      } else {
        canvas.drawLine(
          rect.topLeft + const Offset(2, 2),
          rect.topRight + const Offset(-2, 2),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..strokeWidth = 1.3,
        );
        if (star) {
          final text = TextPainter(
            text: TextSpan(
              text: '★',
              style: TextStyle(
                color: Colors.white,
                fontSize: cell * 0.72,
                shadows: const [Shadow(blurRadius: 2)],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(
            canvas,
            rect.center - Offset(text.width / 2, text.height / 2),
          );
        }
      }
    }

    for (var r = 0; r < GameEngine.height; r++) {
      for (var c = 0; c < GameEngine.width; c++) {
        final block = game.board[r][c];
        if (block != null) drawCell(c, r, block.color, star: block.star);
      }
    }
    if (!game.over && !game.won && (!resolving || bomb)) {
      final ghost = game.ghostY;
      if (ghost != game.y) {
        for (var r = 0; r < game.piece.length; r++) {
          for (var c = 0; c < game.piece[r].length; c++) {
            if (game.piece[r][c] == 1) {
              drawCell(game.x + c, ghost + r, game.color, ghost: true);
            }
          }
        }
      }
      for (var r = 0; r < game.piece.length; r++) {
        for (var c = 0; c < game.piece[r].length; c++) {
          if (game.piece[r][c] == 1) {
            drawCell(
              game.x + c,
              game.y + r,
              game.color,
              star: c == game.starX && r == game.starY,
            );
          }
        }
      }
    }
    if (resolving) {
      final rows = bomb ? [21, 22, 23] : game.clearingRows;
      for (final r in rows) {
        final rect = Rect.fromLTWH(0, r * cell, size.width, cell);
        canvas.drawRect(
          rect,
          Paint()
            ..color = (bomb ? Colors.orangeAccent : Colors.white).withValues(
              alpha: 0.25 + sin(effect * pi).abs() * 0.65,
            ),
        );
        final cx = effect * size.width;
        canvas.drawRect(
          Rect.fromLTWH(cx - 10, r * cell, 20, cell),
          Paint()..color = Colors.white.withValues(alpha: 0.8 * (1 - effect)),
        );
        for (var i = 0; i < 8; i++) {
          canvas.drawCircle(
            Offset(
              size.width * (i + 0.5) / 8,
              (r + 0.5) * cell - sin(i.toDouble()) * effect * cell * 1.7,
            ),
            (1 - effect) * cell * 0.14,
            Paint()..color = accent.withValues(alpha: 1 - effect),
          );
        }
      }
    }
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => true;
}
