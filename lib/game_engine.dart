import 'dart:math';

enum GameMode { level, normal, mission }

class Cell {
  final int color;
  final bool star;
  const Cell(this.color, {this.star = false});
}

class Mission {
  final String title, description, metric;
  final int target;
  const Mission(this.title, this.description, this.metric, this.target);
}

const missions = <Mission>[
  Mission('はじめの10ライン', '合計10ラインを消そう', 'lines', 10),
  Mission('スコアチャレンジ', '5,000点を獲得しよう', 'score', 5000),
  Mission('4ラインの一撃', '一度に4ラインを消そう', 'four', 1),
  Mission('コンボをつなごう', '3回連続の配置でラインを消そう', 'combo', 3),
  Mission('ロングチャレンジ', '合計25ラインを消そう', 'lines', 25),
  Mission('スコアマスター', '15,000点を獲得しよう', 'score', 15000),
];

class GameEngine {
  static const width = 12, height = 24;
  static const shapes = <List<List<int>>>[
    [
      [1, 1, 1, 1],
    ],
    [
      [1, 1],
      [1, 1],
    ],
    [
      [0, 1, 0],
      [1, 1, 1],
    ],
    [
      [1, 0, 0],
      [1, 1, 1],
    ],
    [
      [0, 0, 1],
      [1, 1, 1],
    ],
    [
      [0, 1, 1],
      [1, 1, 0],
    ],
    [
      [1, 1, 0],
      [0, 1, 1],
    ],
  ];
  final GameMode mode;
  final Mission? mission;
  final Random random;
  List<List<Cell?>> board = List.generate(
    height,
    (_) => List.filled(width, null),
  );
  final List<int> next = [];
  List<List<int>> piece = [];
  List<int> clearingRows = [];
  int color = 0, x = 0, y = 0, starX = -1, starY = -1;
  int score = 0, level = 1, bombs = 0, lastStarScore = 0;
  int lines = 0, fourLines = 0, combo = 0, maxCombo = 0, bombsUsed = 0;
  int lastPoints = 0, lastCleared = 0;
  bool over = false, won = false;

  GameEngine({
    required this.mode,
    this.mission,
    int initialBombs = 0,
    Random? random,
  }) : random = random ?? Random(),
       bombs = initialBombs {
    assert(mode != GameMode.mission || mission != null);
    next.addAll(List.generate(3, (_) => this.random.nextInt(shapes.length)));
    spawn();
  }

  int get speedMs => mode == GameMode.level && level > 10
      ? max(110, 500 - (level - 10) * 10)
      : 500;
  static int targetScore(int lv) {
    var total = 0;
    for (var i = 1; i < lv; i++) {
      total += i == 1 ? 500 : i * 1000;
    }
    return total;
  }

  bool collides(int nx, int ny, List<List<int>> shape) {
    for (var r = 0; r < shape.length; r++) {
      for (var c = 0; c < shape[r].length; c++) {
        if (shape[r][c] == 0) continue;
        final bx = nx + c, by = ny + r;
        if (bx < 0 || bx >= width || by >= height) return true;
        if (by >= 0 && board[by][bx] != null) return true;
      }
    }
    return false;
  }

  int get ghostY {
    var dest = y;
    while (!collides(x, dest + 1, piece)) {
      dest++;
    }
    return dest;
  }

  void spawn() {
    color = next.removeAt(0);
    next.add(random.nextInt(shapes.length));
    piece = shapes[color].map((row) => List<int>.from(row)).toList();
    starX = -1;
    starY = -1;
    var star = false;
    if (mode == GameMode.level && level < 40) {
      final chance = level <= 10
          ? 10
          : level <= 20
          ? 7
          : level <= 30
          ? 4
          : 1;
      star = random.nextInt(100) < chance;
    } else if (mode != GameMode.level && score - lastStarScore >= 1000) {
      star = true;
      lastStarScore = (score ~/ 1000) * 1000;
    }
    if (star) {
      final cells = <Point<int>>[];
      for (var r = 0; r < piece.length; r++) {
        for (var c = 0; c < piece[r].length; c++) {
          if (piece[r][c] == 1) cells.add(Point(c, r));
        }
      }
      final chosen = cells[random.nextInt(cells.length)];
      starX = chosen.x;
      starY = chosen.y;
    }
    x = width ~/ 2 - piece[0].length ~/ 2;
    y = 0;
    over = collides(x, y, piece);
  }

