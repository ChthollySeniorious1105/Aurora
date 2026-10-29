import 'dart:math';

import 'package:aurora_shared/games/abstract10/defs.dart';
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
  group('TwixT (twixt) unit tests', () {
    test('corner & border restrictions, knight-move bridges, and non-crossing rule', () {
      final g = TwixtGame(_setup(options: {'size': 10}));
      g.start();
      expect(g.size, 10);

      // Corners are forbidden for both players
      expect(
        () => g.handle(0, {'type': 'place', 'r': 0, 'c': 0}),
        throwsA(isA<GameError>()),
      );
      expect(
        () => g.handle(0, {'type': 'place', 'r': 0, 'c': 9}),
        throwsA(isA<GameError>()),
      );

      // Player 0 (Red) cannot place on left/right border columns (c == 0 or c == 9)
      expect(
        () => g.handle(0, {'type': 'place', 'r': 3, 'c': 0}),
        throwsA(isA<GameError>()),
      );

      // Player 0 places on top border (0, 2)
      g.handle(0, {'type': 'place', 'r': 0, 'c': 2});
      expect(g.board[0][2], 1);
      expect(g.turn, 1);

      // Player 1 (Black) cannot place on top/bottom border rows (r == 0 or r == 9)
      expect(
        () => g.handle(1, {'type': 'place', 'r': 0, 'c': 4}),
        throwsA(isA<GameError>()),
      );

      // Player 1 places at (1, 1)
      g.handle(1, {'type': 'place', 'r': 1, 'c': 1});
      expect(g.board[1][1], 2);

      // Player 0 places at (2, 3) -> knight move (+2, +1) from (0, 2) -> creates 1 Red bridge!
      g.handle(0, {'type': 'place', 'r': 2, 'c': 3});
      expect(g.bridges.length, 1);
      expect(g.bridges.first[4], 0);

      // Player 1 places at (2, 3) is occupied -> error
      expect(
        () => g.handle(1, {'type': 'place', 'r': 2, 'c': 3}),
        throwsA(isA<GameError>()),
      );

      // Player 1 places at (0, 4) is illegal, so Player 1 places at (2, 4) -> wait:
      // Segment from (1, 1) to (2, 3) is occupied; what about (1, 1) to (2, 3)?
      // Let's test crossing: Red bridge is (0, 2)-(2, 3).
      // If Black has a peg at (1, 4) and places at (2, 2), segment (1, 4)-(2, 2) crosses (0, 2)-(2, 3)!
      g.handle(1, {'type': 'place', 'r': 1, 'c': 4});
      expect(g.bridges.length, 1); // (1,1)-(1,4) is not a knight move

      // Red places somewhere away, e.g. (5, 5)
      g.handle(0, {'type': 'place', 'r': 5, 'c': 5});
      expect(g.bridges.length, 1);

      // Black places at (2, 2): knight move from (1, 4), but (2, 2)-(1, 4) crosses Red bridge (0, 2)-(2, 3)!
      g.handle(1, {'type': 'place', 'r': 2, 'c': 2});
      // Because (2, 2)-(1, 4) intersects (0, 2)-(2, 3), no Black bridge is added!
      expect(g.bridges.where((b) => b[4] == 1), isEmpty);
    });

    test('connected bridge chain from r=0 to r=N-1 wins immediately for Red', () {
      final g = TwixtGame(_setup(options: {'size': 10}));
      g.start();

      // Build a Red knight chain across a 10x10 board (r = 0 -> 2 -> 4 -> 6 -> 8 -> 9):
      // (0, 2) -> (2, 3) -> (4, 2) -> (6, 3) -> (8, 2) -> (9, 4)
      final redMoves = [
        (0, 2),
        (2, 3),
        (4, 2),
        (6, 3),
        (8, 2),
        (9, 4),
      ];
      for (var i = 0; i < redMoves.length; i++) {
        final (rr, rc) = redMoves[i];
        g.handle(0, {'type': 'place', 'r': rr, 'c': rc});
        if (i < redMoves.length - 1) {
          expect(g.isOver, isFalse);
          // Black plays harmless moves on col 0/7
          g.handle(1, {'type': 'place', 'r': i + 1, 'c': 0});
        }
      }

      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.winReason, 'connect');
      expect(g.winningPath.first[0], 0);
      expect(g.winningPath.last[0], 9);
      expect(g.placings, [1, 2]);
    });
  });

  group('Epaminondas (epaminondas) unit tests', () {
    test('single stone movement vs phalanx movement and L > E phalanx capture', () {
      final g = EpaminondasGame(_setup(options: {'size': 'quick'}));
      g.start();
      expect(g.rows, 8);
      expect(g.cols, 10);
      expect(g.stoneCount(0), 20);
      expect(g.stoneCount(1), 20);

      // Single stone (L=1) cannot move 2 steps
      expect(
        () => g.handle(0, {
          'type': 'move',
          'r': 6,
          'c': 0,
          'dr': -1,
          'dc': 0,
          'len': 1,
          'steps': 2,
        }),
        throwsA(isA<GameError>()),
      );

      // Set up a tactical test board
      for (var r = 0; r < g.rows; r++) {
        for (var c = 0; c < g.cols; c++) {
          g.board[r][c] = 0;
        }
      }
      // White (P0 = 1) has a 3-stone vertical phalanx at (6, 2), (5, 2), (4, 2)
      g.board[6][2] = 1;
      g.board[5][2] = 1;
      g.board[4][2] = 1;
      // Black (P1 = 2) has a 2-stone vertical line at (2, 2), (1, 2)
      g.board[2][2] = 2;
      g.board[1][2] = 2;
      // Also give Black a 2-stone line at (4, 5), (4, 6) and White a 2-stone phalanx at (4, 3), (4, 4)
      g.board[4][3] = 1;
      g.board[4][4] = 1;
      g.board[4][5] = 2;
      g.board[4][6] = 2;

      // 1. Equal length phalanx (L=2 vs E=2) CANNOT capture!
      expect(
        () => g.handle(0, {
          'type': 'move',
          'r': 4,
          'c': 3,
          'dr': 0,
          'dc': 1,
          'len': 2,
          'steps': 1,
        }),
        throwsA(isA<GameError>()),
      );

      // 2. Single stone (L=1) CANNOT capture!
      expect(
        () => g.handle(0, {
          'type': 'move',
          'r': 4,
          'c': 4,
          'dr': 0,
          'dc': 1,
          'len': 1,
          'steps': 1,
        }),
        throwsA(isA<GameError>()),
      );

      // 3. Strictly longer phalanx (L=3 vs E=2) at col 2 moves 2 steps up (s=2) and crushes BOTH Black stones at (2, 2) and (1, 2)!
      g.handle(0, {
        'type': 'move',
        'r': 6,
        'c': 2,
        'dr': -1,
        'dc': 0,
        'len': 3,
        'steps': 2,
      });
      // White phalanx shifted from (6,2),(5,2),(4,2) by 2 steps to (4,2),(3,2),(2,2)
      expect(g.board[6][2], 0);
      expect(g.board[5][2], 0);
      expect(g.board[4][2], 1);
      expect(g.board[3][2], 1);
      expect(g.board[2][2], 1);
      // Both Black stones at (2, 2) and (1, 2) were crushed!
      expect(g.board[1][2], 0);
      expect(g.captured[0], 2);
    });

    test('start-of-turn back rank win condition gives opponent 1 response turn', () {
      final g = EpaminondasGame(_setup(options: {'size': 'quick'}));
      g.start();
      for (var r = 0; r < g.rows; r++) {
        for (var c = 0; c < g.cols; c++) {
          g.board[r][c] = 0;
        }
      }
      // White (P0 = 1) at (1, 0), Black (P1 = 2) at (3, 5)
      g.board[1][0] = 1;
      g.board[3][5] = 2;

      // White moves (1, 0) -> (0, 0) (reaches Black's back rank!)
      g.handle(0, {'type': 'move', 'from': [1, 0], 'to': [0, 0], 'len': 1});
      // Game is NOT over yet because Black gets 1 turn to respond!
      expect(g.isOver, isFalse);
      expect(g.turn, 1);

      // Black moves (3, 5) -> (4, 5) (fails to capture or equalize on White's back rank)
      g.handle(1, {'type': 'move', 'from': [3, 5], 'to': [4, 5], 'len': 1});
      // Now at the start of White's turn, White has 1 stone on r=0 vs Black's 0 on r=7 -> White wins!
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.winReason, 'back_rank');
      expect(g.placings, [1, 2]);
    });
  });

  group('Neutreeko (neutreeko) unit tests', () {
    test('initial setup, ice-slide full-slide enforcement, and 3-in-a-row win', () {
      final g = NeutreekoGame(_setup());
      g.start();
      expect(g.board[0][1], 1);
      expect(g.board[0][3], 1);
      expect(g.board[3][2], 1);
      expect(g.board[4][1], 2);
      expect(g.board[4][3], 2);
      expect(g.board[1][2], 2);

      // Piece at (0, 1) sliding down (dr=1, dc=0) must slide all the way to (3, 1) (stopped by White at (4, 1)).
      // Stopping early at (2, 1) is illegal!
      expect(
        () => g.handle(0, {'type': 'slide', 'from': [0, 1], 'to': [2, 1]}),
        throwsA(isA<GameError>()),
      );

      // Sliding (0, 1) all the way to (3, 1) succeeds:
      g.handle(0, {'type': 'slide', 'from': [0, 1], 'to': [3, 1]});
      expect(g.board[0][1], 0);
      expect(g.board[3][1], 1);
      expect(g.turn, 1);

      // White slides (1, 2) left to (1, 0)
      g.handle(1, {'type': 'slide', 'from': [1, 2], 'to': [1, 0]});
      expect(g.board[1][0], 2);
      expect(g.turn, 0);

      // Now Black slides (0, 3) down to (3, 3) (stopped by White at (4, 3)).
      // Black now has pieces at (3, 1), (3, 2), (3, 3) -> contiguous 3-in-a-row!
      g.handle(0, {'type': 'slide', 'from': [0, 3], 'to': [3, 3]});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.winReason, 'three');
      expect(g.winningLine.length, 3);
      expect(g.placings, [1, 2]);
    });
  });

  test('simulate 30 full bot games for all abstract10Games options and bot levels', () {
    final failures = runSims(abstract10Games, n: 30);
    expect(failures, 0);
  });
}
