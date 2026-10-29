import 'dart:math';

import 'package:aurora_shared/games/arcade8/defs.dart';
import 'package:aurora_shared/games/arcade8/kakuro.dart';
import 'package:aurora_shared/games/arcade8/plumber.dart';
import 'package:aurora_shared/games/arcade8/shikaku.dart';
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
  group('数方分割竞速 (shikaku)', () {
    test('puzzle generator produces valid non-overlapping rectangle partitions for 5x5 and 6x6', () {
      final rng = Random(42);
      for (final size in [5, 6]) {
        for (var i = 0; i < 12; i++) {
          final puz = ShikakuSolver.generatePuzzle(size, rng);
          expect(puz.solutionRects.every((r) => r.area >= 2 && r.area <= 9), isTrue);
          expect(ShikakuSolver.isSolved(puz.clues, puz.solutionRects, size), isTrue);
        }
      }
    });

    test('overlap removal, remove/clear actions, and completion scoring', () {
      final e = ShikakuGame(_setup(2, {'size': 6, 'rounds': 3}))..host = SimHost();
      e.start();

      // Place two overlapping rectangles: the second must automatically replace the first
      e.handle(0, {'type': 'rect', 'r1': 0, 'c1': 0, 'r2': 1, 'c2': 1});
      expect(e.ps[0].rects.length, 1);
      e.handle(0, {'type': 'rect', 'r1': 0, 'c1': 1, 'r2': 1, 'c2': 2});
      expect(e.ps[0].rects.length, 1);
      expect(e.ps[0].rects.first, const ShikakuRect(0, 1, 1, 2));

      // Remove by index and clear
      e.handle(0, {'type': 'remove', 'index': 0});
      expect(e.ps[0].rects, isEmpty);

      // Apply exact solution rectangles for seat 0
      for (final rect in e.currentPuzzle.solutionRects) {
        if (e.ps[0].status == 'play') {
          e.handle(0, {
            'type': 'rect',
            'r1': rect.r1,
            'c1': rect.c1,
            'r2': rect.r2,
            'c2': rect.c2,
          });
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('数和填字竞速 (kakuro)', () {
    test('puzzle generator produces valid cross-sum puzzles for 5x5 and 6x6', () {
      final rng = Random(77);
      for (final size in [5, 6]) {
        for (var i = 0; i < 12; i++) {
          final puz = KakuroSolver.generatePuzzle(size, rng);
          expect(KakuroSolver.isSolved(puz, List<int>.filled(size * size, 0)), isFalse);
          expect(KakuroSolver.isSolved(puz, puz.solutionBoard), isTrue);
        }
      }
    });

    test('duplicate digit rejection, sum verification, and completion scoring', () {
      final e = KakuroGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      // Black clue cell at (0,0) cannot be modified
      expect(() => e.handle(0, {'type': 'set', 'r': 0, 'c': 0, 'val': 1}), throwsA(isA<GameError>()));

      // Find a horizontal run with >= 2 cells and place duplicate digits
      final runs = KakuroSolver.extractRuns(
        e.currentPuzzle.isWhite,
        e.currentPuzzle.acrossClues,
        e.currentPuzzle.downClues,
        5,
      );
      final firstRun = runs.first;
      final c0 = firstRun.cells[0], c1 = firstRun.cells[1];
      e.handle(0, {'type': 'set', 'r': c0 ~/ 5, 'c': c0 % 5, 'val': 2});
      e.handle(0, {'type': 'set', 'r': c1 ~/ 5, 'c': c1 % 5, 'val': 2});
      final an = KakuroSolver.analyze(e.currentPuzzle, e.boards[0]);
      expect(an.conflictCells.contains(c0), isTrue);
      expect(an.conflictCells.contains(c1), isTrue);

      e.handle(0, {'type': 'clear'});
      expect(e.boards[0].every((v) => v == 0), isTrue);

      // Apply exact solution digits for seat 0
      final sol = e.currentPuzzle.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        if (e.currentPuzzle.isWhite[i] && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'set', 'r': i ~/ 5, 'c': i % 5, 'val': sol[i]});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('水管工接管竞速 (plumber)', () {
    test('puzzle generator produces valid solvable pipe networks for 5x5 and 6x6', () {
      final rng = Random(123);
      for (final size in [5, 6]) {
        for (var i = 0; i < 12; i++) {
          final puz = PlumberSolver.generatePuzzle(size, rng);
          expect(puz.gaugeIndices, isNotEmpty);
          expect(PlumberSolver.isSolved(puz, puz.initRots), isFalse);
          expect(PlumberSolver.isSolved(puz, puz.solutionRots), isTrue);
        }
      }
    });

    test('pipe rotation, BFS water flow, leak detection, and completion scoring', () {
      final e = PlumberGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final initialRot = e.boards[0][0];
      e.handle(0, {'type': 'rotate', 'r': 0, 'c': 0});
      expect(e.boards[0][0], (initialRot + 1) % 4);
      e.handle(0, {'type': 'reset'});
      expect(e.boards[0][0], initialRot);

      // Rotate all pipes to solutionRots for seat 0
      final sol = e.currentPuzzle.solutionRots;
      for (var i = 0; i < sol.length; i++) {
        while (e.ps[0].status == 'play' &&
            PlumberSolver.openPortsMask(e.currentPuzzle.types[i], e.boards[0][i]) !=
                PlumberSolver.openPortsMask(e.currentPuzzle.types[i], sol[i])) {
          e.handle(0, {'type': 'rotate', 'r': i ~/ 5, 'c': i % 5});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade8Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade8Games, n: 30), 0);
    print('arcade8 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