  bool move(int dx) {
    if (over || won || clearingRows.isNotEmpty || collides(x + dx, y, piece)) {
      return false;
    }
    x += dx;
    return true;
  }

  bool rotate() {
    if (over || won || clearingRows.isNotEmpty) return false;
    final rotated = List.generate(
      piece[0].length,
      (r) => List.generate(piece.length, (c) => piece[piece.length - 1 - c][r]),
    );
    for (final offset in [0, -1, 1, -2, 2]) {
      if (!collides(x + offset, y, rotated)) {
        final newStarX = starY < 0 ? -1 : piece.length - 1 - starY;
        final newStarY = starX;
        piece = rotated;
        x += offset;
        starX = newStarX;
        starY = newStarY;
        return true;
      }
    }
    return false;
  }

  // Returns true when the piece needs to be locked by the UI.
  bool step() {
    if (over || won || clearingRows.isNotEmpty) return false;
    if (collides(x, y + 1, piece)) return true;
    y++;
    return false;
  }

  void drop() {
    if (!over && !won) y = ghostY;
  }

  void lock() {
    if (over || won || clearingRows.isNotEmpty) return;
    for (var r = 0; r < piece.length; r++) {
      for (var c = 0; c < piece[r].length; c++) {
        if (piece[r][c] == 0) continue;
        if (y + r < 0) {
          over = true;
          continue;
        }
        board[y + r][x + c] = Cell(color, star: c == starX && r == starY);
      }
    }
    clearingRows = [
      for (var r = 0; r < height; r++)
        if (board[r].every((cell) => cell != null)) r,
    ];
  }

  void resolve() {
    lastCleared = clearingRows.length;
    lastPoints = 0;
    if (lastCleared > 0) {
      final earned = clearingRows.any(
        (r) => board[r].any((cell) => cell?.star ?? false),
      );
      if (earned) bombs++;
      combo++;
      maxCombo = max(maxCombo, combo);
      lines += lastCleared;
      if (lastCleared == 4) fourLines++;
      final base = [0, 100, 400, 900, 1600][min(4, lastCleared)];
      lastPoints =
          (base + max(0, combo - 1) * 50) *
          (mode == GameMode.level ? level : 1);
      score += lastPoints;
      final kept = [
        for (var r = 0; r < height; r++)
          if (!clearingRows.contains(r)) board[r],
      ];
      board = [
        ...List.generate(lastCleared, (_) => List<Cell?>.filled(width, null)),
        ...kept,
      ];
    } else {
      combo = 0;
    }
    clearingRows = [];
    _checkProgress();
    if (!over && !won) spawn();
  }

  bool useBomb() {
    if (bombs <= 0 || over || won || clearingRows.isNotEmpty) return false;
    bombs--;
    bombsUsed++;
    board = [
      ...List.generate(3, (_) => List<Cell?>.filled(width, null)),
      ...board.take(height - 3),
    ];
    // Scroll the falling piece with the board if the bomb would overlap it.
    // Prefer its current column; search legal positions before changing orientation.
    if (collides(x, y, piece)) {
      var found = false;
      for (
        var row = min(y + 3, height - piece.length);
        row >= 0 && !found;
        row--
      ) {
        if (!collides(x, row, piece)) {
          y = row;
          found = true;
        }
      }
      if (!found) {
        for (var row = height - piece.length; row >= 0 && !found; row--) {
          for (var col = 0; col <= width - piece[0].length; col++) {
            if (!collides(col, row, piece)) {
              x = col;
              y = row;
              found = true;
              break;
            }
          }
        }
      }
      if (!found) {
        // Only a vertical I can be taller than the three empty top rows.
        piece = shapes[color].map((row) => List<int>.from(row)).toList();
        if (starX >= 0) {
          starX = 0;
          starY = 0;
        }
        x = min(x, width - piece[0].length);
        y = 0;
      }
    }
    lastPoints = 1500 * (mode == GameMode.level ? level : 1);
    score += lastPoints;
    lastCleared = 0;
    _checkProgress();
    return true;
  }

  int get missionProgress {
    switch (mission?.metric) {
      case 'lines':
        return lines;
      case 'score':
        return score;
      case 'four':
        return fourLines;
      case 'combo':
        return maxCombo;
      default:
        return 0;
    }
  }

  void _checkProgress() {
    if (mode == GameMode.level) {
      while (level < 50 && score >= targetScore(level + 1)) {
        level++;
      }
    }
    if (mode == GameMode.mission && missionProgress >= mission!.target) {
      won = true;
    }
  }
}
