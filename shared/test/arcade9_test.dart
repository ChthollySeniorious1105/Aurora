import 'dart:math';

import 'package:aurora_shared/games/arcade9/defs.dart';
import 'package:aurora_shared/games/arcade9/hitori.dart';
import 'package:aurora_shared/games/arcade9/starbattle.dart';
import 'package:aurora_shared/games/arcade9/tents.dart';
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
  group('数独涂黑竞速 (hitori)', () {
    test('puzzle generator produces valid shading puzzles for 5x5 and 6x6', () {
      final rng = Random(42);
      for (final size in [5, 6]) {
        for (var i = 0; i < 12; i++) {
          final puz = HitoriSolver.generatePuzzle(size, rng);
          expect(HitoriSolver.isSolved(puz, List<int>.filled(size * size, 0)), isFalse);
          expect(HitoriSolver.isSolved(puz, puz.solutionMask), isTrue);
        }
      }
    });

    test('cell toggle (0->1->2->0), adjacency/connectivity check, and completion scoring', () {
      final e = HitoriGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      // Toggle (0,0): 0 -> 1 -> 2 -> 0
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      expect(e.boards[0][0], 1);
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      expect(e.boards[0][0], 2);
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      expect(e.boards[0][0], 0);

      // Shade two adjacent cells (0,0) and (0,1) -> adjacentBlackCells detected
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 1});
      final an = HitoriSolver.analyze(e.currentPuzzle, e.boards[0]);
      expect(an.adjacentBlackCells.contains(0), isTrue);
      expect(an.adjacentBlackCells.contains(1), isTrue);

      e.handle(0, {'type': 'clear'});
      expect(e.boards[0].every((v) => v == 0), isTrue);

      // Apply exact solutionMask for seat 0
      final sol = e.currentPuzzle.solutionMask;
      for (var i = 0; i < sol.length; i++) {
        if (sol[i] == 1 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'toggle', 'r': i ~/ 5, 'c': i % 5});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('星战放星竞速 (starbattle)', () {
    test('puzzle generator produces N contiguous regions and valid non-touching 1-Star solutions', () {
      final rng = Random(77);
      for (final size in [5, 6]) {
        for (var i = 0; i < 12; i++) {
          final puz = StarBattleSolver.generatePuzzle(size, rng);
          expect(puz.regions.length, size);
          expect(StarBattleSolver.isSolved(puz, List<int>.filled(size * size, 0)), isFalse);
          expect(StarBattleSolver.isSolved(puz, puz.solutionBoard), isTrue);
        }
      }
    });

    test('8-way touching star detection, clear, and completion scoring', () {
      final e = StarBattleGame(_setup(2, {'size': 6, 'rounds': 3}))..host = SimHost();
      e.start();

      // Place two diagonally touching stars at (0,0) and (1,1)
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      e.handle(0, {'type': 'toggle', 'r': 1, 'c': 1});
      final an = StarBattleSolver.analyze(e.currentPuzzle, e.boards[0]);
      expect(an.touchingStars.contains(0), isTrue);
      expect(an.touchingStars.contains(7), isTrue);

      e.handle(0, {'type': 'clear'});
      expect(e.boards[0].every((v) => v == 0), isTrue);

      // Apply exact solutionBoard for seat 0
      final sol = e.currentPuzzle.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        if (sol[i] == 1 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'toggle', 'r': i ~/ 6, 'c': i % 6});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('帐篷露营竞速 (tents)', () {
    test('puzzle generator produces valid 1-to-1 Tent & Tree pairings for 5x5 and 6x6', () {
      final rng = Random(123);
      for (final size in [5, 6]) {
        for (var i = 0; i < 12; i++) {
          final puz = TentsSolver.generatePuzzle(size, rng);
          expect(puz.treeIndices, isNotEmpty);
          expect(TentsSolver.isSolved(puz, List<int>.filled(size * size, 0)), isFalse);
          expect(TentsSolver.isSolved(puz, puz.solutionBoard), isTrue);
        }
      }
    });

    test('tree cell rejection, bipartite matching verification, and completion scoring', () {
      final e = TentsGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final treeIdx = e.currentPuzzle.treeIndices.first;
      expect(
        () => e.handle(0, {'type': 'toggle', 'r': treeIdx ~/ 5, 'c': treeIdx % 5}),
        throwsA(isA<GameError>()),
      );

      // Apply exact solutionBoard for seat 0
      final sol = e.currentPuzzle.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        if (sol[i] == 1 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'toggle', 'r': i ~/ 5, 'c': i % 5});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade9Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade9Games, n: 30), 0);
    print('arcade9 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
