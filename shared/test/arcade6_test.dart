import 'dart:math';

import 'package:aurora_shared/games/arcade6/akari.dart';
import 'package:aurora_shared/games/arcade6/defs.dart';
import 'package:aurora_shared/games/arcade6/hashi.dart';
import 'package:aurora_shared/games/arcade6/klotski.dart';
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
  group('华容道竞速 (klotski)', () {
    test('all 16 levels in klotskiLevels have verified valid layouts and solutions', () {
      expect(klotskiLevels.length, greaterThanOrEqualTo(12));
      final easyCount = klotskiLevels.where((l) => l.difficulty == 'easy').length;
      final classicCount = klotskiLevels.where((l) => l.difficulty == 'classic').length;
      expect(easyCount, greaterThanOrEqualTo(6));
      expect(classicCount, greaterThanOrEqualTo(6));

      for (final lvl in klotskiLevels) {
        expect(
          KlotskiSolver.verifyLevel(lvl),
          isTrue,
          reason: 'Level ${lvl.id} (${lvl.name}) failed verification',
        );
      }
    });

    test('piece sliding, collision rejection, undo, reset, and completion scoring', () {
      final e = KlotskiGame(_setup(3, {'difficulty': 'easy', 'rounds': 3}))..host = SimHost();
      e.start();
      // Force level 1 ('初出茅庐', 8 steps) on round 1
      e.matchLevels[0] = klotskiLevels[0];
      e.currentLevel = klotskiLevels[0];
      for (final p in e.ps) {
        p.resetForRound(klotskiLevels[0].pieces);
      }

      final firstMove = klotskiLevels[0].solution.first;
      e.handle(0, {'type': 'slide', 'piece': firstMove.piece, 'dir': firstMove.dir});
      expect(e.ps[0].steps, 1);

      // Undo restores initial state
      e.handle(0, {'type': 'undo'});
      expect(e.ps[0].steps, 0);

      // Slide again then reset
      e.handle(0, {'type': 'slide', 'piece': firstMove.piece, 'dir': firstMove.dir});
      e.handle(0, {'type': 'reset'});
      expect(e.ps[0].steps, 0);

      // Replay full solution for seat 0 -> 1st place (10) + par bonus (2) = 12 pts
      for (final m in klotskiLevels[0].solution) {
        e.handle(0, {'type': 'slide', 'piece': m.piece, 'dir': m.dir});
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 12);

      // Seat 1 also solves -> 2nd place (8) + par bonus (2) = 10 pts
      for (final m in klotskiLevels[0].solution) {
        e.handle(1, {'type': 'slide', 'piece': m.piece, 'dir': m.dir});
      }
      expect(e.ps[1].status, 'solved');
      expect(e.scores[1], 10);

      // Seat 2 passes -> advances to round 2
      e.handle(2, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('数回连桥竞速 (hashi)', () {
    test('puzzle generator produces valid connected non-crossing puzzles for 6x6 and 8x8', () {
      final rng = Random(42);
      for (final size in [6, 8]) {
        for (var i = 0; i < 10; i++) {
          final puz = HashiSolver.generatePuzzle(size, rng);
          expect(puz.islands.length, greaterThanOrEqualTo(6));
          expect(HashiSolver.isSolved(puz.islands, puz.solutionBridges), isTrue);
        }
      }
    });

    test('crossing detection, connectivity check, bridge cycling, and scoring', () {
      // 4 islands arranged in a cross where (0,1) horizontal and (2,3) vertical cross at (2,2)
      const crossIslands = [
        HashiIsland(id: 0, r: 2, c: 0, clue: 1),
        HashiIsland(id: 1, r: 2, c: 4, clue: 1),
        HashiIsland(id: 2, r: 0, c: 2, clue: 1),
        HashiIsland(id: 3, r: 4, c: 2, clue: 1),
      ];
      final crossBridges = {
        HashiSolver.pairKey(0, 1): 1,
        HashiSolver.pairKey(2, 3): 1,
      };
      expect(HashiSolver.crossingBridgeKeys(crossIslands, crossBridges).length, 2);
      expect(HashiSolver.isSolved(crossIslands, crossBridges), isFalse);

      final e = HashiGame(_setup(2, {'size': 6, 'rounds': 3}))..host = SimHost();
      e.start();
      final vis = HashiSolver.visiblePairs(e.currentPuzzle.islands).first;
      // Cycle bridge 0 -> 1 -> 2 -> 0
      e.handle(0, {'type': 'bridge', 'i1': vis.$1, 'i2': vis.$2});
      expect(e.ps[0].bridges[HashiSolver.pairKey(vis.$1, vis.$2)], 1);
      e.handle(0, {'type': 'bridge', 'i1': vis.$1, 'i2': vis.$2});
      expect(e.ps[0].bridges[HashiSolver.pairKey(vis.$1, vis.$2)], 2);
      e.handle(0, {'type': 'bridge', 'i1': vis.$1, 'i2': vis.$2});
      expect(e.ps[0].bridges[HashiSolver.pairKey(vis.$1, vis.$2)] ?? 0, 0);

      // Apply exact solution bridges for seat 0
      for (final entry in e.currentPuzzle.solutionBridges.entries) {
        if (e.ps[0].status == 'play') {
          final (u, v) = HashiSolver.parsePairKey(entry.key);
          e.handle(0, {'type': 'set_bridge', 'i1': u, 'i2': v, 'count': entry.value});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('美术馆照明竞速 (akari)', () {
    test('puzzle generator produces valid solvable puzzles for 6x6 and 8x8', () {
      final rng = Random(99);
      for (final size in [6, 8]) {
        for (var i = 0; i < 10; i++) {
          final puz = AkariSolver.generatePuzzle(size, rng);
          final board = List<int>.filled(size * size, 0);
          for (final b in puz.solutionBulbs) {
            board[b] = 1;
          }
          expect(AkariSolver.isSolved(puz.grid, board, size), isTrue);
        }
      }
    });

    test('illumination raycasting, conflict detection, dot marks, and scoring', () {
      final e = AkariGame(_setup(2, {'size': 6, 'rounds': 3}))..host = SimHost();
      e.start();

      final firstWhite = e.currentPuzzle.grid.indexOf(-2);
      final r = firstWhite ~/ 6, c = firstWhite % 6;
      // Cycle white cell: 0 -> 1 (bulb) -> 2 (dot) -> 0
      e.handle(0, {'type': 'toggle', 'r': r, 'c': c});
      expect(e.boards[0][firstWhite], 1);
      e.handle(0, {'type': 'toggle', 'r': r, 'c': c});
      expect(e.boards[0][firstWhite], 2);
      e.handle(0, {'type': 'toggle', 'r': r, 'c': c});
      expect(e.boards[0][firstWhite], 0);

      // Place solution bulbs (and dot marks on non-bulb white cells) for seat 0
      for (var i = 0; i < 36; i++) {
        if (e.currentPuzzle.grid[i] == -2 && e.ps[0].status == 'play') {
          final val = e.currentPuzzle.solutionBulbs.contains(i) ? 1 : 2;
          e.handle(0, {'type': 'set', 'r': i ~/ 6, 'c': i % 6, 'val': val});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade6Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade6Games, n: 30), 0);
    print('arcade6 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
