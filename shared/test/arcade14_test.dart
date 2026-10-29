import 'dart:math';

import 'package:aurora_shared/games/arcade14/creek.dart';
import 'package:aurora_shared/games/arcade14/defs.dart';
import 'package:aurora_shared/games/arcade14/heyawake.dart';
import 'package:aurora_shared/games/arcade14/shingoki.dart';
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
  group('分室涂黑竞速 (heyawake)', () {
    test('puzzle generator produces valid rectangular rooms and solutions satisfying all 4 Heyawake rules for 5x5 and 6x6', () {
      final rng = Random(42);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = HeyawakeSolver.generatePuzzle(size, rng);
          expect(puz.roomCount, greaterThanOrEqualTo(3));
          for (final rm in puz.rooms) {
            final r1 = rm['r1']!, c1 = rm['c1']!, r2 = rm['r2']!, c2 = rm['c2']!;
            final id = rm['id']!;
            expect(r1, lessThanOrEqualTo(r2));
            expect(c1, lessThanOrEqualTo(c2));
            for (var r = r1; r <= r2; r++) {
              for (var c = c1; c <= c2; c++) {
                expect(puz.roomId[r][c], id);
              }
            }
          }
          expect(HeyawakeSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(HeyawakeSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = HeyawakeSolver.analyze(puz, puz.solutionBoard);
          expect(an.satisfiedRooms.length, puz.roomCount);
          expect(an.violatedRooms, isEmpty);
          expect(an.adjacentBlackCells, isEmpty);
          expect(an.spanViolationCells, isEmpty);
          expect(an.whiteConnected, isTrue);
        }
      }
    });

    test('cell toggling (0/1/2), 3-room white span detection, clear, and completion scoring', () {
      final e = HeyawakeGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
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

  group('信号灯回路竞速 (shingoki)', () {
    test('puzzle generator produces valid single closed loop and traffic light clues (W straight, B turn, ray sum >= 2) for 5x5 and 6x6', () {
      final rng = Random(88);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = ShingokiSolver.generatePuzzle(size, rng);
          expect(
            ShingokiSolver.isSolved(puz, puz.initialHSegs, puz.initialVSegs),
            isFalse,
          );
          expect(
            ShingokiSolver.isSolved(puz, puz.solutionHSegs, puz.solutionVSegs),
            isTrue,
          );
          final an = ShingokiSolver.analyze(
            puz,
            puz.solutionHSegs,
            puz.solutionVSegs,
          );
          expect(an.totalClues, greaterThanOrEqualTo(4));
          expect(an.satisfiedClues.length, an.totalClues);
          expect(an.violatedClues, isEmpty);
          expect(an.unvisitedClues, isEmpty);
          expect(an.badDegreeVertices, isEmpty);
          expect(an.isSingleLoop, isTrue);

          for (var r = 0; r < size; r++) {
            for (var c = 0; c < size; c++) {
              final clue = puz.clues[r][c];
              if (clue != null) {
                expect(clue['color'], isIn(['W', 'B']));
                expect(clue['len'] as int, greaterThanOrEqualTo(2));
              }
            }
          }
        }
      }
    });

    test('edge toggling, clear, and completion scoring', () {
      final e = ShingokiGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      e.handle(0, {'type': 'edge', 'r1': 0, 'c1': 0, 'r2': 0, 'c2': 1});
      expect(e.ps[0].hSegs[0][0], 1);
      e.handle(0, {'type': 'clear'});
      expect(e.ps[0].hSegs[0][0], 0);

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

  group('溪流交点竞速 (creek)', () {
    test('puzzle generator produces valid vertex clues 0..4 and single connected white creek for 5x5 and 6x6', () {
      final rng = Random(123);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = CreekSolver.generatePuzzle(size, rng);
          expect(CreekSolver.isSolved(puz, puz.initialBoard), isFalse);
          expect(CreekSolver.isSolved(puz, puz.solutionBoard), isTrue);
          final an = CreekSolver.analyze(puz, puz.solutionBoard);
          expect(an.totalClues, greaterThanOrEqualTo(5));
          expect(an.satisfiedVertices.length, an.totalClues);
          expect(an.violatedVertices, isEmpty);
          expect(an.pendingVertices, isEmpty);
          expect(an.whiteConnected, isTrue);

          for (var vr = 0; vr <= size; vr++) {
            for (var vc = 0; vc <= size; vc++) {
              final clue = puz.vertexClues[vr][vc];
              expect(clue, inInclusiveRange(-1, 4));
            }
          }
        }
      }
    });

    test('cell toggling (0/1/2), clear, and completion scoring', () {
      final e = CreekGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
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

  test('bot simulations (arcade14Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade14Games, n: 30), 0);
    print('arcade14 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
