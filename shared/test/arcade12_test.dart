import 'dart:math';

import 'package:aurora_shared/games/arcade12/defs.dart';
import 'package:aurora_shared/games/arcade12/galaxies.dart';
import 'package:aurora_shared/games/arcade12/hidato.dart';
import 'package:aurora_shared/games/arcade12/kuromasu.dart';
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
  group('数链寻路竞速 (hidato)', () {
    test('puzzle generator produces valid 8-way Hamiltonian paths for 4x4 and 5x5', () {
      final rng = Random(42);
      for (final size in [4, 5]) {
        for (var i = 0; i < 15; i++) {
          final puz = HidatoSolver.generatePuzzle(size, rng);
          expect(HidatoSolver.isSolved(puz, puz.cluesFlat), isFalse);
          expect(HidatoSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = HidatoSolver.analyze(puz, puz.solutionBoard);
          expect(an.validLinks, size * size - 1);
          expect(an.duplicateCells, isEmpty);
          expect(an.disconnectedCells, isEmpty);
          expect(an.violatedClueCells, isEmpty);
        }
      }
    });

    test('clue protection, 8-way adjacency detection, clear, and completion scoring', () {
      final e = HidatoGame(_setup(2, {'size': 4, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      var clueR = -1, clueC = -1;
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          if (puz.clues[r][c] > 0) {
            clueR = r;
            clueC = c;
            break;
          }
        }
        if (clueR >= 0) break;
      }
      expect(clueR, greaterThanOrEqualTo(0));
      expect(
        () => e.handle(0, {'type': 'set', 'r': clueR, 'c': clueC, 'val': 1}),
        throwsA(isA<GameError>()),
      );

      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.cluesFlat));

      final sol = puz.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        final r = i ~/ 4, c = i % 4;
        if (puz.clues[r][c] == 0 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'set', 'r': r, 'c': c, 'val': sol[i]});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('黑格视线竞速 (kuromasu)', () {
    test('puzzle generator produces valid line-of-sight, non-adjacent black, connected white puzzles', () {
      final rng = Random(88);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = KuromasuSolver.generatePuzzle(size, rng);
          expect(KuromasuSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(KuromasuSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = KuromasuSolver.analyze(puz, puz.solutionBoard);
          expect(an.adjacentBlackCells, isEmpty);
          expect(an.isolatedWhiteCells, isEmpty);
          expect(an.whiteConnected, isTrue);
          expect(an.violatedClues, isEmpty);
          expect(an.satisfiedClues.length, an.totalClues);
        }
      }
    });

    test('clue protection, cell toggling (0/1/2), clear, and completion scoring', () {
      final e = KuromasuGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      var clueR = -1, clueC = -1;
      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 5; c++) {
          if (puz.clues[r][c] > 0) {
            clueR = r;
            clueC = c;
            break;
          }
        }
        if (clueR >= 0) break;
      }
      expect(clueR, greaterThanOrEqualTo(0));
      expect(
        () => e.handle(0, {'type': 'toggle', 'r': clueR, 'c': clueC}),
        throwsA(isA<GameError>()),
      );

      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      final sol = puz.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        final r = i ~/ 5, c = i % 5;
        if (puz.clues[r][c] == 0 && sol[i] == 1 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'toggle', 'r': r, 'c': c});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('对称星系分割竞速 (galaxies)', () {
    test('puzzle generator produces 180-degree symmetric connected polyomino partitions for 5x5 and 6x6', () {
      final rng = Random(123);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = GalaxiesSolver.generatePuzzle(size, rng);
          expect(puz.galaxyCount, greaterThanOrEqualTo(4));
          expect(GalaxiesSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(GalaxiesSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = GalaxiesSolver.analyze(puz, puz.solutionBoard);
          expect(an.asymmetricCells, isEmpty);
          expect(an.disconnectedCells, isEmpty);
          expect(an.violatedGalaxies, isEmpty);
          expect(an.satisfiedGalaxies.length, puz.galaxyCount);
        }
      }
    });

    test('galaxy assignment, symmetry & connectivity validation, clear, and completion scoring', () {
      final e = GalaxiesGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      e.handle(0, {'type': 'set', 'r': 0, 'c': 0, 'val': 0});
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      final sol = puz.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        final r = i ~/ 5, c = i % 5;
        if (e.ps[0].status == 'play') {
          e.handle(0, {'type': 'set', 'r': r, 'c': c, 'val': sol[i]});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade12Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade12Games, n: 30), 0);
    print('arcade12 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
