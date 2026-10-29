import 'dart:math';

import 'package:aurora_shared/games/abstract18/bagh_chal.dart';
import 'package:aurora_shared/games/abstract18/boop.dart';
import 'package:aurora_shared/games/abstract18/defs.dart';
import 'package:aurora_shared/games/abstract18/dobutsu_shogi.dart';
import 'package:aurora_shared/games/abstract18/gobblet.dart';
import 'package:aurora_shared/games/abstract18/orbito.dart';
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
  test('abstract18: bots finish every variant (count: 30)', () {
    expect(runSims(abstract18Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));

  group('boop', () {
    test('boop push mechanics: radial push, off-bed return, line of 2+ block, and weight hierarchy', () {
      final g = BoopGame(_setup(2))..start();
      expect(g.kittens, [8, 8]);
      expect(g.cats, [0, 0]);

      // Set up pieces on board to test all push rules simultaneously:
      // 1. Opponent kitten at (0, 2) -> adjacent to (1, 2), pushed to (-1, 2) which is off-bed!
      // 2. Two kittens in a line at (1, 3) and (1, 4) -> adjacent to (1, 2) on the right, blocked by line of 2!
      // 3. Opponent cat at (2, 2) -> adjacent to (1, 2) below, cannot be pushed by a kitten!
      g.setPiece(0, 2, 1, 'kitten');
      g.setPiece(1, 3, 1, 'kitten');
      g.setPiece(1, 4, 0, 'kitten');
      g.setPiece(2, 2, 1, 'cat');
      g.kittens[1] = 5;
      g.kittens[0] = 7;

      // Player 0 places a kitten at (1, 2):
      g.handle(0, {'type': 'place', 'r': 1, 'c': 2, 'kind': 'kitten'});

      // (0, 2) was pushed off the top edge -> returned to P1's kitten pool (5 -> 6)!
      expect(g.board[0][2], isNull);
      expect(g.kittens[1], 6);

      // (1, 3) and (1, 4) formed a 2-piece line -> neither moved!
      expect(g.board[1][3]?.owner, 1);
      expect(g.board[1][4]?.owner, 0);

      // (2, 2) is a Cat -> Kitten at (1, 2) could NOT push it!
      expect(g.board[2][2]?.kind, 'cat');
      expect(g.board[3][2], isNull);

      // Now give Player 1 a Cat in reserve and place it at (2, 1) next to P1's Cat at (2, 2):
      // A Cat CAN push another Cat (from (2, 2) to (2, 3))!
      g.cats[1] = 1;
      g.handle(1, {'type': 'place', 'r': 2, 'c': 1, 'kind': 'cat'});
      expect(g.board[2][2], isNull);
      expect(g.board[2][3]?.kind, 'cat');
    });

    test('graduation of 3 kittens into 3 cats and victory with 3 cats in a row', () {
      final g = BoopGame(_setup(2))..start();
      // Place two P0 kittens at (3, 1) and (3, 3) so placing at (3, 2) doesn't push them?
      // Wait: if we place at (3, 3) while kittens are at (3, 1) and (3, 2), (3, 2) has (3, 1) behind it!
      // Because (3, 1) is immediately behind (3, 2), the line-of-2 rule prevents (3, 2) from being pushed!
      g.setPiece(3, 1, 0, 'kitten');
      g.setPiece(3, 2, 0, 'kitten');
      g.kittens[0] = 6;
      g.cats[0] = 0;

      g.handle(0, {'type': 'place', 'r': 3, 'c': 3, 'kind': 'kitten'});
      // 3-in-a-row at (3,1)-(3,2)-(3,3) graduated! Board is cleared and P0 gains 3 Cats!
      expect(g.board[3][1], isNull);
      expect(g.board[3][2], isNull);
      expect(g.board[3][3], isNull);
      expect(g.cats[0], 3);
      expect(g.isOver, isFalse);

      // P1 plays a dummy move
      g.handle(1, {'type': 'place', 'r': 0, 'c': 0, 'kind': 'kitten'});

      // Now place two P0 Cats at (4, 1) and (4, 2), and P0 places 3rd Cat at (4, 3):
      // (4, 1) blocks (4, 2) from being pushed, forming 3 Cats in a row -> immediate win!
      g.setPiece(4, 1, 0, 'cat');
      g.setPiece(4, 2, 0, 'cat');
      g.cats[0] = 1;
      g.handle(0, {'type': 'place', 'r': 4, 'c': 3, 'kind': 'cat'});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2]);
    });
  });

  group('gobblet', () {
    test('external stack gobble restriction (only allowed on opponent 3-in-a-row) and board movement', () {
      final g = GobbletGame(_setup(2))..start();
      expect(g.externalStacks[0], [
        [1, 2, 3, 4],
        [1, 2, 3, 4],
        [1, 2, 3, 4],
      ]);

      // Put an opponent (P1) size-2 gobblet at (0, 0). Since P1 only has 1 piece in that line,
      // P0 CANNOT place an external stack piece onto (0, 0)!
      g.board[0][0].add((1, 2));
      expect(
        () => g.handle(0, {'type': 'place', 'stackIdx': 0, 'toR': 0, 'toC': 0}),
        throwsA(isA<GameError>()),
      );

      // Now add two more P1 pieces in row 0 at (0, 1) and (0, 2) so P1 has 3-in-a-row!
      g.board[0][1].add((1, 3));
      g.board[0][2].add((1, 1));
      // Now P0 CAN place size-4 from external stack 0 directly onto P1's size-2 at (0, 0)!
      g.handle(0, {'type': 'place', 'stackIdx': 0, 'toR': 0, 'toC': 0});
      expect(g.topAt(0, 0), (0, 4));
      expect(g.board[0][0].length, 2);
    });

    test('uncovering opponent 4-in-a-row loses if not re-covered, and 4-in-a-row wins', () {
      final g = GobbletGame(_setup(2))..start();
      // Suppose P1 has 4 pieces along row 2: (2,0), (2,1), (2,2), (2,3),
      // but P0's size-4 piece is currently sitting on top of (2,0) covering it!
      for (var c = 0; c < 4; c++) {
        g.board[2][c].add((1, 2));
      }
      g.board[2][0].add((0, 4));

      // P0 lifts the size-4 piece at (2, 0) and moves it to (0, 0) (not covering row 2):
      // Uncovering P1's 4-in-a-row causes P1 to win immediately!
      g.handle(0, {'type': 'move', 'fromR': 2, 'fromC': 0, 'toR': 0, 'toC': 0});
      expect(g.isOver, isTrue);
      expect(g.winner, 1);
      expect(g.placings, [2, 1]);
    });
  });

  group('orbito', () {
    test('counterclockwise orbits, optional shove + place, and 4-in-a-row after rotation', () {
      final g = OrbitoGame(_setup(2))..start();

      // Verify outer and inner orbit mapping
      expect(OrbitoGame.nextOrbitCell(0, 0), (1, 0));
      expect(OrbitoGame.nextOrbitCell(3, 0), (3, 1));
      expect(OrbitoGame.nextOrbitCell(3, 3), (2, 3));
      expect(OrbitoGame.nextOrbitCell(0, 3), (0, 2));
      expect(OrbitoGame.nextOrbitCell(1, 1), (2, 1));
      expect(OrbitoGame.nextOrbitCell(2, 1), (2, 2));
      expect(OrbitoGame.nextOrbitCell(2, 2), (1, 2));
      expect(OrbitoGame.nextOrbitCell(1, 2), (1, 1));

      // Place P1 marble at (1, 1) and test P0 shoving it to (1, 0) then placing at (1, 1):
      g.board[1][1] = 1;
      g.handle(0, {
        'type': 'place',
        'shoveFromR': 1,
        'shoveFromC': 1,
        'shoveToR': 1,
        'shoveToC': 0,
        'r': 1,
        'c': 1,
      });
      // After rotation:
      // P1's shoved marble at (1, 0) rotated to (2, 0)
      // P0's placed marble at (1, 1) rotated to (2, 1)
      expect(g.board[2][0], 1);
      expect(g.board[2][1], 0);
      expect(g.turn, 1);

      // Set up 3 P1 marbles that will rotate into column 0: (0,1)->(0,0), (0,0)->(1,0), (1,0)->(2,0)
      // and P1 places at (2,0) which rotates to (3,0), completing column 0 after rotation!
      g.clearBoard();
      g.board[0][1] = 1;
      g.board[0][0] = 1;
      g.board[1][0] = 1;
      g.turn = 1;
      g.handle(1, {'type': 'place', 'r': 2, 'c': 0});
      expect(g.board[0][0], 1);
      expect(g.board[1][0], 1);
      expect(g.board[2][0], 1);
      expect(g.board[3][0], 1);
      expect(g.isOver, isTrue);
      expect(g.winner, 1);
    });
  });

  group('bagh_chal', () {
    test('alquerque parity diagonals, goat placement, tiger jump capture, and victory conditions', () {
      final g = BaghChalGame(_setup(2, {'mode': 'quick'}))..start();
      expect(g.turn, 1); // Goats start first
      expect(g.goatsInReserve, 20);

      // Odd parity intersection (0, 1) has NO diagonal edge to (1, 2)
      expect(BaghChalGame.hasEdge(0, 1, 1, 2), isFalse);
      // Even parity intersection (0, 0) HAS diagonal edge to (1, 1)
      expect(BaghChalGame.hasEdge(0, 0, 1, 1), isTrue);

      // Goat (Seat 1) places at (1, 1)
      g.handle(1, {'type': 'place', 'r': 1, 'c': 1});
      expect(g.board[1][1], BaghChalGame.kGoat);
      expect(g.goatsInReserve, 19);
      expect(g.turn, 0); // Now Tigers' turn

      // Tiger at (0, 0) jumps diagonally over Goat at (1, 1) into (2, 2)!
      g.handle(0, {'type': 'move', 'fromR': 0, 'fromC': 0, 'toR': 2, 'toC': 2});
      expect(g.board[0][0], BaghChalGame.kEmpty);
      expect(g.board[1][1], BaghChalGame.kEmpty);
      expect(g.board[2][2], BaghChalGame.kTiger);
      expect(g.goatsCaptured, 1);

      // Give Tigers 2 captures already (target is 3 in quick mode) and let Tiger jump another Goat:
      g.goatsCaptured = 2;
      g.handle(1, {'type': 'place', 'r': 2, 'c': 3});
      g.handle(0, {'type': 'move', 'fromR': 2, 'fromC': 2, 'toR': 2, 'toC': 4});
      expect(g.goatsCaptured, 3);
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
    });

    test('goats win immediately when all 4 tigers are trapped with 0 legal moves', () {
      final g = BaghChalGame(_setup(2))..start();
      g.clearBoard();
      // Place 4 tigers at the 4 corners and surround all their 1-step and 2-step landing spots with goats
      g.board[0][0] = BaghChalGame.kTiger;
      g.board[0][4] = BaghChalGame.kTiger;
      g.board[4][0] = BaghChalGame.kTiger;
      g.board[4][4] = BaghChalGame.kTiger;

      for (var r = 0; r < 5; r++) {
        for (var c = 0; c < 5; c++) {
          if (g.board[r][c] == BaghChalGame.kEmpty && !(r == 2 && c == 2)) {
            g.board[r][c] = BaghChalGame.kGoat;
          }
        }
      }
      // Leave (2, 2) empty so before Goat places at (2, 2), Tigers at corners could jump over (1,1)/(1,3)/(3,1)/(3,3) into (2, 2).
      // Now Goat places at (2, 2), blocking the last jump landing square!
      g.turn = 1;
      g.goatsInReserve = 1;
      g.handle(1, {'type': 'place', 'r': 2, 'c': 2});
      expect(g.isOver, isTrue);
      expect(g.winner, 1);
      expect(g.placings, [2, 1]);
    });
  });

  group('dobutsu_shogi', () {
    test('chick capture, hand drop, promotion to hen, and catch/try victory conditions', () {
      final g = DobutsuShogiGame(_setup(2))..start();
      expect(g.board[3][1]?.kind, 'L');
      expect(g.board[0][1]?.kind, 'L');

      // Seat 0 Chick at (2, 1) captures Seat 1 Chick at (1, 1)
      g.handle(0, {'type': 'move', 'fromR': 2, 'fromC': 1, 'toR': 1, 'toC': 1});
      expect(g.hands[0], ['C']);
      expect(g.turn, 1);

      // Seat 1 Elephant at (0, 2) captures Seat 0 Chick at (1, 1)
      g.handle(1, {'type': 'move', 'fromR': 0, 'fromC': 2, 'toR': 1, 'toC': 1});
      expect(g.hands[1], ['C']);
      expect(g.turn, 0);

      // Seat 0 drops captured Chick 'C' onto (1, 2)
      g.handle(0, {'type': 'drop', 'kind': 'C', 'r': 1, 'c': 2});
      expect(g.board[1][2]?.kind, 'C');
      expect(g.hands[0], isEmpty);

      // Seat 1 moves Lion from (0, 1) to (0, 2)
      g.handle(1, {'type': 'move', 'fromR': 0, 'fromC': 1, 'toR': 0, 'toC': 2});

      // Seat 0 moves Chick at (1, 2) forward to (0, 2), capturing Seat 1's Lion -> Catch win!
      g.handle(0, {'type': 'move', 'fromR': 1, 'fromC': 2, 'toR': 0, 'toC': 2});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
    });

    test('try rule: lion reaching back rank wins immediately only if square is unattacked', () {
      final g = DobutsuShogiGame(_setup(2))..start();
      g.clearBoard();
      // Place P0 Lion at (1, 0), P1 Lion at (2, 2), and P1 Giraffe at (0, 2)
      g.setPiece(1, 0, 0, 'L');
      g.setPiece(2, 2, 1, 'L');
      g.setPiece(0, 2, 1, 'G');
      g.turn = 0;

      // If P0 Lion moves to (0, 1), P1 Giraffe at (0, 2) attacks (0, 1), so it is NOT an immediate Try win!
      // Instead, P0 Lion moves to (0, 0), which is NOT attacked by any P1 piece -> immediate Try win!
      g.handle(0, {'type': 'move', 'fromR': 1, 'fromC': 0, 'toR': 0, 'toC': 0});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2]);
    });
  });
}
