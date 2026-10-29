import 'dart:math';

import 'package:aurora_shared/games/abstract11/defs.dart';
import 'package:aurora_shared/games/abstract11/focus.dart';
import 'package:aurora_shared/games/abstract11/gipf.dart';
import 'package:aurora_shared/games/abstract11/kulami.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup(int players, [Map<String, dynamic> opts = const {}, int seed = 1]) => GameSetup(
      players: players,
      options: opts,
      names: [for (var i = 0; i < players; i++) 'P$i'],
      bots: List.filled(players, false),
      rng: Random(seed),
    );

void main() {
  test('abstract11: bots finish every variant (count: 30)', () {
    expect(runSims(abstract11Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));

  group('gipf', () {
    test('board geometry: 37 interior cells, 24 outer rim entry points, starting corners', () {
      expect(gipfInteriorCells.length, 37);
      expect(gipfRimCells.length, 24);
      final g = GipfGame(_setup(2))..start();
      expect(g.reserve, [15, 15]);
      expect(g.pieceAt(3, 0), 1);
      expect(g.pieceAt(0, 3), 2);
      expect(g.pieceAt(-3, 3), 1);
      expect(g.pieceAt(-3, 0), 2);
      expect(g.pieceAt(0, -3), 1);
      expect(g.pieceAt(3, -3), 2);

      final gQuick = GipfGame(_setup(2, {'mode': 'quick'}))..start();
      expect(gQuick.reserve, [12, 12]);
    });

    test('line shift and full-line rejection', () {
      final g = GipfGame(_setup(2))..start();
      for (final (q, r) in gipfInteriorCells) {
        g.setPieceAt(q, r, 0);
      }
      g.setPieceAt(3, 0, 1);
      g.setPieceAt(2, 0, 2);

      // Push from rim (4, 0) along (-1, 0): shifts (3,0)->(1,0)? Wait: (3,0)->(2,0) and (2,0)->(1,0)!
      g.handle(0, {'type': 'push', 'fromQ': 4, 'fromR': 0, 'dq': -1, 'dr': 0});
      expect(g.pieceAt(3, 0), 1); // newly pushed White piece
      expect(g.pieceAt(2, 0), 1); // shifted from (3, 0)
      expect(g.pieceAt(1, 0), 2); // shifted from (2, 0)
      expect(g.reserve[0], 14);

      // Fill entire line r = 0 from q = -3..3 with alternating pieces (no 4-in-a-row)
      final pattern = [1, 2, 1, 2, 1, 2, 1];
      for (var i = 0; i < 7; i++) {
        g.setPieceAt(-3 + i, 0, pattern[i]);
      }
      // Pushing along full line must fail
      expect(
        () => g.handle(1, {'type': 'push', 'fromQ': 4, 'fromR': 0, 'dq': -1, 'dr': 0}),
        throwsA(isA<GameError>()),
      );
    });

    test('4-in-a-row recycles own pieces and permanently captures contiguous enemy pieces', () {
      final g = GipfGame(_setup(2))..start();
      for (final (q, r) in gipfInteriorCells) {
        g.setPieceAt(q, r, 0);
      }
      // Line r = 0:
      // Place 3 White pieces at (2,0), (1,0), (0,0) and 2 Black pieces directly attached at (-1,0), (-2,0)
      g.setPieceAt(2, 0, 1);
      g.setPieceAt(1, 0, 1);
      g.setPieceAt(0, 0, 1);
      g.setPieceAt(-1, 0, 2);
      g.setPieceAt(-2, 0, 2);
      g.reserve[0] = 5;

      // White pushes from (4, 0) along (-1, 0) into (3, 0):
      // (3, 0) becomes 1, creating 4 White pieces at (3,0),(2,0),(1,0),(0,0) connected to 2 Black at (-1,0),(-2,0)!
      g.handle(0, {'type': 'push', 'fromQ': 4, 'fromR': 0, 'dq': -1, 'dr': 0});

      // White spent 1 from reserve (5 -> 4), then recycled 4 White pieces (4 + 4 = 8)!
      expect(g.reserve[0], 8);
      // And captured the 2 contiguous Black pieces!
      expect(g.captured[0], 2);
      for (var q = -2; q <= 3; q++) {
        expect(g.pieceAt(q, 0), 0);
      }
    });

    test('player with 0 reserve at start of turn loses immediately', () {
      final g = GipfGame(_setup(2))..start();
      g.reserve[1] = 0;
      g.handle(0, {'type': 'push', 'fromQ': 4, 'fromR': -1, 'dq': -1, 'dr': 0});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2]);
    });
  });

  group('focus', () {
    test('board geometry: 52 playable cells in standard, 36 in quick, 18 White and 18 Black pieces', () {
      final f = FocusGame(_setup(2))..start();
      var playable = 0;
      var wCount = 0;
      var bCount = 0;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          if (f.isPlayable(r, c)) {
            playable++;
            for (final p in f.stackAt(r, c)) {
              if (p == 0) wCount++;
              if (p == 1) bCount++;
            }
          }
        }
      }
      expect(playable, 52);
      expect(wCount, 18);
      expect(bCount, 18);

      final fq = FocusGame(_setup(2, {'mode': 'quick'}))..start();
      var qPlayable = 0;
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < 6; c++) {
          if (fq.isPlayable(r, c)) qPlayable++;
        }
      }
      expect(qPlayable, 36);
    });

    test('stack movement distance equals moved piece count and 5-stack overflow recycles/captures', () {
      final f = FocusGame(_setup(2))..start();
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          f.board[r][c].clear();
        }
      }
      // At (2, 2), stack height 3 controlled by seat 0: [1, 0, 0] (bottom to top)
      f.board[2][2].addAll([1, 0, 0]);
      // At (2, 5), stack height 4: [1, 0, 1, 1] (bottom is 1, next is 0)
      f.board[2][5].addAll([1, 0, 1, 1]);
      // Ensure seat 1 also has a controlled stack so game doesn't end by 0 moves
      f.board[4][4].add(1);

      // Illegal: moving 3 pieces only 2 steps
      expect(
        () => f.handle(0, {'type': 'move', 'fromR': 2, 'fromC': 2, 'toR': 2, 'toC': 4, 'count': 3}),
        throwsA(isA<GameError>()),
      );

      // Legal: move all 3 pieces 3 steps E from (2, 2) to (2, 5)
      // Combined stack at (2, 5) has 4 + 3 = 7 pieces: [1, 0, 1, 1, 1, 0, 0]
      // Bottom 2 pieces overflow: first removed is 1 (opponent -> captured[0]++), second is 0 (own -> reserve[0]++)!
      f.handle(0, {'type': 'move', 'fromR': 2, 'fromC': 2, 'toR': 2, 'toC': 5, 'count': 3});
      expect(f.stackAt(2, 2), isEmpty);
      expect(f.stackAt(2, 5), [1, 1, 1, 0, 0]);
      expect(f.captured[0], 1);
      expect(f.reserve[0], 1);

      // Seat 1 moves
      f.handle(1, {'type': 'move', 'fromR': 4, 'fromC': 4, 'toR': 4, 'toC': 5, 'count': 1});

      // Seat 0 drops from reserve onto (2, 5) (height 5 -> 6, overflows bottom '1' -> captured[0] becomes 2!)
      f.handle(0, {'type': 'drop', 'r': 2, 'c': 5});
      expect(f.reserve[0], 0);
      expect(f.captured[0], 2);
      expect(f.stackAt(2, 5), [1, 1, 0, 0, 0]);
    });
  });

  group('kulami', () {
    test('17 rectangular planks cover all 64 holes with areas 2, 3, 4, 6', () {
      expect(kulamiPlankAreas.length, 17);
      expect(kulamiPlankAreas.reduce((a, b) => a + b), 64);
      final counts = List<int>.filled(17, 0);
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          final id = kulamiDefaultPlankGrid[r][c];
          expect(id, inInclusiveRange(0, 16));
          counts[id]++;
        }
      }
      expect(counts, kulamiPlankAreas);
    });

    test('cross-hair and two-plank restrictions', () {
      final k = KulamiGame(_setup(2))..start();
      // Turn 1: Player 0 places at (0, 0) on plank 0
      k.handle(0, {'type': 'place', 'r': 0, 'c': 0});
      expect(k.lastPlankId, 0);

      // Turn 2: Player 1 cannot place on plank 0 (e.g. (0, 1)), nor outside row 0 / col 0 (e.g. (3, 3))
      expect(() => k.handle(1, {'type': 'place', 'r': 0, 'c': 1}), throwsA(isA<GameError>()));
      expect(() => k.handle(1, {'type': 'place', 'r': 3, 'c': 3}), throwsA(isA<GameError>()));

      // Player 1 places at (0, 3) on plank 1
      k.handle(1, {'type': 'place', 'r': 0, 'c': 3});
      expect(k.prevPlankId, 0);
      expect(k.lastPlankId, 1);

      // Turn 3: Player 0 must play in row 0 or col 3, and cannot play on plank 1 (last) OR plank 0 (prev)!
      expect(() => k.handle(0, {'type': 'place', 'r': 0, 'c': 2}), throwsA(isA<GameError>())); // plank 0
      expect(() => k.handle(0, {'type': 'place', 'r': 1, 'c': 3}), throwsA(isA<GameError>())); // plank 1
      // Legal: (2, 3) is on plank 5 in col 3
      k.handle(0, {'type': 'place', 'r': 2, 'c': 3});
      expect(k.lastPlankId, 5);
      expect(k.prevPlankId, 1);
    });

    test('endgame scoring: plank majority, largest orthogonal territory, and 5+ line bonus', () {
      final k = KulamiGame(_setup(2))..start();
      // Give Player 0 a 5-in-a-row along row 0: (0,0),(0,1),(0,2),(0,3),(0,4)
      for (var c = 0; c < 5; c++) {
        k.board[0][c] = 0;
      }
      // Plank 0 (2x3, area 6) has 3 marbles of Player 0 -> won by Player 0 (+6)
      // Plank 1 (2x2, area 4) has 2 marbles of Player 0 -> won by Player 0 (+4)
      expect(k.computePlankScores(), [10, 0]);
      expect(k.computeLargestTerritory(0), 5);
      expect(k.computeLongestLine(0), 5);
      expect(k.computeLineBonus(0), 5);
      expect(k.computeTotalScores(), [20, 0]);

      k.resign(1);
      expect(k.isOver, isTrue);
      expect(k.placings, [1, 2]);
    });
  });
}
