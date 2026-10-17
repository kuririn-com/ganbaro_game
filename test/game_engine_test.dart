import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ganbaro_game/game_engine.dart';

void verticalI(GameEngine g, {int x = 11}) {
  g.piece = [
    [1],
    [1],
    [1],
    [1],
  ];
  g.color = 0;
  g.x = x;
  g.y = 0;
  g.starX = -1;
  g.starY = -1;
}

void setBottomRows(GameEngine g, int count) {
  g.board = List.generate(
    GameEngine.height,
    (_) => List.filled(GameEngine.width, null),
  );
  for (var r = GameEngine.height - count; r < GameEngine.height; r++) {
    for (var c = 0; c < 11; c++) {
      g.board[r][c] = const Cell(1);
    }
  }
  verticalI(g);
}

void main() {
  test('queue preview becomes the next spawned piece', () {
    final g = GameEngine(mode: GameMode.normal, random: Random(8));
    final preview = List<int>.from(g.next);
    g.drop();
    g.lock();
    g.resolve();
    expect(g.color, preview[0]);
    expect(g.next.take(2), preview.skip(1));
    expect(g.next.length, 3);
  });

  test('ghost finds the last legal position on a nonempty board', () {
    final g = GameEngine(mode: GameMode.normal);
    verticalI(g, x: 4);
    g.board[20][4] = const Cell(2);
    expect(g.ghostY, 16);
    expect(g.collides(g.x, g.ghostY, g.piece), false);
    expect(g.collides(g.x, g.ghostY + 1, g.piece), true);
    g.drop();
    expect(g.y, 16);
  });

  test('four-line clear animates before collapse and scores once', () {
    final g = GameEngine(mode: GameMode.normal);
    setBottomRows(g, 4);
    g.board[20][0] = const Cell(1, star: true);
    g.drop();
    g.lock();
    expect(g.clearingRows, [20, 21, 22, 23]);
    expect(g.score, 0);
    expect(g.move(-1), false);
    g.resolve();
    expect(g.lines, 4);
    expect(g.fourLines, 1);
    expect(g.score, 1600);
    expect(g.bombs, 1);
    expect(g.board.expand((r) => r).every((c) => c == null), true);
  });

  test('consecutive clears add combo bonus; a miss resets the chain', () {
    final g = GameEngine(mode: GameMode.normal);
    for (var i = 0; i < 3; i++) {
      setBottomRows(g, 4);
      g.drop();
      g.lock();
      g.resolve();
    }
    expect(g.combo, 3);
    expect(g.maxCombo, 3);
    expect(g.score, 1600 + 1650 + 1700);
    verticalI(g);
    g.drop();
    g.lock();
    g.resolve();
    expect(g.combo, 0);
    expect(g.maxCombo, 3);
  });

  test('mission completion is based on actual cleared lines', () {
    final g = GameEngine(
      mode: GameMode.mission,
      mission: missions[0],
      initialBombs: 1,
    );
    g.useBomb();
    expect(g.lines, 0);
    expect(g.won, false);
    for (var i = 0; i < 3; i++) {
      setBottomRows(g, 4);
      g.drop();
      g.lock();
      g.resolve();
    }
    expect(g.won, true);
    final x = g.x;
    expect(g.move(-1), false);
    expect(g.x, x);
  });

  test('combo and four-line missions complete on their own metrics', () {
    final four = GameEngine(mode: GameMode.mission, mission: missions[2]);
    setBottomRows(four, 4);
    four.drop();
    four.lock();
    four.resolve();
    expect(four.won, true);
    final combo = GameEngine(mode: GameMode.mission, mission: missions[3]);
    for (var i = 0; i < 3; i++) {
      setBottomRows(combo, 1);
      combo.drop();
      combo.lock();
      combo.resolve();
    }
    expect(combo.won, true);
  });

  test('bomb awards points, updates level, and does not count as lines', () {
    final g = GameEngine(mode: GameMode.level, initialBombs: 1);
    expect(g.useBomb(), true);
    expect(g.score, 1500);
    expect(g.level, 2);
    expect(g.bombs, 0);
    expect(g.lines, 0);
    expect(g.useBomb(), false);
    expect(g.board.length, GameEngine.height);
  });

  test('bomb never leaves the falling piece overlapping settled blocks', () {
    final g = GameEngine(mode: GameMode.normal, initialBombs: 1);
    g.board = List.generate(
      24,
      (_) => List<Cell?>.generate(12, (_) => const Cell(1)),
    );
    verticalI(g);
    g.y = 20;
    for (var r = 20; r < 24; r++) {
      g.board[r][11] = null;
    }
    expect(g.collides(g.x, g.y, g.piece), false);
    expect(g.useBomb(), true);
    expect(g.collides(g.x, g.y, g.piece), false);
    expect(g.board.length, 24);
  });

  test('rotation keeps star attached and supports wall adjustment', () {
    final g = GameEngine(mode: GameMode.normal);
    verticalI(g);
    g.starX = 0;
    g.starY = 0;
    expect(g.rotate(), false); // At x=11 an I needs a three-cell shift.
    g.x = 10;
    expect(g.rotate(), true);
    expect(g.x, 8);
    expect(g.starX, 3);
    expect(g.starY, 0);
    expect(g.collides(g.x, g.y, g.piece), false);
  });

  test('blocked spawn ends game and blocks actions', () {
    final g = GameEngine(mode: GameMode.normal);
    g.board = List.generate(24, (_) => List.generate(12, (_) => const Cell(1)));
    g.spawn();
    expect(g.over, true);
    expect(g.rotate(), false);
    expect(g.move(1), false);
  });

  test(
    'many random turns preserve board dimensions and legal active pieces',
    () {
      final random = Random(9);
      for (var session = 0; session < 50; session++) {
        final g = GameEngine(
          mode: GameMode.level,
          initialBombs: 10,
          random: random,
        );
        for (var turn = 0; turn < 200 && !g.over; turn++) {
          for (var i = 0; i < random.nextInt(6); i++) {
            g.rotate();
          }
          for (var i = 0; i < random.nextInt(10); i++) {
            g.move(random.nextBool() ? 1 : -1);
          }
          g.drop();
          g.lock();
          g.resolve();
          expect(g.board.length, 24);
          expect(g.board.every((r) => r.length == 12), true);
          if (!g.over) expect(g.collides(g.x, g.y, g.piece), false);
        }
      }
    },
  );
}
