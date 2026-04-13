import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb) {
    // 広告初期化の前に、トラッキング許可のポップアップを表示する
    await AppTrackingTransparency.requestTrackingAuthorization();
    await MobileAds.instance.initialize();
  }
  
  runApp(const BlockPuzzleApp());
}

class BlockPuzzleApp extends StatelessWidget {
  const BlockPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Block Pop',
      theme: ThemeData.dark(),
      home: const TitleScreen(),
    );
  }
}

// ==========================================
// トップ画面
// ==========================================
enum GameMode { level, normal }

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  int _bestLevel = 0;
  int _bestNormal = 0;
  int _initialBombs = 0; // トップ画面で獲得した初期ボム数

  RewardedAd? _rewardedAd;
  final String rewardedAdUnitId = 'ca-app-pub-9003840415284448/5493879760';

  @override
  void initState() {
    super.initState();
    _loadAllBestScores();
    _loadRewardedAd(); // トップ画面でリワード広告を準備
  }

  void _loadRewardedAd() {
    if (kIsWeb) return;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) => _rewardedAd = null,
      ),
    );
  }

  void _showRewardedAd() {
    if (_rewardedAd == null) return;
    
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd(); // 次のために再読み込み
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadRewardedAd();
      },
    );
    
    _rewardedAd!.show(onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      // 広告を見終わったらボムを3つ追加！
      setState(() {
        _initialBombs += 3;
      });
    });
  }

  Future<void> _loadAllBestScores() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bestLevel = prefs.getInt('best_score_level') ?? 0;
      _bestNormal = prefs.getInt('best_score_normal') ?? 0;
    });
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.grid_view, size: 80, color: Colors.orange),
            const SizedBox(height: 10),
            const Text('Block Pop', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // ベストスコア表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  Text('Level Mode Best: $_bestLevel', style: const TextStyle(fontSize: 16, color: Colors.orangeAccent)),
                  const SizedBox(height: 5),
                  Text('Normal Mode Best: $_bestNormal', style: const TextStyle(fontSize: 16, color: Colors.lightBlueAccent)),
                ],
              ),
            ),
            
            const SizedBox(height: 30),

            // ==== ボム追加ボタン（動画広告） ====
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.yellow, width: 2),
                borderRadius: BorderRadius.circular(15),
                color: Colors.yellow.withOpacity(0.1),
              ),
              child: Column(
                children: [
                  Text('スタートダッシュ持ち込み: $_initialBombs 個', 
                      style: const TextStyle(fontSize: 18, color: Colors.yellow, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _rewardedAd != null ? _showRewardedAd : null,
                    icon: const Icon(Icons.live_tv, color: Colors.white),
                    label: const Text('動画を見てボム追加(+3)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            _modeButton(context, 'レベルアップモード', GameMode.level, Colors.orange),
            const SizedBox(height: 20),
            _modeButton(context, '通常モード', GameMode.normal, Colors.blueAccent),
          ],
        ),
      ),
    );
  }

  Widget _modeButton(BuildContext context, String text, GameMode mode, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => GameBoard(mode: mode, initialBombs: _initialBombs),
        )).then((_) {
          // ゲームから戻ったら、持ち込みボムは0にリセット＆スコア更新
          setState(() => _initialBombs = 0);
          _loadAllBestScores();
        });
      },
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

// ==========================================
// ゲーム画面
// ==========================================
class BlockData {
  final Color color;
  final bool isBomb;
  BlockData(this.color, {this.isBomb = false});
}

class GameBoard extends StatefulWidget {
  final GameMode mode;
  final int initialBombs; 

  const GameBoard({super.key, required this.mode, this.initialBombs = 0});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  static const int rowLength = 12;
  static const int colLength = 24;

  List<List<BlockData?>> board = List.generate(colLength, (i) => List.generate(rowLength, (j) => null));
  final List<List<List<int>>> shapes = [
    [[1, 1, 1, 1]], [[1, 1], [1, 1]], [[0, 1, 0], [1, 1, 1]], 
    [[1, 0, 0], [1, 1, 1]], [[0, 0, 1], [1, 1, 1]], 
    [[0, 1, 1], [1, 1, 0]], [[1, 1, 0], [0, 1, 1]],
  ];
  final List<Color> shapeColors = [
    Colors.cyan, Colors.yellow, Colors.purple, Colors.orange, Colors.blue, Colors.green, Colors.pink
  ];

