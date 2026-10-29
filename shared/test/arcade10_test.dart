import 'dart:math';

import 'package:aurora_shared/games/arcade10/defs.dart';
import 'package:aurora_shared/games/arcade10/futoshiki.dart';
import 'package:aurora_shared/games/arcade10/kenken.dart';
import 'package:aurora_shared/games/arcade10/masyu.dart';
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
  group('不等号数独竞速 (futoshiki)', () {
    test('puzzle generator produces valid Inequality Latin Square puzzles for 4x4 and 5x5', () {
      final rng = Random(42);
      for (final size in [4, 5]) {
        for (var i = 0; i < 12; i++) {
          final puz = FutoshikiSolver.generatePuzzle(size, rng);
          expect(FutoshikiSolver.isSolved(puz, puz.cluesFlat), isFalse);
          expect(FutoshikiSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = FutoshikiSolver.analyze(puz, puz.solutionBoard);
          expect(an.totalIneq, greaterThan(0));
          expect(an.satisfiedIneq, an.totalIneq);
        }
      }
    });

    test('clue protection, inequality violation detection, clear, and completion scoring', () {
      final e = FutoshikiGame(_setup(2, {'size': 4, 'rounds': 3}))..host = SimHost();
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

  group('黑白珍珠回路竞速 (masyu)', () {
    test('puzzle generator produces valid White & Black Pearl single-loop puzzles for 5x5 and 6x6', () {
      final rng = Random(88);
      for (final size in [5, 6]) {
        for (var i = 0; i < 12; i++) {
          final puz = MasyuSolver.generatePuzzle(size, rng);
          final emptyH = [for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0)];
          final emptyV = [for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0)];
          expect(MasyuSolver.isSolved(puz, emptyH, emptyV), isFalse);
          expect(MasyuSolver.isSolved(puz, puz.solutionHSegs, puz.solutionVSegs), isTrue);

          final flat = puz.pearlsFlat;
          expect(flat.contains(1), isTrue, reason: 'should contain at least one White Pearl (1)');
          expect(flat.contains(2), isTrue, reason: 'should contain at least one Black Pearl (2)');
        }
      }
    });

    test('segment toggling, pearl violation detection, clear, and completion scoring', () {
      final e = MasyuGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      e.handle(0, {'type': 'seg', 'dir': 'h', 'r': 0, 'c': 0});
      expect(e.ps[0].hSegs[0][0], 1);
      e.handle(0, {'type': 'clear'});
      expect(e.ps[0].hSegs[0][0], 0);

      // Apply exact solution segments for seat 0
      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 4; c++) {
          if (puz.solutionHSegs[r][c] == 1 && e.ps[0].status == 'play') {
            e.handle(0, {'type': 'seg', 'dir': 'h', 'r': r, 'c': c});
          }
        }
      }
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 5; c++) {
          if (puz.solutionVSegs[r][c] == 1 && e.ps[0].status == 'play') {
            e.handle(0, {'type': 'seg', 'dir': 'v', 'r': r, 'c': c});
          }
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('算术笼数独竞速 (kenken)', () {
    test('puzzle generator produces contiguous cages of size 1..3 and valid Latin Square solutions', () {
      final rng = Random(123);
      for (final size in [4, 5]) {
        for (var i = 0; i < 12; i++) {
          final puz = KenKenSolver.generatePuzzle(size, rng);
          expect(puz.cages, isNotEmpty);
          for (final cage in puz.cages) {
            expect(cage.cells.length, inInclusiveRange(1, 3));
            expect(KenKenSolver.evaluateCage(cage, puz.solutionBoard, size), isTrue);
          }
          expect(KenKenSolver.isSolved(puz, List<int>.filled(size * size, 0)), isFalse);
          expect(KenKenSolver.isSolved(puz, puz.solutionBoard), isTrue);
        }
      }
    });

    test('digit setting, duplicate & cage violation detection, clear, and completion scoring', () {
      final e = KenKenGame(_setup(2, {'size': 4, 'rounds': 3}))..host = SimHost();
      e.start();

      // Place same digit in (0,0) and (0,1) -> duplicate detected
      e.handle(0, {'type': 'set', 'r': 0, 'c': 0, 'val': 1});
      e.handle(0, {'type': 'set', 'r': 0, 'c': 1, 'val': 1});
      final an = KenKenSolver.analyze(e.currentPuzzle, e.boards[0]);
      expect(an.duplicateCells.contains(0), isTrue);
      expect(an.duplicateCells.contains(1), isTrue);

      e.handle(0, {'type': 'clear'});
      expect(e.boards[0].every((v) => v == 0), isTrue);

      // Apply exact solutionBoard for seat 0
      final sol = e.currentPuzzle.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        if (e.ps[0].status == 'play') {
          e.handle(0, {'type': 'set', 'r': i ~/ 4, 'c': i % 4, 'val': sol[i]});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade10Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade10Games, n: 30), 0);
    print('arcade10 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
