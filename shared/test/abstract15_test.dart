import 'dart:math';

import 'package:aurora_shared/games/abstract15/defs.dart';
import 'package:aurora_shared/games/abstract15/dipole.dart';
import 'package:aurora_shared/games/abstract15/otrio.dart';
import 'package:aurora_shared/games/abstract15/slither.dart';
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
  test('abstract15: bots finish every variant (count: 30)', () {
    expect(runSims(abstract15Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));

  group('otrio', () {
    test('initial reserve and concentric nest in 1 cell win', () {
      final g = OtrioGame(_setup(3))..start();
      expect(g.reserve, [
        [3, 3, 3],
        [3, 3, 3],
        [3, 3, 3],
      ]);

      // P0 places Small (0) at (1, 1)
      g.handle(0, {'type': 'place', 'r': 1, 'c': 1, 'size': 0});
      expect(g.rings[1][1][0], 1);
      expect(g.reserve[0], [2, 3, 3]);

      // P1 cannot place Small (0) at occupied (1, 1, 0)
      expect(
        () => g.handle(1, {'type': 'place', 'r': 1, 'c': 1, 'size': 0}),
        throwsA(isA<GameError>()),
      );

      g.handle(1, {'type': 'place', 'r': 0, 'c': 0, 'size': 0});
      g.handle(2, {'type': 'place', 'r': 0, 'c': 2, 'size': 0});

      // P0 places Medium (1) at (1, 1)
      g.handle(0, {'type': 'place', 'r': 1, 'c': 1, 'size': 1});
      g.handle(1, {'type': 'place', 'r': 0, 'c': 0, 'size': 1});
      g.handle(2, {'type': 'place', 'r': 0, 'c': 2, 'size': 1});

      // P0 places Large (2) at (1, 1) -> Concentric Nest in 1 cell!
      g.handle(0, {'type': 'place', 'r': 1, 'c': 1, 'size': 2});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.winKind, 'concentric');
      expect(g.placings, [1, 2, 2]);
    });

    test('same-size 3-in-a-row and ordered-size 3-in-a-row wins', () {
      // 1. Same-Size 3-in-a-Row along a row
      final g1 = OtrioGame(_setup(2))..start();
      g1.handle(0, {'type': 'place', 'r': 0, 'c': 0, 'size': 2});
      g1.handle(1, {'type': 'place', 'r': 1, 'c': 0, 'size': 0});
      g1.handle(0, {'type': 'place', 'r': 0, 'c': 1, 'size': 2});
      g1.handle(1, {'type': 'place', 'r': 1, 'c': 1, 'size': 0});
      g1.handle(0, {'type': 'place', 'r': 0, 'c': 2, 'size': 2});
      expect(g1.isOver, isTrue);
      expect(g1.winner, 0);
      expect(g1.winKind, 'same_size');

      // 2. Ordered-Size 3-in-a-Row descending [2, 1, 0] along a diagonal
      final g2 = OtrioGame(_setup(2))..start();
      g2.handle(0, {'type': 'place', 'r': 0, 'c': 0, 'size': 1});
      g2.handle(1, {'type': 'place', 'r': 0, 'c': 2, 'size': 2}); // Large at (0, 2)
      g2.handle(0, {'type': 'place', 'r': 2, 'c': 2, 'size': 0});
      g2.handle(1, {'type': 'place', 'r': 1, 'c': 1, 'size': 1}); // Medium at (1, 1)
      g2.handle(0, {'type': 'place', 'r': 2, 'c': 1, 'size': 0});
      g2.handle(1, {'type': 'place', 'r': 2, 'c': 0, 'size': 0}); // Small at (2, 0)
      expect(g2.isOver, isTrue);
      expect(g2.winner, 1);
      expect(g2.winKind, 'ordered_size');
      expect(g2.placings, [2, 1]);
    });
  });

  group('dipole', () {
    test('initial setup, dark-square distance==count movement, and stack merging', () {
      final d = DipoleGame(_setup(2))..start();
      expect(d.owner[7][4], 1);
      expect(d.counts[7][4], 12);
      expect(d.owner[0][3], 2);
      expect(d.counts[0][3], 12);

      // Orthogonal distance 1 lands on a light square -> illegal
      expect(
        () => d.handle(0, {'type': 'move', 'fromR': 7, 'fromC': 4, 'toR': 6, 'toC': 4, 'count': 1}),
        throwsA(isA<GameError>()),
      );

      // Diagonal forward move with count == 2 from (7, 4) to (5, 2)
      d.handle(0, {'type': 'move', 'fromR': 7, 'fromC': 4, 'toR': 5, 'toC': 2, 'count': 2});
      expect(d.counts[7][4], 10);
      expect(d.owner[5][2], 1);
      expect(d.counts[5][2], 2);

      // Player 1 moves orthogonal forward (down) with count == 2 from (0, 3) to (2, 3)
      d.handle(1, {'type': 'move', 'fromR': 0, 'fromC': 3, 'toR': 2, 'toC': 3, 'count': 2});
      expect(d.counts[0][3], 10);
      expect(d.owner[2][3], 2);
      expect(d.counts[2][3], 2);

      // Player 0 cannot move backward without capturing
      expect(
        () => d.handle(0, {'type': 'move', 'fromR': 5, 'fromC': 2, 'toR': 6, 'toC': 3, 'count': 1}),
        throwsA(isA<GameError>()),
      );

      // Player 0 can merge another 2 checkers from (7, 4) onto (5, 2)
      d.handle(0, {'type': 'move', 'fromR': 7, 'fromC': 4, 'toR': 5, 'toC': 2, 'count': 2});
      expect(d.counts[7][4], 8);
      expect(d.counts[5][2], 4);
    });

    test('backward and forward capture require count >= enemy stack size and elimination wins', () {
      final d = DipoleGame(_setup(2))..start();
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          d.setStack(r, c, 0, 0);
        }
      }
      // Place Player 0 stack of 4 at (3, 4), and Player 1 stack of 2 behind it at (5, 2)
      d.setStack(3, 4, 1, 4);
      d.setStack(5, 2, 2, 2);
      // Also a larger Player 1 stack of 3 at (4, 5) (distance 1 diagonally from (3, 4))
      d.setStack(4, 5, 2, 3);

      // Cannot capture (4, 5) at distance 1 because count == 1 < enemy stack size 3!
      expect(
        () => d.handle(0, {'type': 'capture', 'fromR': 3, 'fromC': 4, 'toR': 4, 'toC': 5, 'count': 1}),
        throwsA(isA<GameError>()),
      );

      // Can capture backward diagonally from (3, 4) to (5, 2) with count == 2 >= enemy size 2!
      d.handle(0, {'type': 'capture', 'fromR': 3, 'fromC': 4, 'toR': 5, 'toC': 2, 'count': 2});
      expect(d.owner[5][2], 1);
      expect(d.counts[5][2], 2);
      expect(d.counts[3][4], 2);
      expect(d.captured[0], 2);

      // Player 1 moves 3 checkers from (4, 5) sideways/forward to (6, 3) (distance 2, leaving 1 at (4, 5))
      d.handle(1, {'type': 'move', 'fromR': 4, 'fromC': 5, 'toR': 6, 'toC': 3, 'count': 2});
      expect(d.counts[4][5], 1);
      expect(d.counts[6][3], 2);

      // Remove (6, 3) so (4, 5) is the last enemy checker, then Player 0 captures (4, 5) from (3, 4) with count 1!
      d.setStack(6, 3, 0, 0);
      d.handle(0, {'type': 'capture', 'fromR': 3, 'fromC': 4, 'toR': 4, 'toC': 5, 'count': 1});
      expect(d.isOver, isTrue);
      expect(d.winner, 0);
      expect(d.placings, [1, 2]);
    });
  });

  group('slither', () {
    test('no-diagonal-touch invariant and slide+place repairing diagonal to win', () {
      final s = SlitherGame(_setup(2, {'mode': 'quick'}))..start();
      expect(s.boardSize, 6);

      // Player 0 places at (1, 1)
      s.handle(0, {
        'type': 'turn',
        'fromR': -1,
        'fromC': -1,
        'toR': -1,
        'toC': -1,
        'placeR': 1,
        'placeC': 1,
      });
      expect(s.board[1][1], 1);

      // Player 1 places at (0, 5)
      s.handle(1, {
        'type': 'turn',
        'fromR': -1,
        'fromC': -1,
        'toR': -1,
        'toC': -1,
        'placeR': 0,
        'placeC': 5,
      });

      // Player 0 cannot place directly at (2, 2) without sliding because (1, 1) and (2, 2)
      // would touch diagonally with neither (1, 2) nor (2, 1) holding color 1!
      expect(
        () => s.handle(0, {
          'type': 'turn',
          'fromR': -1,
          'fromC': -1,
          'toR': -1,
          'toC': -1,
          'placeR': 2,
          'placeC': 2,
        }),
        throwsA(isA<GameError>()),
      );

      // However, Player 0 CAN slide (1, 1) -> (1, 2) and place at (2, 2) in the same turn!
      s.handle(0, {
        'type': 'turn',
        'fromR': 1,
        'fromC': 1,
        'toR': 1,
        'toC': 2,
        'placeR': 2,
        'placeC': 2,
      });
      expect(s.board[1][1], 0);
      expect(s.board[1][2], 1);
      expect(s.board[2][2], 1);

      // Set up Player 0 almost connected from Top (r=0) to Bottom (r=5) on column 2
      s.board[0][2] = 1;
      s.board[3][2] = 1;
      s.board[4][2] = 1;
      // Player 1 takes a legal turn
      s.handle(1, {
        'type': 'turn',
        'fromR': -1,
        'fromC': -1,
        'toR': -1,
        'toC': -1,
        'placeR': 0,
        'placeC': 4,
      });

      // Player 0 places at (5, 2) to complete Top-to-Bottom orthogonal chain!
      s.handle(0, {
        'type': 'turn',
        'fromR': -1,
        'fromC': -1,
        'toR': -1,
        'toC': -1,
        'placeR': 5,
        'placeC': 2,
      });
      expect(s.isOver, isTrue);
      expect(s.winner, 0);
      expect(s.winChain, isNotNull);
      expect(s.placings, [1, 2]);
    });
  });
}
