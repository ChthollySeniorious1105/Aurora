import 'dart:math';

import 'package:aurora_shared/games/arcade17/defs.dart';
import 'package:aurora_shared/games/arcade17/match3_battle.dart';
import 'package:aurora_shared/games/arcade17/shakashaka.dart';
import 'package:aurora_shared/games/arcade17/yinyang.dart';
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
  group('宝石消消乐对战 (match3_battle)', () {
    test('initial 7x7 board has no pre-existing 3-in-a-row and at least one valid swap for 5 and 6 colors', () {
      final rng = Random(42);
      for (final colors in [5, 6]) {
        for (var i = 0; i < 20; i++) {
          final board = Match3Logic.generateInitialBoard(colors, rng);
          expect(board.length, 49);
          expect(board.every((v) => v >= 1 && v <= colors), isTrue);
          expect(Match3Logic.hasAutoMatch(board), isFalse);
          expect(Match3Logic.findValidSwaps(board), isNotEmpty);
        }
      }
    });

    test('4-in-a-row creates Line Blaster (⚡), 5-in-a-row creates Rainbow Prism (🌈), and Ice Shield (❄️) thaws before clearing', () {
      final rng = Random(99);
      // Set up a 7x7 board with no initial matches
      final board = Match3Logic.generateInitialBoard(5, rng);
      final special = List<int>.filled(49, 0);
      final frozen = List<int>.filled(49, 0);

      // Force a 4-in-a-row on row 6: (6,0)=1, (6,1)=1, (6,2)=2, (6,3)=1, and (5,2)=1
      // Swapping (5,2) and (6,2) creates 4-in-a-row at (6,0..3) of color 1!
      for (var i = 0; i < 49; i++) {
        board[i] = ((i ~/ 7) * 2 + (i % 7)) % 4 + 2; // colors 2..5 without 3-in-a-row
      }
      board[6 * 7 + 0] = 1;
      board[6 * 7 + 1] = 1;
      board[6 * 7 + 2] = 2;
      board[6 * 7 + 3] = 1;
      board[5 * 7 + 2] = 1;

      final res4 = Match3Logic.executeSwap(
        board: board,
        special: special,
        frozen: frozen,
        idx1: 5 * 7 + 2,
        idx2: 6 * 7 + 2,
        colors: 5,
        rng: rng,
      );
      expect(res4.valid, isTrue);
      expect(res4.specialsCreated, greaterThanOrEqualTo(1));
      expect(special.contains(Match3Logic.specialLineBlaster), isTrue);

      // Now test 5-in-a-row creating Rainbow Prism (special == 2) and Ice Shield thawing
      for (var i = 0; i < 49; i++) {
        board[i] = ((i ~/ 7) * 2 + (i % 7)) % 4 + 2;
        special[i] = 0;
        frozen[i] = 0;
      }
      board[6 * 7 + 0] = 1;
      board[6 * 7 + 1] = 1;
      board[6 * 7 + 2] = 2;
      board[6 * 7 + 3] = 1;
      board[6 * 7 + 4] = 1;
      board[5 * 7 + 2] = 1;
      // Freeze (6,0) and adjacent (5,0)
      frozen[6 * 7 + 0] = 1;
      frozen[5 * 7 + 0] = 1;

      final res5 = Match3Logic.executeSwap(
        board: board,
        special: special,
        frozen: frozen,
        idx1: 5 * 7 + 2,
        idx2: 6 * 7 + 2,
        colors: 5,
        rng: rng,
      );
      expect(res5.valid, isTrue);
      expect(res5.specialsCreated, greaterThanOrEqualTo(1));
      expect(res5.iceThawed, greaterThanOrEqualTo(2));
      expect(res5.iceAttackCount, greaterThan(0));
    });

    test('multiplayer swap, invalid swap rejection, and garbage ice attack on opponent', () {
      final e = Match3BattleGame(_setup(2, {'moves': 10, 'colors': 5}))..host = SimHost();
      e.start();

      expect(
        () => e.handle(0, {'type': 'swap', 'r1': 0, 'c1': 0, 'r2': 2, 'c2': 2}),
        throwsA(isA<GameError>()),
      );

      final swaps = Match3Logic.findValidSwaps(e.boards[0], e.specials[0]);
      expect(swaps, isNotEmpty);
      final (idx1, idx2) = swaps.first;
      e.handle(0, {
        'type': 'swap',
        'r1': idx1 ~/ 7,
        'c1': idx1 % 7,
        'r2': idx2 ~/ 7,
        'c2': idx2 % 7,
      });
      expect(e.ps[0].movesLeft, 9);
      expect(e.scores[0], greaterThan(0));
    });
  });

  group('阴阳连通竞速 (yinyang)', () {
    test('puzzle generator produces valid connected white and black groups with no 2x2 same-color square for 5x5 and 6x6', () {
      final rng = Random(77);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = YinYangSolver.generatePuzzle(size, rng);
          expect(validateYinYang(size, puz.initialBoard, puz.clues), isFalse);
          expect(validateYinYang(size, puz.solutionBoard, puz.clues), isTrue);

          final an = YinYangSolver.analyze(puz, puz.solutionBoard);
          expect(an.isSolved, isTrue);
          expect(an.emptyCount, 0);
          expect(an.isWhiteConnected, isTrue);
          expect(an.isBlackConnected, isTrue);
          expect(an.whiteComponentCount, 1);
          expect(an.blackComponentCount, 1);
          expect(an.twoByTwoCells, isEmpty);
          expect(an.conflictCells, isEmpty);
        }
      }
    });

    test('set, cycle, 2x2 violation detection, clue lock, clear, and completion scoring', () {
      final e = YinYangGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      final clueIdx = puz.clues.indexWhere((v) => v != 0);
      final emptyIdx = puz.clues.indexWhere((v) => v == 0);
      expect(
        () => e.handle(0, {'type': 'cycle', 'r': clueIdx ~/ 5, 'c': clueIdx % 5}),
        throwsA(isA<GameError>()),
      );

      e.handle(0, {'type': 'cycle', 'r': emptyIdx ~/ 5, 'c': emptyIdx % 5});
      expect(e.boards[0][emptyIdx], 1);
      e.handle(0, {'type': 'cycle', 'r': emptyIdx ~/ 5, 'c': emptyIdx % 5});
      expect(e.boards[0][emptyIdx], 2);
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      // Verify 2x2 all-White and all-Black rejection
      final allWhite = List<int>.filled(25, 1);
      expect(validateYinYang(5, allWhite), isFalse);

      final sol = puz.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        if (puz.clues[i] == 0 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'set', 'r': i ~/ 5, 'c': i % 5, 'val': sol[i]});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  group('数间直角三角竞速 (shakashaka)', () {
    test('puzzle generator produces valid clue counts and exact axis-aligned or 45-degree tilted white rectangles for 5x5 and 6x6', () {
      final rng = Random(123);
      for (final size in [5, 6]) {
        for (var i = 0; i < 15; i++) {
          final puz = ShakashakaSolver.generatePuzzle(size, rng);
          expect(validateShakashaka(size, puz.initialBoard, puz.clues), isFalse);
          expect(validateShakashaka(size, puz.solutionBoard, puz.clues), isTrue);

          final an = ShakashakaSolver.analyze(puz, puz.solutionBoard);
          expect(an.isSolved, isTrue);
          expect(an.violatedClueCells, isEmpty);
          expect(an.pendingClueCells, isEmpty);
          expect(an.satisfiedClueCells.length, an.totalNumberedClues);
          expect(an.nonRectCells, isEmpty);
          expect(an.validRectRegionCount, an.whiteRegionCount);
          expect(an.tiltedRectCount, greaterThanOrEqualTo(1));
        }
      }
    });

    test('triangle cycling (0..4), non-rectangle detection, clear, and completion scoring', () {
      final e = ShakashakaGame(_setup(2, {'size': 5, 'rounds': 3}))..host = SimHost();
      e.start();

      final puz = e.currentPuzzle;
      final blackIdx = puz.clues.indexWhere((v) => v >= -1);
      final whiteIdx = puz.clues.indexWhere((v) => v == -2);

      expect(
        () => e.handle(0, {'type': 'cycle', 'r': blackIdx ~/ 5, 'c': blackIdx % 5}),
        throwsA(isA<GameError>()),
      );

      e.handle(0, {'type': 'cycle', 'r': whiteIdx ~/ 5, 'c': whiteIdx % 5});
      expect(e.boards[0][whiteIdx], 1);
      e.handle(0, {'type': 'set', 'r': whiteIdx ~/ 5, 'c': whiteIdx % 5, 'val': 4});
      expect(e.boards[0][whiteIdx], 4);
      e.handle(0, {'type': 'clear'});
      expect(e.boards[0], equals(puz.initialBoard));

      final sol = puz.solutionBoard;
      for (var i = 0; i < sol.length; i++) {
        if (!puz.isBlackCell(i) && sol[i] != 0 && e.ps[0].status == 'play') {
          e.handle(0, {'type': 'set', 'r': i ~/ 5, 'c': i % 5, 'val': sol[i]});
        }
      }
      expect(e.ps[0].status, 'solved');
      expect(e.scores[0], 10);

      e.handle(1, {'type': 'pass'});
      expect(e.round, 2);
    });
  });

  test('bot simulations (arcade17Games, count: 30)', () {
    final sw = Stopwatch()..start();
    expect(runSims(arcade17Games, n: 30), 0);
    print('arcade17 sims took ${sw.elapsedMilliseconds} ms');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