  List<List<int>> currentPiece = [];
  Color currentPieceColor = Colors.white;
  int bombLocalX = -1, bombLocalY = -1;
  int currentPosX = 0, currentPosY = 0;
  Timer? gameTimer;
  bool isGameOver = false, isExploding = false;
  int score = 0, level = 1, bombCount = 0, lastStarScore = 0, bestScore = 0;
  bool _isFirstGame = true; 

  final AudioPlayer _fallPlayer = AudioPlayer(); 
  final AudioPlayer _placePlayer = AudioPlayer();
  final AudioPlayer _clearPlayer = AudioPlayer();

  String get _bestScoreKey => widget.mode == GameMode.level ? 'best_score_level' : 'best_score_normal';

  // インタースティシャル広告
  InterstitialAd? _interstitialAd;
  final String interstitialAdUnitId = 'ca-app-pub-9003840415284448/6721545961';

  @override
  void initState() {
    super.initState();
    _loadBestScore();
    _loadInterstitialAd();
    startGame();
  }

  void _loadInterstitialAd() {
    if (kIsWeb) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => _interstitialAd = null,
      ),
    );
  }

  Future<void> _loadBestScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bestScore = prefs.getInt(_bestScoreKey) ?? 0;
    });
  }

  Future<void> _updateScore(int points) async {
    setState(() {
      score += points;
      if (score > bestScore) {
        bestScore = score;
        _saveBestScore(bestScore);
      }
    });
  }

  Future<void> _saveBestScore(int newBest) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_bestScoreKey, newBest);
  }

  void _playFallSound() => _fallPlayer.play(AssetSource('audio/fall.mp3'));
  void _playPlaceSound() => _placePlayer.play(AssetSource('audio/place.mp3'));
  void _playClearSound() => _clearPlayer.play(AssetSource('audio/clear.mp3'));

  @override
  void dispose() {
    gameTimer?.cancel();
    _fallPlayer.dispose(); _placePlayer.dispose(); _clearPlayer.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }

  void startGame() {
    board = List.generate(colLength, (i) => List.generate(rowLength, (j) => null));
    isGameOver = false; isExploding = false; score = 0; level = 1; lastStarScore = 0;
    
    // 初回のみトップ画面から持ち込んだボムを適用。RESTART時は0になる。
    bombCount = _isFirstGame ? widget.initialBombs : 0;
    _isFirstGame = false;

    spawnPiece();
    updateTimer();
  }

  int getTargetScore(int targetLv) {
    int reqScore = 0;
    for (int i = 1; i < targetLv; i++) {
      if (i == 1) reqScore += 500;
      else reqScore += (i * 1000);
    }
    return reqScore;
  }

  void updateTimer() {
    gameTimer?.cancel();
    int speed = 500;
    if (widget.mode == GameMode.level && level > 10) {
      speed = 500 - ((level - 10) * 10);
      if (speed < 110) speed = 110;
    }
    gameTimer = Timer.periodic(Duration(milliseconds: speed), (timer) {
      if (!isExploding) gameLoop();
    });
  }

  void spawnPiece() {
    Random rand = Random();
    int index = rand.nextInt(shapes.length);
    currentPiece = shapes[index];
    currentPieceColor = shapeColors[index];
    bombLocalX = -1; bombLocalY = -1;

    bool isBomb = false;
    if (widget.mode == GameMode.level) {
      if (level < 40) {
        int chance = 0;
        if (level <= 10) chance = 10;
        else if (level <= 20) chance = 7;
        else if (level <= 30) chance = 4;
        else if (level < 40) chance = 1;
        if (rand.nextInt(100) < chance) isBomb = true;
      }
    } else {
      if (score - lastStarScore >= 1000) {
        isBomb = true;
        lastStarScore = (score ~/ 1000) * 1000; 
      }
    }
    
    if (isBomb) {
      List<List<int>> ones = [];
      for (int r = 0; r < currentPiece.length; r++) {
        for (int c = 0; c < currentPiece[r].length; c++) {
          if (currentPiece[r][c] == 1) ones.add([c, r]);
        }
      }
      var chosen = ones[rand.nextInt(ones.length)];
      bombLocalX = chosen[0]; bombLocalY = chosen[1];
    }

    currentPosX = (rowLength ~/ 2) - (currentPiece[0].length ~/ 2);
    currentPosY = 0;
    if (checkCollision(currentPosX, currentPosY, currentPiece)) {
      isGameOver = true;
      gameTimer?.cancel();
    }
  }

  void gameLoop() {
    setState(() {
      if (!checkCollision(currentPosX, currentPosY + 1, currentPiece)) {
        currentPosY++;
        _playFallSound();
      } else {
        placePiece();
        clearLines();
        if (!isGameOver) spawnPiece();
      }
    });
  }

  bool checkCollision(int x, int y, List<List<int>> piece) {
    for (int r = 0; r < piece.length; r++) {
      for (int c = 0; c < piece[r].length; c++) {
        if (piece[r][c] == 1) {
          int nX = x + c, nY = y + r;
          if (nX < 0 || nX >= rowLength || nY >= colLength) return true;
          if (nY >= 0 && board[nY][nX] != null) return true;
        }
      }
    }
    return false;
  }

  void placePiece() {
    _playPlaceSound();
    for (int r = 0; r < currentPiece.length; r++) {
      for (int c = 0; c < currentPiece[r].length; c++) {
        if (currentPiece[r][c] == 1) {
          int fixY = currentPosY + r, fixX = currentPosX + c;
          bool isStar = (c == bombLocalX && r == bombLocalY);
          if (fixY >= 0) {
            board[fixY][fixX] = BlockData(currentPieceColor, isBomb: isStar);
          } else {
            isGameOver = true;
          }
        }
      }
    }
  }

  void clearLines() {
    int linesCleared = 0;
    bool earnedBomb = false;
    for (int row = colLength - 1; row >= 0; row--) {
      bool full = true, hasStar = false;
      for (int col = 0; col < rowLength; col++) {
        if (board[row][col] == null) { full = false; break; }
        if (board[row][col]!.isBomb) hasStar = true;
      }
      if (full) {
        if (hasStar) earnedBomb = true;
        board.removeAt(row);
        board.insert(0, List.generate(rowLength, (index) => null));
        linesCleared++; row++;
      }
    }

    if (linesCleared > 0) {
      _playClearSound();
      if (earnedBomb) setState(() => bombCount++);
      
      int base = 0;
      switch (linesCleared) {
        case 1: base = 100; break;
        case 2: base = 400; break; 
        case 3: base = 900; break; 
        case 4: base = 1600; break;
      }
      
      int multiplier = widget.mode == GameMode.level ? level : 1;
      _updateScore(base * multiplier);

      if (widget.mode == GameMode.level) {
        setState(() {
          while (level < 50 && score >= getTargetScore(level + 1)) level++;
        });
        updateTimer();
      }
    }
  }

  void useBombItem() async {
    if (bombCount > 0 && !isGameOver && !isExploding) {
      _playClearSound();
      setState(() { bombCount--; isExploding = true; });
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        setState(() { isExploding = false; });
        for (int i = 0; i < 3; i++) {
          board.removeLast();
          board.insert(0, List.generate(rowLength, (index) => null));
        }
        int bombPoints = 1500 * (widget.mode == GameMode.level ? level : 1);
        _updateScore(bombPoints);
      }
    }
  }

  void moveLeft() { if (!checkCollision(currentPosX - 1, currentPosY, currentPiece) && !isExploding) setState(() { currentPosX--; _playFallSound(); }); }
  void moveRight() { if (!checkCollision(currentPosX + 1, currentPosY, currentPiece) && !isExploding) setState(() { currentPosX++; _playFallSound(); }); }
  void rotatePiece() {
    if (isExploding) return;
    List<List<int>> next = List.generate(currentPiece[0].length, (i) => List.generate(currentPiece.length, (j) => 0));
    int nBX = -1, nBY = -1;
    for (int r = 0; r < currentPiece.length; r++) {
      for (int c = 0; c < currentPiece[r].length; c++) {
        next[c][currentPiece.length - 1 - r] = currentPiece[r][c];
        if (c == bombLocalX && r == bombLocalY) { nBX = currentPiece.length - 1 - r; nBY = c; }
      }
    }
    if (!checkCollision(currentPosX, currentPosY, next)) setState(() { currentPiece = next; bombLocalX = nBX; bombLocalY = nBY; _playFallSound(); });
  }
  void hardDrop() { if (!isExploding) { int dist = 0; while (!checkCollision(currentPosX, currentPosY + dist + 1, currentPiece)) dist++; setState(() { currentPosY += dist; placePiece(); clearLines(); if (!isGameOver) spawnPiece(); }); } }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  
                  // ▼▼ レベル表示をここに追加しました ▼▼
                  Column(children: [
                    Text(widget.mode == GameMode.level ? 'LEVEL: $level / 50' : 'NORMAL MODE', style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('BEST: $bestScore', style: const TextStyle(color: Colors.yellow, fontSize: 12)),
                    Text('SCORE: $score', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ]),
                  
                  // ゲーム中のボム使用ボタン
                  ElevatedButton.icon(
                    onPressed: bombCount > 0 && !isGameOver && !isExploding ? useBombItem : null,
                    icon: const Icon(Icons.bolt, color: Colors.yellow),
                    label: Text('x$bombCount'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[900],
                      disabledBackgroundColor: Colors.grey[900]
                    ),
                  )
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: rowLength / colLength,
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.white24, width: 2)),
                    child: Stack(children: [
                      GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rowLength * colLength,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: rowLength),
                        itemBuilder: (context, index) {
                          int x = index % rowLength, y = index ~/ rowLength;
                          if (isExploding && y >= colLength - 3) return _buildPixel(Colors.redAccent, isExp: true);
                          bool isCur = false, isStar = false;
                          for (int r = 0; r < currentPiece.length; r++) {
                            for (int c = 0; c < currentPiece[r].length; c++) {
                              if (currentPiece[r][c] == 1 && x == currentPosX + c && y == currentPosY + r) {
                                isCur = true; if (c == bombLocalX && r == bombLocalY) isStar = true; break;
                              }
                            }
                            if (isCur) break;
                          }
                          Color color = isCur ? currentPieceColor : (board[y][x]?.color ?? Colors.grey[850]!);
                          return _buildPixel(color, isStar: isStar || (board[y][x]?.isBomb ?? false));
                        },
                      ),
                      if (isGameOver) Container(
                        color: Colors.black87,
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Text('GAME OVER', style: TextStyle(color: Colors.red, fontSize: 36, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Text('SCORE: $score', style: const TextStyle(fontSize: 24)),
                          Text('BEST SCORE: $bestScore', style: const TextStyle(color: Colors.yellow)),
                          const SizedBox(height: 20),
                          
                          ElevatedButton(
                            onPressed: () {
                              if (_interstitialAd != null) {
                                _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
                                  onAdDismissedFullScreenContent: (ad) {
                                    ad.dispose();
                                    _loadInterstitialAd();
                                    setState(() => startGame());
                                  },
                                  onAdFailedToShowFullScreenContent: (ad, error) {
                                    ad.dispose();
                                    setState(() => startGame());
                                  },
                                );
                                _interstitialAd!.show();
                              } else {
                                setState(() => startGame());
                              }
                            },
                            child: const Text('RESTART', style: TextStyle(fontSize: 20))
                          )
                        ])),
                      )
                    ]),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                IconButton(onPressed: moveLeft, icon: const Icon(Icons.arrow_left, size: 60)),
                IconButton(onPressed: rotatePiece, icon: const Icon(Icons.rotate_right, size: 60)),
                IconButton(onPressed: hardDrop, icon: const Icon(Icons.arrow_drop_down_circle, size: 60)),
                IconButton(onPressed: moveRight, icon: const Icon(Icons.arrow_right, size: 60)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPixel(Color color, {bool isStar = false, bool isExp = false}) {
    return Container(
      decoration: BoxDecoration(color: color, border: Border.all(color: Colors.black26, width: 0.5)),
      child: isExp ? const Icon(Icons.local_fire_department, color: Colors.yellow, size: 16)
                   : (isStar ? const Icon(Icons.star, color: Colors.yellowAccent, size: 16) : null),
    );
  }
}