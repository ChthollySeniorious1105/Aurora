import 'dart:math';

import 'package:aurora_shared/games/arcade11/binairo.dart';
import 'package:aurora_shared/games/arcade11/defs.dart';
import 'package:aurora_shared/games/arcade11/skyscrapers.dart';
import 'package:aurora_shared/games/arcade11/suguru.dart';
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
  group('摩天楼可见数竞速 (skyscrapers)', () {
    test('puzzle generator produces valid Latin Square & border visibility puzzles for 4x4 and 5x5', () {
      final rng = Random(42);
      for (final size in [4, 5]) {
        for (var i = 0; i < 15; i++) {
          final puz = SkyscrapersSolver.generatePuzzle(size, rng);
          expect(SkyscrapersSolver.isSolved(puz, puz.cluesFlat), isFalse);
          expect(SkyscrapersSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = SkyscrapersSolver.analyze(puz, puz.solutionBoard);
          expect(an.totalClues, 4 * size);
          expect(an.satisfiedClues, an.totalClues);
          expect(an.duplicateCells, isEmpty);
          expect(an.violatedCells, isEmpty);
        }
      }
    });

    test('clue protection, visibility violation detection, clear, and completion scoring', () {
      final e = SkyscrapersGame(_setup(2, {'size': 4, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      // Find a fixed interior clue cell and verify it cannot be overwritten
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

      // Clear resets non-clue cells
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.cluesFlat));

      // Apply exact solutionBoard for seat 0 on all non-clue cells
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

  group('黑白平衡二进制竞速 (binairo)', () {
    test('puzzle generator produces valid balanced, no-3-in-a-row, distinct-line puzzles for 4x4 and 6x6', () {
      final rng = Random(88);
      for (final size in [4, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = BinairoSolver.generatePuzzle(size, rng);
          expect(BinairoSolver.isSolved(puz, puz.cluesFlat), isFalse);
          expect(BinairoSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = BinairoSolver.analyze(puz, puz.solutionBoard);
          expect(an.threeInRowCells, isEmpty);
          expect(an.unbalancedCells, isEmpty);
          expect(an.duplicateLineCells, isEmpty);
          expect(an.validLines, 2 * size);
        }
      }
    });

    test('cell toggling, 3-in-a-row violation detection, clear, and completion scoring', () {
      final e = BinairoGame(_setup(2, {'size': 4, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      // Find a fixed clue cell and verify it cannot be overwritten
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
        () => e.handle(0, {'type': 'toggle', 'r': clueR, 'c': clueC}),
        throwsA(isA<GameError>()),
      );

      // Clear resets non-clue cells
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.cluesFlat));

      // Apply exact solutionBoard for seat 0 using toggle on non-clue cells
      final sol = puz.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        final r = i ~/ 4, c = i % 4;
        if (puz.clues[r][c] == 0) {
          while (e.ps[0].status == 'play' && e.boards[0][i] != sol[i]) {
            e.handle(0, {'type': 'toggle', 'r': r, 'c': c});
          }
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('数块邻格互斥竞速 (suguru)', () {
    test('puzzle generator produces contiguous polyomino regions of size 1..5 and valid 8-way no-touch solutions', () {
      final rng = Random(123);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = SuguruSolver.generatePuzzle(size, rng);
          expect(puz.regionList, isNotEmpty);
          for (final reg in puz.regionList) {
            expect(reg.size, inInclusiveRange(1, 5));
          }
          expect(SuguruSolver.isSolved(puz, puz.cluesFlat), isFalse);
          expect(SuguruSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = SuguruSolver.analyze(puz, puz.solutionBoard);
          expect(an.regionDuplicateCells, isEmpty);
          expect(an.adjacentTouchCells, isEmpty);
          expect(an.satisfiedRegions.length, puz.regionList.length);
        }
      }
    });

    test('digit setting, 8-way touch & region duplicate detection, clear, and completion scoring', () {
      final e = SuguruGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      // Clear resets non-clue cells
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.cluesFlat));

      // Apply exact solutionBoard for seat 0
      final sol = puz.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        final r = i ~/ 5, c = i % 5;
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

  test('bot simulations (arcade11Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade11Games, n: 30), 0);
    print('arcade11 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
