import 'dart:math';

import 'package:aurora_shared/games/arcade16/chocona.dart';
import 'package:aurora_shared/games/arcade16/defs.dart';
import 'package:aurora_shared/games/arcade16/lits.dart';
import 'package:aurora_shared/games/arcade16/magnets.dart';
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
  group('四格骨牌竞速 (lits)', () {
    test('puzzle generator produces valid L, I, T, S tetromino per region, globally connected, no 2x2, and no same-shape touching for 5x5 and 6x6', () {
      final rng = Random(42);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = LitsSolver.generatePuzzle(size, rng);
          expect(puz.regionCount, size <= 5 ? 4 : 5);
          expect(puz.regionSizes.every((s) => s >= 4), isTrue);
          expect(LitsSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(LitsSolver.isSolved(puz, puz.solutionBoard), isTrue);

          final an = LitsSolver.analyze(puz, puz.solutionBoard);
          expect(an.satisfiedRegions.length, puz.regionCount);
          expect(an.violatedRegions, isEmpty);
          expect(an.pendingRegions, isEmpty);
          expect(an.sameShapeConflictRegions, isEmpty);
          expect(an.twoByTwoCells, isEmpty);
          expect(an.conflictCells, isEmpty);
          expect(an.isAllBlackConnected, isTrue);
          expect(an.blackComponentCount, 1);
          expect(an.blackCount, puz.regionCount * 4);
          for (var r = 0; r < puz.regionCount; r++) {
            expect(an.regionBlackCounts[r], 4);
            expect(LitsSolver.validLetters.contains(an.regionShapes[r]), isTrue);
          }
        }
      }
    });

    test('cell toggling (0/1/2), 2x2 detection, clear, and completion scoring', () {
      final e = LitsGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      expect(e.boards[0][0], 1);
      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      expect(e.boards[0][0], 2);
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      final sol = puz.solutionBoard;
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

  group('巧克块矩形竞速 (chocona)', () {
    test('puzzle generator produces valid regions with exact black counts and all-rectangle black components for 5x5 and 6x6', () {
      final rng = Random(88);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = ChoconaSolver.generatePuzzle(size, rng);
          expect(puz.regionCount, greaterThanOrEqualTo(6));
          expect(ChoconaSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(ChoconaSolver.isSolved(puz, puz.solutionBoard), isTrue);

          final an = ChoconaSolver.analyze(puz, puz.solutionBoard);
          expect(an.satisfiedRegions.length, puz.regionCount);
          expect(an.violatedRegions, isEmpty);
          expect(an.pendingRegions, isEmpty);
          expect(an.nonRectCells, isEmpty);
          expect(an.blackComponentCount, greaterThanOrEqualTo(2));
          expect(an.rectComponentCount, an.blackComponentCount);
          expect(an.regionBlackCounts, equals(puz.regionClues));
        }
      }
    });

    test('cell toggling (0/1/2), non-rectangular component detection, clear, and completion scoring', () {
      final e = ChoconaGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      // Form an L-shaped 3-cell black component and verify nonRectCells detects it
      final testBoard = List<int>.filled(25, 0);
      testBoard[0] = 1;
      testBoard[1] = 1;
      testBoard[5] = 1;
      final testAn = ChoconaSolver.analyze(puz, testBoard);
      expect(testAn.nonRectCells, containsAll([0, 1, 5]));

      e.handle(0, {'type': 'toggle', 'r': 0, 'c': 0});
      expect(e.boards[0][0], 1);
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      final sol = puz.solutionBoard;
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

  group('磁铁正负极竞速 (magnets)', () {
    test('puzzle generator produces valid domino slots, no same-pole adjacency, and exact row/col +/- counts for 5x5 and 6x6', () {
      final rng = Random(123);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = MagnetsSolver.generatePuzzle(size, rng);
          expect(puz.slotCount, (size * size) ~/ 2);
          expect(MagnetsSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(MagnetsSolver.isSolved(puz, puz.solutionBoard), isTrue);

          final an = MagnetsSolver.analyze(puz, puz.solutionBoard);
          expect(an.satisfiedSlots.length, puz.slotCount);
          expect(an.violatedSlots, isEmpty);
          expect(an.samePoleConflictCells, isEmpty);
          expect(an.satisfiedRows.length, size);
          expect(an.satisfiedCols.length, size);
          expect(an.violatedRows, isEmpty);
          expect(an.violatedCols, isEmpty);
          expect(an.rowPlusCounts, equals(puz.rowPlus));
          expect(an.rowMinusCounts, equals(puz.rowMinus));
          expect(an.colPlusCounts, equals(puz.colPlus));
          expect(an.colMinusCounts, equals(puz.colMinus));
        }
      }
    });

    test('domino polarity cycling, set, clear, and completion scoring', () {
      final e = MagnetsGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      final firstSlot = puz.slots.first;
      final idxA = firstSlot[0], idxB = firstSlot[1];
      final rA = idxA ~/ 5, cA = idxA % 5;

      e.handle(0, {'type': 'cycle', 'r': rA, 'c': cA});
      expect(e.boards[0][idxA], 1);
      expect(e.boards[0][idxB], 2);

      e.handle(0, {'type': 'cycle', 'r': rA, 'c': cA});
      expect(e.boards[0][idxA], 2);
      expect(e.boards[0][idxB], 1);

      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      final sol = puz.solutionBoard;
      for (final slot in puz.slots) {
        final u = slot[0];
        if (sol[u] != 0 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'set', 'r': u ~/ 5, 'c': u % 5, 'val': sol[u]});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade16Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade16Games, n: 30), 0);
    print('arcade16 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
