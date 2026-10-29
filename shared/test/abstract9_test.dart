import 'dart:math';

import 'package:aurora_shared/games/abstract9/defs.dart';
import 'package:aurora_shared/src/engine.dart';
import 'package:aurora_shared/src/simulate.dart';
import 'package:test/test.dart';

GameSetup _setup({
  Map<String, dynamic> options = const {},
  int seed = 42,
}) =>
    GameSetup(
      players: 2,
      options: options,
      names: const ['Alice', 'Bob'],
      bots: const [false, false],
      hostSeat: 0,
      rng: Random(seed),
    );

void main() {
  group('Pente (pente) unit tests', () {
    test('board initialization, custodial pair capture, multi-capture & safe between-enemy placement', () {
      final g = PenteGame(_setup(options: {'size': 13, 'targetPairs': 5}));
      g.start();
      expect(g.size, 13);
      expect(g.targetPairs, 5);
      expect(g.board.length, 13);

      // Set up a horizontal pair capture and a diagonal pair capture simultaneously when Black plays at (6, 6):
      // Horizontal: Black at (6, 3), White at (6, 4) and (6, 5)
      g.board[6][3] = 1;
      g.board[6][4] = 2;
      g.board[6][5] = 2;
      // Diagonal: Black at (3, 3), White at (4, 4) and (5, 5)
      g.board[3][3] = 1;
      g.board[4][4] = 2;
      g.board[5][5] = 2;
      // 3-stone enemy line should NOT be captured: Black at (6, 10), White at (6, 7), (6, 8), (6, 9)
      g.board[6][7] = 2;
      g.board[6][8] = 2;
      g.board[6][9] = 2;
      g.board[6][10] = 1;

      g.handle(0, {'type': 'place', 'r': 6, 'c': 6});
      expect(g.board[6][6], 1);
      // Both pairs removed!
      expect(g.board[6][4], 0);
      expect(g.board[6][5], 0);
      expect(g.board[4][4], 0);
      expect(g.board[5][5], 0);
      // 3-stone group remains untouched
      expect(g.board[6][7], 2);
      expect(g.board[6][8], 2);
      expect(g.board[6][9], 2);
      expect(g.capturedPairs[0], 2);
      expect(g.turn, 1);

      // Test safe placement between enemy stones: opp - me - me - opp does NOT self-capture
      // Suppose Black is at (2, 2) and (2, 5), White is already at (2, 3), and White plays at (2, 4)
      g.board[2][2] = 1;
      g.board[2][3] = 2;
      g.board[2][5] = 1;
      g.handle(1, {'type': 'place', 'r': 2, 'c': 4});
      expect(g.board[2][3], 2);
      expect(g.board[2][4], 2);
      expect(g.capturedPairs[0], 2);
      expect(g.capturedPairs[1], 0);
    });

    test('dual win conditions: 5-in-a-row win & targetPairs capture win', () {
      // 1. 5-in-a-row win
      final g1 = PenteGame(_setup(options: {'size': 11, 'targetPairs': 4}));
      g1.start();
      for (var c = 0; c < 4; c++) {
        g1.board[5][c] = 1;
      }
      g1.handle(0, {'type': 'place', 'r': 5, 'c': 4});
      expect(g1.isOver, isTrue);
      expect(g1.winner, 0);
      expect(g1.winReason, 'five');
      expect(g1.winningLine.length, 5);
      expect(g1.placings, [1, 2]);

      // 2. Capture targetPairs win
      final g2 = PenteGame(_setup(options: {'size': 11, 'targetPairs': 4}));
      g2.start();
      g2.capturedPairs[0] = 3;
      g2.board[0][0] = 1;
      g2.board[0][1] = 2;
      g2.board[0][2] = 2;
      g2.handle(0, {'type': 'place', 'r': 0, 'c': 3});
      expect(g2.capturedPairs[0], 4);
      expect(g2.isOver, isTrue);
      expect(g2.winner, 0);
      expect(g2.winReason, 'capture');
    });
  });

  group('Entropy (entropy) unit tests', () {
    test('palindrome scoring rules on rows and columns', () {
      expect(EntropyGame.scoreLine([1, 1, 0, 0, 0]), 2);
      expect(EntropyGame.scoreLine([1, 2, 1, 0, 0]), 3);
      // [3, 1, 1, 3] has inner [1, 1] (2 pts) + outer [3, 1, 1, 3] (4 pts) = 6 pts
      expect(EntropyGame.scoreLine([3, 1, 1, 3, 0]), 6);
      // Empty cells break palindromes
      expect(EntropyGame.scoreLine([1, 0, 1, 0, 0]), 0);
    });

    test('Chaos placement, Order orthogonal slide & pass, and 2-half role swap', () {
      final g = EntropyGame(_setup(options: {'size': 5, 'halves': 2}));
      g.start();
      expect(g.half, 1);
      expect(g.chaosSeat, 0);
      expect(g.orderSeat, 1);
      expect(g.phase, 'chaos');

      // Chaos places first tile at (0, 0)
      final firstColor = g.currentTile;
      g.handle(0, {'type': 'place', 'r': 0, 'c': 0});
      expect(g.board[0][0], firstColor);
      expect(g.phase, 'order');
      expect(g.turn, 1);

      // Order cannot slide diagonally
      expect(
        () => g.handle(1, {'type': 'slide', 'fromR': 0, 'fromC': 0, 'toR': 1, 'toC': 1}),
        throwsA(isA<GameError>()),
      );

      // Order slides (0, 0) orthogonally across empty cells to (0, 4)
      g.handle(1, {'type': 'slide', 'fromR': 0, 'fromC': 0, 'toR': 0, 'toC': 4});
      expect(g.board[0][0], 0);
      expect(g.board[0][4], firstColor);
      expect(g.phase, 'chaos');
      expect(g.turn, 0);

      // Chaos places second tile at (0, 2); Order cannot slide (0, 4) past (0, 2) to (0, 0)
      g.handle(0, {'type': 'place', 'r': 0, 'c': 2});
      expect(
        () => g.handle(1, {'type': 'slide', 'fromR': 0, 'fromC': 4, 'toR': 0, 'toC': 0}),
        throwsA(isA<GameError>()),
      );
      // Order can pass
      g.handle(1, {'type': 'pass'});
      expect(g.phase, 'chaos');
    });
  });

  group('Konane (konane) unit tests', () {
    test('opening removal restrictions and orthogonal single & multi-jump captures', () {
      final g = KonaneGame(_setup(options: {'size': 6}));
      g.start();
      expect(g.phase, 'remove_black');
      expect(g.board[0][0], 1);
      expect(g.board[0][1], 2);

      // Black (seat 0) cannot remove a non-center, non-corner stone like (0, 2)
      expect(
        () => g.handle(0, {'type': 'remove', 'r': 0, 'c': 2}),
        throwsA(isA<GameError>()),
      );

      // Black removes center Black stone at (2, 2)
      g.handle(0, {'type': 'remove', 'r': 2, 'c': 2});
      expect(g.board[2][2], 0);
      expect(g.phase, 'remove_white');
      expect(g.turn, 1);

      // White (seat 1) cannot remove a non-adjacent White stone like (0, 1)
      expect(
        () => g.handle(1, {'type': 'remove', 'r': 0, 'c': 1}),
        throwsA(isA<GameError>()),
      );

      // White removes orthogonally adjacent White stone at (2, 3)
      g.handle(1, {'type': 'remove', 'r': 2, 'c': 3});
      expect(g.board[2][3], 0);
      expect(g.phase, 'jump');
      expect(g.turn, 0);

      // Set up a double-jump in the same straight orthogonal direction:
      // Clear row 0 and place Black at (0, 0), White at (0, 1) and (0, 3), empty at (0, 2) and (0, 4)
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < 6; c++) {
          g.board[r][c] = 0;
        }
      }
      g.board[0][0] = 1;
      g.board[0][1] = 2;
      g.board[0][3] = 2;

      // Black multi-jumps from (0, 0) to (0, 4), capturing both (0, 1) and (0, 3)!
      g.handle(0, {
        'type': 'jump',
        'fromR': 0,
        'fromC': 0,
        'toR': 0,
        'toC': 4,
      });
      expect(g.board[0][0], 0);
      expect(g.board[0][1], 0);
      expect(g.board[0][3], 0);
      expect(g.board[0][4], 1);
      expect(g.captured[0], 2);

      // White now has 0 stones/jumps left -> Black wins immediately!
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.winReason, 'no_moves');
    });
  });

  test('simulate 30 full bot games for all abstract9Games options and bot levels', () {
    final failures = runSims(abstract9Games, n: 30);
    expect(failures, 0);
  });
}
