import 'dart:math';

import 'package:aurora_shared/games/abstract14/blooms.dart';
import 'package:aurora_shared/games/abstract14/cannon.dart';
import 'package:aurora_shared/games/abstract14/defs.dart';
import 'package:aurora_shared/games/abstract14/latrunculi.dart';
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
  test('abstract14: bots finish every variant (count: 30)', () {
    expect(runSims(abstract14Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));

  group('cannon', () {
    test('initial setup and town placement phase', () {
      final g = CannonGame(_setup(2))..start();
      expect(g.boardSize, 10);
      expect(g.phase, 'place_town');
      expect(g.soldierCount(0), 15);
      expect(g.soldierCount(1), 15);

      // Corner columns (0 and 9) are illegal for town placement
      expect(
        () => g.handle(0, {'type': 'place_town', 'c': 0}),
        throwsA(isA<GameError>()),
      );
      expect(
        () => g.handle(0, {'type': 'place_town', 'c': 9}),
        throwsA(isA<GameError>()),
      );

      // Valid town placements transition to 'play' phase
      g.handle(0, {'type': 'place_town', 'c': 4});
      expect(g.board[9][4], 3);
      expect(g.turn, 1);

      g.handle(1, {'type': 'place_town', 'c': 5});
      expect(g.board[0][5], 4);
      expect(g.phase, 'play');
      expect(g.turn, 0);
    });

    test('soldier step, sideways/forward capture, and tactical retreat', () {
      final g = CannonGame(_setup(2, {'mode': 'quick'}))..start();
      g.handle(0, {'type': 'place_town', 'c': 3});
      g.handle(1, {'type': 'place_town', 'c': 4});

      // Clear board for isolated tactical test
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          g.board[r][c] = 0;
        }
      }
      g.board[7][3] = 3; // Blue Town
      g.board[0][4] = 4; // Red Town
      g.board[4][3] = 1; // Blue Soldier
      g.board[3][4] = 2; // Red Soldier adjacent diagonally
      g.board[4][2] = 2; // Red Soldier adjacent sideways

      // Blue Soldier at (4, 3) captures sideways Red Soldier at (4, 2)
      g.handle(0, {'type': 'move', 'fromR': 4, 'fromC': 3, 'toR': 4, 'toC': 2});
      expect(g.board[4][2], 1);
      expect(g.captured[0], 1);

      // Red Soldier at (3, 4) steps forward to (4, 3) (now adjacent to Blue at (4, 2))
      g.handle(1, {'type': 'move', 'fromR': 3, 'fromC': 4, 'toR': 4, 'toC': 3});
      expect(g.board[4][3], 2);

      // Blue Soldier at (4, 2) is adjacent to Red at (4, 3), so it can Tactical Retreat 2 spaces backward to (6, 2)!
      g.handle(0, {'type': 'move', 'fromR': 4, 'fromC': 2, 'toR': 6, 'toC': 2});
      expect(g.board[6][2], 1);
      expect(g.board[4][2], 0);
    });

    test('3-soldier cannon slide and artillery shoot destroying enemy Town wins immediately', () {
      final g = CannonGame(_setup(2, {'mode': 'quick'}))..start();
      g.handle(0, {'type': 'place_town', 'c': 3});
      g.handle(1, {'type': 'place_town', 'c': 4});

      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          g.board[r][c] = 0;
        }
      }
      g.board[7][3] = 3; // Blue Town
      g.board[0][4] = 4; // Red Town
      g.board[2][1] = 2; // Red Soldier

      // Blue 3-soldier vertical cannon at (6, 4), (5, 4), (4, 4)
      g.board[6][4] = 1;
      g.board[5][4] = 1;
      g.board[4][4] = 1;

      // Cannon slide: move rear soldier (6, 4) to front (3, 4)
      g.handle(0, {'type': 'move', 'fromR': 6, 'fromC': 4, 'toR': 3, 'toC': 4});
      expect(g.board[3][4], 1);
      expect(g.board[6][4], 0);

      // Red moves soldier (2, 1) -> (3, 1)
      g.handle(1, {'type': 'move', 'fromR': 2, 'fromC': 1, 'toR': 3, 'toC': 1});

      // Now Blue's 3-soldier cannon is at (5, 4), (4, 4), (3, 4).
      // Square (2, 4) at distance 1 in front of muzzle (3, 4) is EMPTY,
      // and Red Town is at (0, 4) — distance 3 in front of muzzle (3, 4)!
      g.handle(0, {'type': 'shoot', 'fromR': 3, 'fromC': 4, 'toR': 0, 'toC': 4});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2]);
    });
  });

  group('blooms', () {
    test('turn 1 single placement and subsequent dual-color placement rules', () {
      final b = BloomsGame(_setup(2))..start();
      expect(b.boardCells.length, 61);
      expect(b.targetCaptures, 15);

      // Turn 0: Player 0 places 1 stone of Color 1, turn immediately passes to Player 1
      b.handle(0, {'type': 'place', 'q': 0, 'r': 0, 'color': 1});
      expect(b.stoneAt(0, 0), 1);
      expect(b.turn, 1);

      // Turn 1: Player 1 cannot use Player 0's colors (1 or 2)
      expect(
        () => b.handle(1, {'type': 'place', 'q': 1, 'r': 0, 'color': 1}),
        throwsA(isA<GameError>()),
      );

      // Player 1 places Color 3 at (1, 0) -> still Player 1's turn for second color
      b.handle(1, {'type': 'place', 'q': 1, 'r': 0, 'color': 3});
      expect(b.turn, 1);

      // Player 1 cannot place a second stone of the SAME color 3!
      expect(
        () => b.handle(1, {'type': 'place', 'q': 0, 'r': 1, 'color': 3}),
        throwsA(isA<GameError>()),
      );

      // Player 1 places Color 4 at (0, 1) -> turn ends and passes to Player 0
      b.handle(1, {'type': 'place', 'q': 0, 'r': 1, 'color': 4});
      expect(b.turn, 0);
    });

    test('distinct same-owner colors form separate blooms and 0-liberty enemy blooms are captured', () {
      final b = BloomsGame(_setup(2, {'mode': 'quick'}))..start();
      expect(b.boardCells.length, 37);
      expect(b.targetCaptures, 10);

      // Place an enemy Color 3 stone at (0, 0) and an enemy Color 4 stone at (1, 0).
      // Surround (0, 0) on its other 5 sides with Player 0's stones, leaving (1, 0) with liberties!
      b.setStoneAt(0, 0, 3);
      b.setStoneAt(1, 0, 4); // Adjacent enemy stone, but DIFFERENT color (4 != 3)!
      b.setStoneAt(-1, 0, 1);
      b.setStoneAt(0, 1, 1);
      b.setStoneAt(0, -1, 2);
      b.setStoneAt(1, -1, 2);
      // The only remaining neighbor of (0, 0) is (-1, 1)!
      // Even though (1, 0) is also Player 1's stone and has liberties, Color 3 at (0, 0) is a separate Bloom!
      b.handle(0, {'type': 'place', 'q': -1, 'r': 1, 'color': 1});
      expect(b.stoneAt(0, 0), 0); // Captured!
      expect(b.stoneAt(1, 0), 4); // Untouched because it's Color 4 with plenty of liberties!
      expect(b.captured[0], 1);
    });
  });

  group('latrunculi', () {
    test('initial setup, rook slide, and Dux vault jump', () {
      final l = LatrunculiGame(_setup(2))..start();
      expect(l.legionaryCount(0), 8);
      expect(l.legionaryCount(1), 8);
      expect(l.board[6][4], 3); // White Dux
      expect(l.board[1][3], 4); // Black Dux

      // White Legionary at (7, 0) slides up to (3, 0)
      l.handle(0, {'type': 'move', 'fromR': 7, 'fromC': 0, 'toR': 3, 'toC': 0});
      expect(l.board[3][0], 1);

      // Black Legionary at (0, 3) is blocked by Black Dux at (1, 3), so cannot slide to (2, 3)
      expect(
        () => l.handle(1, {'type': 'move', 'fromR': 0, 'fromC': 3, 'toR': 2, 'toC': 3}),
        throwsA(isA<GameError>()),
      );

      // Move Black Legionary (0, 2) -> (5, 4) directly in front of White Dux (6, 4)
      l.board[0][2] = 0;
      l.board[5][4] = 2;
      l.handle(1, {'type': 'move', 'fromR': 0, 'fromC': 1, 'toR': 2, 'toC': 1});

      // Now White Dux at (6, 4) can VAULT over Black Legionary at (5, 4) to land on (4, 4)!
      l.handle(0, {'type': 'move', 'fromR': 6, 'fromC': 4, 'toR': 4, 'toC': 4});
      expect(l.board[4][4], 3);
      expect(l.board[5][4], 2); // Vaulted piece is not captured by jumping alone
    });

    test('custodial sandwich capture, corner trap, and Dux immunity', () {
      final l = LatrunculiGame(_setup(2))..start();
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          l.board[r][c] = 0;
        }
      }
      l.board[6][4] = 3; // White Dux
      l.board[4][4] = 4; // Black Dux
      // Place Black Legionary at (3, 2) with White Legionary at (3, 1)
      l.board[3][1] = 1;
      l.board[3][2] = 2;
      // Place Black Legionary at corner (0, 0) with White Legionary at (1, 0)
      l.board[0][0] = 2;
      l.board[1][0] = 1;
      // Place extra Black Legionaries so game doesn't end immediately on 1 capture
      for (var c = 2; c < 7; c++) {
        l.board[0][c] = 2;
      }
      // White Legionary at (3, 6) slides to (3, 3) -> sandwiches Black Legionary at (3, 2)!
      l.board[3][6] = 1;
      l.handle(0, {'type': 'move', 'fromR': 3, 'fromC': 6, 'toR': 3, 'toC': 3});
      expect(l.board[3][2], 0);
      expect(l.captured[0], 1);

      // Black moves a piece between two White pieces -> safe (no self-capture)
      l.board[3][5] = 1;
      l.handle(1, {'type': 'move', 'fromR': 0, 'fromC': 4, 'toR': 3, 'toC': 4});
      expect(l.board[3][4], 2);

      // White traps corner (0, 0) by moving from (2, 1) to (0, 1)!
      l.board[2][1] = 1;
      l.handle(0, {'type': 'move', 'fromR': 2, 'fromC': 1, 'toR': 0, 'toC': 1});
      expect(l.board[0][0], 0);
      expect(l.captured[0], 2);
    });

    test('surrounding enemy Dux on all orthogonal sides wins immediately', () {
      final l = LatrunculiGame(_setup(2))..start();
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          l.board[r][c] = 0;
        }
      }
      l.board[6][4] = 3; // White Dux
      l.board[3][3] = 4; // Black Dux
      l.board[2][3] = 1;
      l.board[4][3] = 1;
      l.board[3][2] = 1;
      l.board[3][6] = 1;
      l.board[0][7] = 2;
      l.board[1][7] = 2;

      // White moves (3, 6) -> (3, 4), completing orthogonal encirclement of Black Dux at (3, 3)!
      l.handle(0, {'type': 'move', 'fromR': 3, 'fromC': 6, 'toR': 3, 'toC': 4});
      expect(l.isOver, isTrue);
      expect(l.winner, 0);
      expect(l.placings, [1, 2]);
    });
  });
}
