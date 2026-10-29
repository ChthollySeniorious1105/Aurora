import 'dart:math';

import 'package:aurora_shared/games/abstract17/defs.dart';
import 'package:aurora_shared/games/abstract17/kuba.dart';
import 'package:aurora_shared/games/abstract17/martian_chess.dart';
import 'package:aurora_shared/games/abstract17/six_hex.dart';
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
  test('abstract17: bots finish every variant (count: 30)', () {
    expect(runSims(abstract17Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));

  group('kuba', () {
    test('initial setup, open-behind push rule, and ko rule enforcement', () {
      final g = KubaGame(_setup(2))..start();
      expect(g.marbleCount(1), 8); // White (P0)
      expect(g.marbleCount(2), 8); // Black (P1)
      expect(g.marbleCount(3), 13); // Neutral Red

      // (1, 1) has (1, 0)=1 behind it when pushing right (dir=1), so open-behind fails!
      expect(g.canPush(0, 1, 1, 1), isFalse);
      expect(
        () => g.handle(0, {'type': 'push', 'r': 1, 'c': 1, 'dir': 1}),
        throwsA(isA<GameError>()),
      );

      // (0, 0) has off-board behind it when pushing right (dir=1) or down (dir=2):
      // Pushing (0, 0) right shifts (0, 0) and (0, 1) to (0, 1) and (0, 2)
      expect(g.canPush(0, 0, 0, 1), isTrue);
      g.handle(0, {'type': 'push', 'r': 0, 'c': 0, 'dir': 1});
      expect(g.board[0][0], 0);
      expect(g.board[0][1], 1);
      expect(g.board[0][2], 1);
      expect(g.turn, 1);

      // Set up a direct Ko situation between P1 and P0:
      // Place [1, 2] horizontally at row 0, cols 2..3 with empty cells at (0, 1) and (0, 4)
      for (var r = 0; r < 7; r++) {
        for (var c = 0; c < 7; c++) {
          g.board[r][c] = 0;
        }
      }
      g.board[0][2] = 1; // P0
      g.board[0][3] = 2; // P1
      g.board[6][0] = 2;
      g.board[6][6] = 1;
      g.board[3][3] = 3;
      g.prevBoard = null;
      g.turn = 0;

      // P0 pushes (0, 2) right (dir=1) -> [1, 2] moves to cols 3..4
      g.handle(0, {'type': 'push', 'r': 0, 'c': 2, 'dir': 1});
      expect(g.board[0][3], 1);
      expect(g.board[0][4], 2);
      expect(g.turn, 1);

      // P1 cannot immediately push (0, 4) left (dir=3) to recreate prevBoard (Ko Rule)!
      expect(g.canPush(1, 0, 4, 3), isFalse);
      expect(
        () => g.handle(1, {'type': 'push', 'r': 0, 'c': 4, 'dir': 3}),
        throwsA(isA<GameError>()),
      );
    });

    test('no self-ejection, neutral red capture bonus turn, and 7-red win condition', () {
      final g = KubaGame(_setup(2))..start();
      for (var r = 0; r < 7; r++) {
        for (var c = 0; c < 7; c++) {
          g.board[r][c] = 0;
        }
      }
      // Put P0 marble at (0, 5) and another P0 marble at (0, 6) on the right edge:
      // Pushing (0, 5) right (dir=1) would eject P0's own marble at (0, 6) -> forbidden!
      g.board[0][5] = 1;
      g.board[0][6] = 1;
      g.board[6][0] = 2;
      expect(g.canPush(0, 0, 5, 1), isFalse);
      expect(
        () => g.handle(0, {'type': 'push', 'r': 0, 'c': 5, 'dir': 1}),
        throwsA(isA<GameError>()),
      );

      // Put Neutral Red (3) at (0, 6) and P0 marble at (0, 5) with (0, 4) empty:
      g.board[0][6] = 3;
      g.redCaptured[0] = 5;
      g.handle(0, {'type': 'push', 'r': 0, 'c': 5, 'dir': 1});
      // Red marble ejected! P0 now has 6 red marbles and gets a bonus turn (turn stays 0)!
      expect(g.redCaptured[0], 6);
      expect(g.over, isFalse);
      expect(g.turn, 0);
      expect(g.bonusTurn, isTrue);

      // Put a 7th Neutral Red at (2, 6) and P0 marble at (2, 5):
      g.board[2][5] = 1;
      g.board[2][6] = 3;
      g.handle(0, {'type': 'push', 'r': 2, 'c': 5, 'dir': 1});
      expect(g.redCaptured[0], 7);
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2]);
    });
  });

  group('six_hex', () {
    test('place phase, line/ring/triangle winning shape detection', () {
      final g = SixHexGame(_setup(2, {'mode': 'quick'}))..start();
      expect(g.reserve, [12, 12]);
      expect(g.phase, 'place');

      // Cannot place on disconnected hex (5, 5)
      expect(
        () => g.handle(0, {'type': 'place', 'q': 5, 'r': 5}),
        throwsA(isA<GameError>()),
      );

      // Test Line of 6 detection: (0,0), (0,1), (0,2), (0,3), (0,4), (0,5)
      for (var r = 0; r < 6; r++) {
        g.setTile(0, r, 0);
      }
      final lineWin = g.findWinningShape(0);
      expect(lineWin, isNotNull);
      expect(lineWin!.$1, 'line');

      // Test Ring of 6 detection around center (3, 3)
      g.board.clear();
      for (final (dq, dr) in SixHexGame.kHexDirs) {
        g.setTile(3 + dq, 3 + dr, 1);
      }
      final ringWin = g.findWinningShape(1);
      expect(ringWin, isNotNull);
      expect(ringWin!.$1, 'ring');

      // Test Triangle of 6 detection: (0,0), (1,0), (2,0), (0,1), (1,1), (0,2)
      g.board.clear();
      for (final (dq, dr) in SixHexGame.kTriUp) {
        g.setTile(dq, dr, 0);
      }
      final triWin = g.findWinningShape(0);
      expect(triWin, isNotNull);
      expect(triWin!.$1, 'triangle');
    });

    test('transition to move phase and outer-edge movement', () {
      final g = SixHexGame(_setup(2, {'mode': 'quick'}))..start();
      g.reserve = [1, 1];
      // P0 places last tile at (-1, 0), P1 places last tile at (2, 0)
      g.handle(0, {'type': 'place', 'q': -1, 'r': 0});
      expect(g.phase, 'place');
      g.handle(1, {'type': 'place', 'q': 2, 'r': 0});
      expect(g.phase, 'move');
      expect(g.turn, 0);

      // Give both players 6 tiles on the board so the game continues in move phase,
      // and let P0 move an outer-edge tile to complete a Triangle of 6!
      g.board.clear();
      // P0 has 5 of the 6 cells of kTriUp: (0,0), (1,0), (2,0), (0,1), (1,1), plus an extra outer tile at (-1, 0)
      g.setTile(0, 0, 0);
      g.setTile(1, 0, 0);
      g.setTile(2, 0, 0);
      g.setTile(0, 1, 0);
      g.setTile(1, 1, 0);
      g.setTile(-1, 0, 0);
      // P1 has 6 connected tiles nearby
      for (var k = 0; k < 6; k++) {
        g.setTile(3 + k, 0, 1);
      }

      // P0 moves outer-edge tile (-1, 0) to (0, 2), completing the 1+2+3 Triangle of 6!
      g.handle(0, {'type': 'move', 'fromQ': -1, 'fromR': 0, 'toQ': 0, 'toR': 2});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.winningShape, 'triangle');
    });
  });

  group('martian_chess', () {
    test('zone ownership, cross-canal transfer, ko reversal rule, and capture scoring', () {
      final g = MartianChessGame(_setup(2))..start();
      expect(g.zonePieceCount(0), 9);
      expect(g.zonePieceCount(1), 9);

      // Player 0 (South Zone rows 4..7) cannot move a piece in North Zone (rows 0..3)
      expect(
        () => g.handle(0, {'type': 'move', 'fromR': 2, 'fromC': 1, 'toR': 3, 'toC': 2}),
        throwsA(isA<GameError>()),
      );

      // Player 0 moves Drone (2) at (5, 3) two steps north across the canal to (3, 3) (North Zone!)
      g.handle(0, {'type': 'move', 'fromR': 5, 'fromC': 3, 'toR': 3, 'toC': 3});
      expect(g.board[3][3], 2);
      expect(g.turn, 1);

      // Now (3, 3) is in North Zone (Player 1's control!), but Player 1 CANNOT immediately reverse
      // the non-capturing cross-canal move back to (5, 3)!
      expect(
        () => g.handle(1, {'type': 'move', 'fromR': 3, 'fromC': 3, 'toR': 5, 'toC': 3}),
        throwsA(isA<GameError>()),
      );

      // However, Player 1 CAN move that Drone at (3, 3) to (4, 3) (a different square across the canal)
      g.handle(1, {'type': 'move', 'fromR': 3, 'fromC': 3, 'toR': 4, 'toC': 3});
      expect(g.board[4][3], 2);
      expect(g.turn, 0);

      // Put an enemy Queen (3) at (2, 3) so Player 0's Drone at (4, 3) can capture it 2 steps across the canal!
      g.board[2][3] = 3;
      g.handle(0, {'type': 'move', 'fromR': 4, 'fromC': 3, 'toR': 2, 'toC': 3});
      expect(g.score[0], 3);
      expect(g.board[2][3], 2); // Drone now stands in North Zone!
    });

    test('field promotion (Pawn + Drone -> Queen when 0 Queens in zone) and empty zone game end', () {
      final g = MartianChessGame(_setup(2))..start();
      // While Player 0 still has Queens in South Zone, merging Pawn (5, 2) onto Drone (5, 3) is forbidden
      expect(
        () => g.handle(0, {'type': 'move', 'fromR': 6, 'fromC': 1, 'toR': 5, 'toC': 2}),
        throwsA(isA<GameError>()),
      );

      // Clear board and leave Player 0 with 0 Queens: 1 Pawn at (6, 1) and 1 Drone at (5, 2)
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 4; c++) {
          g.board[r][c] = 0;
        }
      }
      g.board[6][1] = 1; // Pawn
      g.board[5][2] = 2; // Drone
      g.board[2][2] = 1; // North Pawn
      g.turn = 0;

      expect(g.zoneQueenCount(0), 0);
      // Pawn at (6, 1) moves diagonally 1 step onto Drone at (5, 2) -> merges into Queen (3)!
      g.handle(0, {'type': 'move', 'fromR': 6, 'fromC': 1, 'toR': 5, 'toC': 2});
      expect(g.board[5][2], 3);
      expect(g.board[6][1], 0);
      expect(g.turn, 1);

      // Player 1 moves North Pawn at (2, 2) to (3, 1), then Player 0's Queen at (5, 2) captures (3, 1)?
      // Wait: (5, 2) to (3, 2) is orthogonal, so let's move North Pawn at (2, 2) to (3, 2) instead:
      g.board[2][2] = 0;
      g.board[2][1] = 1;
      g.handle(1, {'type': 'move', 'fromR': 2, 'fromC': 1, 'toR': 3, 'toC': 2});
      expect(g.board[3][2], 1);

      // Now Player 0's only piece in South Zone is Queen at (5, 2).
      // Queen moves north across the canal to capture North's Pawn at (3, 2)!
      // South Zone becomes completely empty -> game ends immediately and Player 0 wins 1-0!
      g.handle(0, {'type': 'move', 'fromR': 5, 'fromC': 2, 'toR': 3, 'toC': 2});
      expect(g.score[0], 1);
      expect(g.zonePieceCount(0), 0);
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2]);
    });
  });
}
