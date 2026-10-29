import 'dart:math';

import 'package:aurora_shared/games/arcade5/defs.dart';
import 'package:aurora_shared/games/arcade5/nonogram.dart';
import 'package:aurora_shared/games/arcade5/ricochet.dart';
import 'package:aurora_shared/games/arcade5/sokoban.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int n, Map<String, dynamic> opts, {int seed = 7, bool bots = false}) => GameSetup(
      players: n,
      options: opts,
      names: [for (var i = 0; i < n; i++) 'P$i'],
      bots: List.filled(n, bots),
      hostSeat: 0,
      rng: Random(seed),
    );

void main() {
  group('弹射机器人 (ricochet)', () {
    test('sliding stops on walls, board boundaries, and other robots', () {
      final (walls, _) = RicochetSolver.buildBoard(10, Random(1));
      // Clear interior walls for a controlled test on row 0
      for (var i = 0; i < 100; i++) {
        walls[i] = 0;
      }
      for (var i = 0; i < 10; i++) {
        RicochetSolver.addWall(walls, 10, 0, i, 0);
        RicochetSolver.addWall(walls, 10, 9, i, 2);
        RicochetSolver.addWall(walls, 10, i, 0, 3);
        RicochetSolver.addWall(walls, 10, i, 9, 1);
      }
      // Add vertical wall to the right of (0, 4)
      RicochetSolver.addWall(walls, 10, 0, 4, 1);

      final robots = [0, 7, 50, 99];
      // Slide robot 0 right (dir=1): stops at (0, 4) due to wall
      expect(RicochetSolver.slide(walls, 10, robots, 0, 1), 4);
      // Slide robot 1 left (dir=3) from (0, 7): stops at (0, 5) due to wall between (0,4) and (0,5)
      expect(RicochetSolver.slide(walls, 10, robots, 1, 3), 5);
      // Put robot 2 at (0, 2); slide robot 0 right -> stops at (0, 1) due to robot 2
      robots[2] = 2;
      expect(RicochetSolver.slide(walls, 10, robots, 0, 1), 1);
    });

    test('step-by-step slide, undo, reset, fewest-moves +2/+1 scoring, and mainRobots update', () {
      final e = RicochetGame(_setup(3, {'rounds': 3, 'size': 10}))..host = SimHost();
      e.start();
      expect(e.round, 1);
      expect(e.currentSolution.length, inInclusiveRange(1, 6));

      // Construct a controlled scenario on the current board:
      // Clear interior walls on row 5 so robot 0 can slide right to (5,9) in 1 move,
      // or go down/up/right in 3 moves.
      for (var i = 0; i < e.walls.length; i++) {
        e.walls[i] = 0;
      }
      for (var i = 0; i < 10; i++) {
        RicochetSolver.addWall(e.walls, 10, 0, i, 0);
        RicochetSolver.addWall(e.walls, 10, 9, i, 2);
        RicochetSolver.addWall(e.walls, 10, i, 0, 3);
        RicochetSolver.addWall(e.walls, 10, i, 9, 1);
      }
      e.mainRobots = [50, 0, 9, 90]; // robot 0 at (5,0), others at corners (0,0), (0,9), (9,0)
      e.targetRobot = 0;
      e.targetCell = 59; // (5,9)
      for (var s = 0; s < 3; s++) {
        e.ps[s].resetForRound(e.mainRobots);
      }

      // Seat 0 slides robot 3 (at 90) right to 99, undoes, resets, then slides robot 0 right (1 move)
      e.handle(0, {'type': 'slide', 'robot': 3, 'dir': 1});
      expect(e.playerRobots[0][3], 99);
      e.handle(0, {'type': 'undo'});
      expect(e.playerRobots[0][3], 90);
      e.handle(0, {'type': 'slide', 'robot': 3, 'dir': 1});
      e.handle(0, {'type': 'reset'});
      expect(e.playerRobots[0], [50, 0, 9, 90]);

      // Seat 0 solves in 1 move -> locks
      e.handle(0, {'type': 'slide', 'robot': 0, 'dir': 1});
      expect(e.ps[0].status, 'solved');
      expect(e.playerMoves[0].length, 1);

      // Seat 1 solves in 2 moves via 'solve' (slide robot 3 right, then robot 0 right)
      e.handle(1, {
        'type': 'solve',
        'moves': [
          {'robot': 3, 'dir': 1},
          {'robot': 0, 'dir': 1},
        ],
      });
      expect(e.ps[1].status, 'solved');
      expect(e.playerMoves[1].length, 2);

      // Seat 2 passes -> triggers round end!
      // Seat 0 had fewest moves (1) -> +2 pts; Seat 1 solved with 2 moves -> +1 pt; Seat 2 -> 0 pts.
      // Main board robots update to Seat 0's winning positions [59, 0, 9, 90], and round 2 begins!
      e.handle(2, {'type': 'pass'});
      expect(e.scores, [2, 1, 0]);
      expect(e.mainRobots, [59, 0, 9, 90]);
      expect(e.round, 2);
    });
  });

  group('数织竞速 (nonogram)', () {
    test('computeLineClue and computeClues accuracy', () {
      expect(NonogramSolver.computeLineClue([0, 0, 0, 0, 0]), [0]);
      expect(NonogramSolver.computeLineClue([2, 2, 0, 2, 0]), [0]);
      expect(NonogramSolver.computeLineClue([1, 1, 0, 1, 0]), [2, 1]);
      expect(NonogramSolver.computeLineClue([1, 1, 2, 1, 1]), [2, 2]);
      expect(NonogramSolver.computeLineClue([1, 1, 1, 1, 1]), [5]);
    });

    test('cell set, toggle, X mark ignoring, and speed scoring', () {
      final e = NonogramGame(_setup(3, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();
      expect(e.size, 5);
      expect(e.rowClues.length, 5);
      expect(e.colClues.length, 5);

      // Toggle cell (0, 0): 0 -> 1 -> 2 -> 0
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      expect(e.boards[0][0], 1);
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      expect(e.boards[0][0], 2);
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      expect(e.boards[0][0], 0);

      // Seat 0 fills the exact target pattern (putting 2=X on empty cells)
      for (var i = 0; i < 25; i++) {
        final v = e.targetPattern[i] == 1 ? 1 : 2;
        if (e.ps[0].status == 'play') {
          e.handle(0, {'type': 'set', 'r': i ~/ 5, 'c': i % 5, 'val': v});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      // Seat 1 also solves -> 2nd place gets 8 pts
      for (var i = 0; i < 25; i++) {
        if (e.targetPattern[i] == 1 && e.ps[1].status == 'play') {
          e.handle(1, {'type': 'set', 'r': i ~/ 5, 'c': i % 5, 'val': 1});
        }
      }
      expect(e.ps[1].status, 'solved');
      expect(e.scores[1], 8);

      // Seat 2 passes -> advances to round 2
      e.handle(2, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('推箱子竞速 (sokoban)', () {
    test('all 18 levels in sokobanLevels have verified valid solutions', () {
      expect(sokobanLevels.length, greaterThanOrEqualTo(16));
      for (final lvl in sokobanLevels) {
        expect(
          SokobanSolver.verifyLevel(lvl),
          isTrue,
          reason: 'Level ${lvl.id} (${lvl.name}) failed solution verification',
        );
      }
    });

    test('walking, box pushing, blocked push rejection, undo, reset, and level completion', () {
      final e = SokobanGame(_setup(2, {'rounds': 3}))..host = SimHost();
      e.start();
      // Force level 1 ('初出茅庐') on round 1
      e.matchLevels[0] = sokobanLevels[0];
      e.currentLevel = sokobanLevels[0];
      e.currentWarehouse = SokobanSolver.parse(sokobanLevels[0]);
      for (final p in e.ps) {
        p.resetForRound(e.currentWarehouse);
      }

      // Level 1 solution is [3, 3, 1, 0]
      // First move 3 (left) pushes box from (3,3) to (3,2)
      e.handle(0, {'type': 'move', 'dir': 3});
      expect(e.ps[0].steps, 1);
      expect(e.ps[0].pushes, 1);

      // Undo restores initial state
      e.handle(0, {'type': 'undo'});
      expect(e.ps[0].steps, 0);
      expect(e.ps[0].pushes, 0);

      // Replay full solution [3, 3, 1, 0] for seat 0
      for (final d in sokobanLevels[0].solution) {
        e.handle(0, {'type': 'move', 'dir': d});
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 12); // 10 base + 2 par efficiency bonus

      // Seat 1 passes -> advances to round 2
      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade5Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade5Games, n: 30), 0);
    print('arcade5 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
