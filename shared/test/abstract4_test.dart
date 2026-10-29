import 'dart:math';

import 'package:aurora_shared/games/abstract4/amazons.dart';
import 'package:aurora_shared/games/abstract4/defs.dart';
import 'package:aurora_shared/games/abstract4/kamisado.dart';
import 'package:aurora_shared/games/abstract4/linesofaction.dart';
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
  test('abstract4: bots finish every variant (count: 30)', () {
    expect(runSims(abstract4Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('amazons', () {
    test('8x8 and 10x10 starting setups and basic move + arrow shot', () {
      for (final sz in [8, 10]) {
        final e = Amazons(_setup(2, {'size': sz}))..start();
        expect(e.size, sz);
        expect(e.board.length, sz * sz);
        expect(e.piecesOf(0).length, 4);
        expect(e.piecesOf(1).length, 4);
      }

      final e = Amazons(_setup(2, {'size': 8}))..start();
      // White Amazon at (7, 2) = 58 moves to (3, 2) = 26, shoots arrow back to (7, 2) = 58
      e.handle(0, {'type': 'move', 'from': 58, 'to': 26, 'arrow': 58});
      expect(e.board[26], 0);
      expect(e.board[58], 2); // burned arrow
      expect(e.turn, 1);

      // Cannot move through or onto burned arrow at 58
      expect(
        () => e.handle(1, {'type': 'move', 'from': 2, 'to': 58, 'arrow': 50}),
        throwsA(isA<GameError>()),
      );
    });

    test('player with no legal moves loses immediately', () {
      final e = Amazons(_setup(2, {'size': 8}))..start();
      e.board.fillRange(0, 64, 2); // Fill all with arrows
      // Place 1 White Amazon at (0, 0) = 0 with empty (0, 1) = 1 and (0, 2) = 2
      e.board[0] = 0;
      e.board[1] = -1;
      e.board[2] = -1;
      // Place 1 Black Amazon at (7, 7) = 63, completely surrounded except (0, 2) is far away
      e.board[63] = 1;
      // White moves 0 -> 1 and shoots arrow at 2, leaving Black with 0 legal moves
      e.handle(0, {'from': 0, 'to': 1, 'arrow': 2});
      expect(e.isOver, isTrue);
      expect(e.winner, 0);
      expect(e.placings, [1, 2]);
    });
  });

  group('linesofaction', () {
    test('standard and scrambled layouts have 12 pieces per side', () {
      for (final layout in ['standard', 'scrambled']) {
        final e = LinesOfAction(_setup(2, {'layout': layout}))..start();
        expect(e.board.where((c) => c == 0).length, 12);
        expect(e.board.where((c) => c == 1).length, 12);
      }
    });

    test('exact line-count movement, jumping own vs opponent, capture, and connection win', () {
      final e = LinesOfAction(_setup(2))..start();
      // In standard setup, column 1 has 2 Black pieces at (0,1)=1 and (7,1)=57, and 0 White pieces -> line count = 2.
      expect(e.linePieceCount(0, 1, 1, 0), 2);
      // Moving (0,1)=1 south by 3 squares (to 25) is illegal because line count is 2
      expect(() => e.handle(0, {'from': 1, 'to': 25}), throwsA(isA<GameError>()));
      // Moving (0,1)=1 south by 2 squares (to (2,1)=17) is legal!
      e.handle(0, {'from': 1, 'to': 17});
      expect(e.board[17], 0);
      expect(e.turn, 1);

      // Test jumping over own piece vs opponent piece and simultaneous connection win
      e.board.fillRange(0, 64, -1);
      e.turn = 0;
      // Black at (0,0)=0, (0,1)=1 (own piece to jump over), and (0,4)=4; White at (0,3)=3 (capture target) and (5,5)=45
      // Total pieces on row 0: (0,0), (0,1), (0,3), (0,4) -> 4 pieces? Wait: let's put 3 pieces on row 0:
      // Black at (0,0)=0, Black at (0,1)=1, White at (0,3)=3 -> 3 pieces on row 0!
      // And White also has 1 piece at (5,5)=45.
      // When Black moves (0,0) -> (0,3) (distance 3, jumping over own piece at (0,1), capturing White at (0,3)):
      // Black now has pieces at (0,1) and (0,3)? Wait: put Black's 2nd piece at (1,2)=10 so (1,2) and (0,3) are diagonally adjacent!
      e.board[0] = 0; // (0,0) Black
      e.board[1] = 0; // (0,1) Black
      e.board[10] = 0; // (1,2) Black - adjacent to both (0,1) and (0,3)
      e.board[3] = 1; // (0,3) White
      e.board[45] = 1; // (5,5) White
      // Wait: if White is also at (0,2)=2, Black at (0,0) cannot jump over White at (0,2)!
      e.board[2] = 1;
      expect(() => e.handle(0, {'from': 0, 'to': 4}), throwsA(isA<GameError>()));
      e.board[2] = -1;

      // Now row 0 has 3 pieces: (0,0), (0,1), (0,3).
      // Black moves (0,0)=0 -> (0,3)=3 (distance 3, jumps over own piece at (0,1), captures White at (0,3)).
      // After capture, BOTH Black ((0,1), (1,2), (0,3)) and White (only (5,5) left) are 1-component connected!
      // Moving player (Black = 0) wins!
      e.handle(0, {'from': 0, 'to': 3});
      expect(e.isOver, isTrue);
      expect(e.winner, 0);
      expect(e.placings, [1, 2]);
    });
  });

  group('kamisado', () {
    test('color lock, blocked pass, deadlock cycle, and home rank win (1pt & 3pt)', () {
      final e = Kamisado(_setup(2, {'targetScore': 1}))..start();
      // Player 0 moves tower of color 0 at (7,7)=63 straight up to (4,7)=39 (color 3 = Pink)
      e.handle(0, {'from': 63, 'to': 39});
      expect(e.turn, 1);
      expect(e.requiredColor, 3); // Pink

      // Player 1 cannot move a non-Pink tower (e.g. Orange tower at (0,0)=0)
      expect(() => e.handle(1, {'from': 0, 'to': 8}), throwsA(isA<GameError>()));

      // Test blocked tower pass and deadlock cycle:
      // Place P1's Pink tower (color 3) at (0, 0)=0 (square color 0 = Orange), blocked by towers at (1,0)=8 and (1,1)=9.
      // Place P0's Orange tower (color 0) at (7, 4)=60 (square color 3 = Pink), blocked by towers at (6,3)=51, (6,4)=52, (6,5)=53.
      e.towers[1][3] = 0; // on color 0
      e.towers[0][1] = 8;
      e.towers[0][2] = 9;

      e.towers[0][0] = 60; // on color 3
      e.towers[1][4] = 51;
      e.towers[1][5] = 52;
      e.towers[1][6] = 53;

      // P1 (requiredColor = 3) has no legal moves -> must pass!
      expect(e.canPass(1), isTrue);
      e.handle(1, {'type': 'pass'});
      expect(e.turn, 0);
      expect(e.requiredColor, 0); // Orange (square color of cell 0)

      // Now P0 (requiredColor = 0) is also blocked on cell 60 (color 3) -> passing creates a cycle back to (1, 3)!
      // Last actual move was by P0 (lastMover = 0), so P0 caused the cycle and loses -> P1 wins!
      expect(e.canPass(0), isTrue);
      e.handle(0, {'type': 'pass'});
      expect(e.isOver, isTrue);
      expect(e.winner, 1);
      expect(e.placings, [2, 1]);

      // Test reaching home rank in targetScore = 3 mode
      final e3 = Kamisado(_setup(2, {'targetScore': 3}))..start();
      // Clear path for P0's Brown tower at (7,0)=56 to reach (0,0)=0 by moving P1's (0,0) tower out of the way
      e3.towers[1][0] = 10;
      e3.handle(0, {'from': 56, 'to': 0});
      expect(e3.scores, [1, 0]);
      expect(e3.isOver, isFalse);
      expect(e3.round, 2);
      expect(e3.turn, 1); // loser of round 1 starts round 2
    });
  });
}
