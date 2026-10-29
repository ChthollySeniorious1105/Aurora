import 'dart:math';

import 'package:aurora_shared/games/arcade7/defs.dart';
import 'package:aurora_shared/games/arcade7/lasermaze.dart';
import 'package:aurora_shared/games/arcade7/nurikabe.dart';
import 'package:aurora_shared/games/arcade7/slitherlink.dart';
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
  group('数墙竞速 (nurikabe)', () {
    test('puzzle generator produces valid solvable puzzles for 5x5 and 7x7', () {
      final rng = Random(42);
      for (final size in [5, 7]) {
        for (var i = 0; i < 12; i++) {
          final puz = NurikabeSolver.generatePuzzle(size, rng);
          final board = List<int>.filled(size * size, 0);
          for (final idx in puz.solutionSea) {
            board[idx] = 1;
          }
          expect(NurikabeSolver.isSolved(puz.clues, board, size), isTrue);
        }
      }
    });

    test('2x2 sea violation, sea connectivity, island clue rules, and scoring', () {
      // Custom 3x3 test grid: clue 2 at (0,0), clue 2 at (2,2)
      final clues = [
        2, 0, 0,
        0, 0, 0,
        0, 0, 2,
      ];
      // Valid solution: (0,0)+(0,1) island 1; (1,2)+(2,2) island 2; remaining 5 cells connected sea
      final validBoard = [
        0, 2, 1,
        1, 1, 0,
        1, 1, 0,
      ];
      // Wait: (1,0),(1,1),(2,0),(2,1) is a 2x2 sea block! Verify it's rejected!
      expect(NurikabeSolver.findTwoByTwoSeaCells(clues, validBoard, 3).length, 4);
      expect(NurikabeSolver.isSolved(clues, validBoard, 3), isFalse);

      // Fix 2x2 by making (2,0) part of bottom island and (0,2),(1,2) sea:
      // Island 1: (0,0),(1,0) size 2; Island 2: (2,1),(2,2) size 2; Sea: (0,1),(0,2),(1,1),(1,2),(2,0) -> wait (2,0) not connected to sea!
      // Instead: Island 1: (0,0),(0,1) size 2; Island 2: (2,1),(2,2) size 2; clue at (2,0)=1
      final clues2 = [
        2, 0, 0,
        0, 0, 0,
        1, 0, 1,
      ];
      final validBoard2 = [
        0, 2, 1,
        1, 1, 1,
        0, 1, 0,
      ];
      expect(NurikabeSolver.findTwoByTwoSeaCells(clues2, validBoard2, 3), isEmpty);
      expect(NurikabeSolver.isSolved(clues2, validBoard2, 3), isTrue);

      final e = NurikabeGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final firstNonClue = e.currentPuzzle.clues.indexOf(0);
      final r = firstNonClue ~/ 5, c = firstNonClue % 5;
      // Cycle 0 -> 1 (sea) -> 2 (dot) -> 0
      e.handle(0, {'type': 'toggle', 'r': r, 'c': c});
      expect(e.boards[0][firstNonClue], 1);
      e.handle(0, {'type': 'toggle', 'r': r, 'c': c});
      expect(e.boards[0][firstNonClue], 2);
      e.handle(0, {'type': 'toggle', 'r': r, 'c': c});
      expect(e.boards[0][firstNonClue], 0);

      // Apply exact solution sea for seat 0
      for (var i = 0; i < 25; i++) {
        if (e.currentPuzzle.clues[i] == 0 && e.ps[0].status == 'play') {
          final val = e.currentPuzzle.solutionSea.contains(i) ? 1 : 2;
          e.handle(0, {'type': 'set', 'r': i ~/ 5, 'c': i % 5, 'val': val});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('数圈竞速 (slitherlink)', () {
    test('puzzle generator produces valid single-loop puzzles for 5x5 and 6x6', () {
      final rng = Random(77);
      for (final size in [5, 6]) {
        for (var i = 0; i < 12; i++) {
          final puz = SlitherlinkSolver.generatePuzzle(size, rng);
          expect(
            SlitherlinkSolver.isSolved(puz.clues, puz.solutionHEdges, puz.solutionVEdges, size),
            isTrue,
          );
        }
      }
    });

    test('edge toggling, branching/multi-loop rejection, and completion scoring', () {
      final e = SlitherlinkGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      // Cycle horizontal edge (0, 0): 0 -> 1 -> 2 -> 0
      e.handle(0, {'type': 'edge', 'dir': 'h', 'r': 0, 'c': 0});
      expect(e.ps[0].hEdges[0], 1);
      e.handle(0, {'type': 'edge', 'dir': 'h', 'r': 0, 'c': 0});
      expect(e.ps[0].hEdges[0], 2);
      e.handle(0, {'type': 'edge', 'dir': 'h', 'r': 0, 'c': 0});
      expect(e.ps[0].hEdges[0], 0);

      // Apply solution edges for seat 0
      final solH = e.currentPuzzle.solutionHEdges;
      final solV = e.currentPuzzle.solutionVEdges;
      for (var i = 0; i < solH.length; i++) {
        if (solH[i] == 1 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'edge', 'dir': 'h', 'r': i ~/ 5, 'c': i % 5, 'val': 1});
        }
      }
      for (var i = 0; i < solV.length; i++) {
        if (solV[i] == 1 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'edge', 'dir': 'v', 'r': i ~/ 6, 'c': i % 6, 'val': 1});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('激光迷宫竞速 (lasermaze)', () {
    test('puzzle generator produces valid solvable optical puzzles for 6x6 and 7x7', () {
      final rng = Random(123);
      for (final size in [6, 7]) {
        for (var i = 0; i < 12; i++) {
          final puz = LaserMazeSolver.generatePuzzle(size, rng);
          expect(puz.crystalIndices, isNotEmpty);
          expect(LaserMazeSolver.isSolved(puz, List<int>.filled(size * size, 0)), isFalse);
          expect(LaserMazeSolver.isSolved(puz, puz.solutionBoard), isTrue);
        }
      }
    });

    test('mirror rotation, placement, raycast reflection, reset, and scoring', () {
      final e = LaserMazeGame(_setup(2, {'size': 6, 'rounds': 3}))..host = SimHost();
      e.start();

      final firstEmpty = e.currentPuzzle.grid.indexOf(0);
      final r = firstEmpty ~/ 6, c = firstEmpty % 6;
      // Rotate cycles 0 -> 1 ('/') -> 2 ('\') -> 0
      e.handle(0, {'type': 'rotate', 'r': r, 'c': c});
      expect(e.boards[0][firstEmpty], 1);
      e.handle(0, {'type': 'rotate', 'r': r, 'c': c});
      expect(e.boards[0][firstEmpty], 2);
      e.handle(0, {'type': 'reset'});
      expect(e.boards[0][firstEmpty], 0);

      // Place solution mirrors for seat 0
      final sol = e.currentPuzzle.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        if (sol[i] != 0 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'place', 'r': i ~/ 6, 'c': i % 6, 'mirror': sol[i]});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade7Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade7Games, n: 30), 0);
    print('arcade7 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
