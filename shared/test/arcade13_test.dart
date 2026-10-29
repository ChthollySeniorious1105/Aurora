import 'dart:math';

import 'package:aurora_shared/games/arcade13/defs.dart';
import 'package:aurora_shared/games/arcade13/norinori.dart';
import 'package:aurora_shared/games/arcade13/thermometers.dart';
import 'package:aurora_shared/games/arcade13/yajilin.dart';
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
  group('箭头回路竞速 (yajilin)', () {
    test('puzzle generator produces valid arrow clues, non-adjacent black cells, and single closed loop for 5x5 and 6x6', () {
      final rng = Random(42);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = YajilinSolver.generatePuzzle(size, rng);
          expect(
            YajilinSolver.isSolved(puz, puz.initialBoard, puz.initialHSegs, puz.initialVSegs),
            isFalse,
          );
          expect(
            YajilinSolver.isSolved(puz, puz.solutionBoard, puz.solutionHSegs, puz.solutionVSegs),
            isTrue,
          );
          final an = YajilinSolver.analyze(
            puz,
            puz.solutionBoard,
            puz.solutionHSegs,
            puz.solutionVSegs,
          );
          expect(an.totalClues, greaterThanOrEqualTo(2));
          expect(an.satisfiedClues.length, an.totalClues);
          expect(an.violatedClues, isEmpty);
          expect(an.adjacentBlackCells, isEmpty);
          expect(an.badDegreeCells, isEmpty);
          expect(an.unvisitedLoopCells, isEmpty);
          expect(an.isSingleLoop, isTrue);
        }
      }
    });

    test('clue protection, cell shading, edge toggling, clear, and completion scoring', () {
      final e = YajilinGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      var clueR = -1, clueC = -1;
      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 5; c++) {
          if (puz.clues[r][c] != null) {
            clueR = r;
            clueC = c;
            break;
          }
        }
        if (clueR >= 0) break;
      }
      expect(clueR, greaterThanOrEqualTo(0));
      expect(
        () => e.handle(0, {'type': 'shade', 'r': clueR, 'c': clueC}),
        throwsA(isA<GameError>()),
      );

      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      final solBoard = puz.solutionBoard;
      for (var i = 0; i < solBoard.length; i++) {
        final r = i ~/ 5, c = i % 5;
        if (puz.clues[r][c] == null && solBoard[i] == 1 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'shade', 'r': r, 'c': c});
        }
      }
      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 4; c++) {
          if (puz.solutionHSegs[r][c] == 1 && e.ps[0].status == 'play') {
            e.handle(0, {'type': 'edge', 'r1': r, 'c1': c, 'r2': r, 'c2': c + 1});
          }
        }
      }
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 5; c++) {
          if (puz.solutionVSegs[r][c] == 1 && e.ps[0].status == 'play') {
            e.handle(0, {'type': 'edge', 'r1': r, 'c1': c, 'r2': r + 1, 'c2': c});
          }
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('多米诺双格竞速 (norinori)', () {
    test('puzzle generator produces 2-black-per-region and isolated 1x2 domino solutions for 5x5 and 6x6', () {
      final rng = Random(88);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = NorinoriSolver.generatePuzzle(size, rng);
          expect(puz.regionCount, greaterThanOrEqualTo(4));
          expect(NorinoriSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(NorinoriSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = NorinoriSolver.analyze(puz, puz.solutionBoard);
          expect(an.satisfiedRegions.length, puz.regionCount);
          expect(an.violatedRegions, isEmpty);
          expect(an.isolatedBlackCells, isEmpty);
          expect(an.crowdedBlackCells, isEmpty);
          expect(an.blackCount, puz.regionCount * 2);
          expect(an.validDominoCells.length, puz.regionCount * 2);
        }
      }
    });

    test('cell toggling (0/1/2), domino pairing validation, clear, and completion scoring', () {
      final e = NorinoriGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
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

  group('温度计填充竞速 (thermometers)', () {
    test('puzzle generator produces valid length 2..5 thermometers and continuous bulb fills for 5x5 and 6x6', () {
      final rng = Random(123);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = ThermometersSolver.generatePuzzle(size, rng);
          for (final t in puz.thermos) {
            expect(t.length, inInclusiveRange(2, 5));
          }
          expect(ThermometersSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(ThermometersSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = ThermometersSolver.analyze(puz, puz.solutionBoard);
          expect(an.brokenThermos, isEmpty);
          expect(an.gapCells, isEmpty);
          expect(an.violatedRows, isEmpty);
          expect(an.violatedCols, isEmpty);
          expect(an.satisfiedRows.length, size);
          expect(an.satisfiedCols.length, size);
        }
      }
    });

    test('fill_to from bulb, gap detection, clear, and completion scoring', () {
      final e = ThermometersGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      final firstThermo = puz.thermos.first;
      final tip = firstThermo.last;
      // Filling only the tip creates a gap in that thermometer
      e.handle(0, {'type': 'toggle', 'r': tip[0], 'c': tip[1]});
      final gapAn = ThermometersSolver.analyze(puz, e.boards[0]);
      expect(gapAn.brokenThermos, contains(0));
      expect(gapAn.gapCells, isNotEmpty);

      // fill_to on the tip fills continuously from bulb to tip
      e.handle(0, {'type': 'fill_to', 'r': tip[0], 'c': tip[1]});
      final contAn = ThermometersSolver.analyze(puz, e.boards[0]);
      expect(contAn.brokenThermos, isNot(contains(0)));

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

  test('bot simulations (arcade13Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade13Games, n: 30), 0);
    print('arcade13 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
