import 'dart:math';

import 'package:aurora_shared/games/arcade15/defs.dart';
import 'package:aurora_shared/games/arcade15/kurotto.dart';
import 'package:aurora_shared/games/arcade15/stitches.dart';
import 'package:aurora_shared/games/arcade15/tatamibari.dart';
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
  group('榻榻米分割竞速 (tatamibari)', () {
    test('puzzle generator produces valid rectangular partitions matching + / - / | clues and zero 4-corner intersections for 5x5 and 6x6', () {
      final rng = Random(42);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = TatamibariSolver.generatePuzzle(size, rng);
          expect(puz.regionCount, greaterThanOrEqualTo(5));
          expect(TatamibariSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(TatamibariSolver.isSolved(puz, puz.solutionBoard), isTrue);

          final an = TatamibariSolver.analyze(puz, puz.solutionBoard);
          expect(an.satisfiedRegions.length, puz.regionCount);
          expect(an.violatedRegions, isEmpty);
          expect(an.nonRectCells, isEmpty);
          expect(an.badProportionCells, isEmpty);
          expect(an.fourCornerVertices, isEmpty);
          expect(an.assignedCount, size * size);

          for (var k = 0; k < puz.regionCount; k++) {
            final clue = puz.clues[k];
            final r1 = clue['r1'] as int, c1 = clue['c1'] as int;
            final r2 = clue['r2'] as int, c2 = clue['c2'] as int;
            final cr = clue['r'] as int, cc = clue['c'] as int;
            final sym = clue['sym'] as String;
            final code = clue['code'] as int;
            final w = c2 - c1 + 1, h = r2 - r1 + 1;
            expect(cr, inInclusiveRange(r1, r2));
            expect(cc, inInclusiveRange(c1, c2));
            expect(puz.clueIdGrid[cr][cc], k);
            expect(puz.clueGrid[cr][cc], code);
            if (sym == '+') {
              expect(code, 1);
              expect(w, equals(h));
            } else if (sym == '-') {
              expect(code, 2);
              expect(w, greaterThan(h));
            } else {
              expect(sym, '|');
              expect(code, 3);
              expect(h, greaterThan(w));
            }
          }
        }
      }
    });

    test('region assignment, 4-corner intersection detection, clear, and completion scoring', () {
      final e = TatamibariGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      e.handle(0, {'type': 'set', 'r': 0, 'c': 0, 'val': 0});
      expect(e.boards[0][0], 0);
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      final sol = puz.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        if (e.ps[0].status == 'play') {
          e.handle(0, {'type': 'set', 'r': i ~/ 5, 'c': i % 5, 'val': sol[i]});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('跨宫缝线竞速 (stitches)', () {
    test('puzzle generator produces valid polyomino regions, 1 stitch per adjacent pair, max 1 hole per cell, and matching row/col clues for 5x5 and 6x6', () {
      final rng = Random(88);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = StitchesSolver.generatePuzzle(size, rng);
          expect(puz.totalPairs, greaterThanOrEqualTo(5));
          expect(
            StitchesSolver.isSolved(puz, puz.initialHStitches, puz.initialVStitches),
            isFalse,
          );
          expect(
            StitchesSolver.isSolved(puz, puz.solutionHStitches, puz.solutionVStitches),
            isTrue,
          );

          final an = StitchesSolver.analyze(
            puz,
            puz.solutionHStitches,
            puz.solutionVStitches,
          );
          expect(an.satisfiedPairs.length, puz.totalPairs);
          expect(an.violatedPairs, isEmpty);
          expect(an.missingPairs, isEmpty);
          expect(an.overloadedCells, isEmpty);
          expect(an.satisfiedRows.length, size);
          expect(an.satisfiedCols.length, size);
          expect(an.rowCounts, equals(puz.rowClues));
          expect(an.colCounts, equals(puz.colClues));
          for (final cnt in an.cellHoleCounts) {
            expect(cnt, inInclusiveRange(0, 1));
          }
        }
      }
    });

    test('cross-border stitch toggling, clear, and completion scoring', () {
      final e = StitchesGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      // Find a valid cross-border pair of cells
      var br1 = -1, bc1 = -1, br2 = -1, bc2 = -1;
      for (var r = 0; r < 5 && br1 < 0; r++) {
        for (var c = 0; c < 4; c++) {
          if (puz.regions[r][c] != puz.regions[r][c + 1]) {
            br1 = r;
            bc1 = c;
            br2 = r;
            bc2 = c + 1;
            break;
          }
        }
      }
      expect(br1, greaterThanOrEqualTo(0));
      e.handle(0, {'type': 'stitch', 'r1': br1, 'c1': bc1, 'r2': br2, 'c2': bc2});
      expect(e.ps[0].hStitches[br1][bc1], 1);
      e.handle(0, {'type': 'clear'});
      expect(e.ps[0].hStitches[br1][bc1], 0);

      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 4; c++) {
          if (puz.solutionHStitches[r][c] == 1 && e.ps[0].status == 'play') {
            e.handle(0, {'type': 'stitch', 'r1': r, 'c1': c, 'r2': r, 'c2': c + 1});
          }
        }
      }
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 5; c++) {
          if (puz.solutionVStitches[r][c] == 1 && e.ps[0].status == 'play') {
            e.handle(0, {'type': 'stitch', 'r1': r, 'c1': c, 'r2': r + 1, 'c2': c});
          }
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('黑格邻群计数竞速 (kurotto)', () {
    test('puzzle generator produces valid circled clues matching touching distinct black-cluster size sums for 5x5 and 6x6', () {
      final rng = Random(123);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = KurottoSolver.generatePuzzle(size, rng);
          expect(KurottoSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(KurottoSolver.isSolved(puz, puz.solutionBoard), isTrue);

          final an = KurottoSolver.analyze(puz, puz.solutionBoard);
          expect(an.totalClues, greaterThanOrEqualTo(5));
          expect(an.satisfiedClues.length, an.totalClues);
          expect(an.violatedClues, isEmpty);
          expect(an.pendingClues, isEmpty);

          for (var r = 0; r < size; r++) {
            for (var c = 0; c < size; c++) {
              final clue = puz.clues[r][c];
              if (clue >= 0) {
                expect(puz.solutionBoard[r * size + c], 0);
                expect(an.clueClusterSums[r * size + c], clue);
              }
            }
          }
        }
      }
    });

    test('non-clue cell toggling (0/1/2), distinct black-cluster deduplication, clear, and completion scoring', () {
      final e = KurottoGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      var nonClueR = -1, nonClueC = -1;
      for (var r = 0; r < 5 && nonClueR < 0; r++) {
        for (var c = 0; c < 5; c++) {
          if (puz.clues[r][c] < 0) {
            nonClueR = r;
            nonClueC = c;
            break;
          }
        }
      }
      expect(nonClueR, greaterThanOrEqualTo(0));
      final idx = nonClueR * 5 + nonClueC;
      e.handle(0, {'type': 'toggle', 'r': nonClueR, 'c': nonClueC});
      expect(e.boards[0][idx], 1);
      e.handle(0, {'type': 'toggle', 'r': nonClueR, 'c': nonClueC});
      expect(e.boards[0][idx], 2);
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      final sol = puz.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        final r = i ~/ 5, c = i % 5;
        if (sol[i] == 1 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'toggle', 'r': r, 'c': c});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade15Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade15Games, n: 30), 0);
    print('arcade15 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
