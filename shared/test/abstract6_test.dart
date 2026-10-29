import 'dart:math';

import 'package:aurora_shared/games/abstract6/breakthrough.dart';
import 'package:aurora_shared/games/abstract6/defs.dart';
import 'package:aurora_shared/games/abstract6/quixo.dart';
import 'package:aurora_shared/games/abstract6/yinsh.dart';
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
  test('abstract6: bots finish every variant (count: 30)', () {
    expect(runSims(abstract6Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('yinsh', () {
    test('setup 10 rings, ring jumping & marker flipping, and 5-in-a-row trophy ring win', () {
      final e = Yinsh(_setup(2, {'target': 1}))..start();
      expect(e.board.length, 61);
      expect(e.phase, 'setup');
      expect(e.targetRings, 1);

      // Place 10 rings alternating
      for (var i = 0; i < 10; i++) {
        final s = i % 2;
        e.handle(s, {'type': 'place_ring', 'cell': i});
      }
      expect(e.phase, 'play');
      expect(e.countRings(0), 5);
      expect(e.countRings(1), 5);

      // Clear board to test exact jumping, flipping, and 5-in-a-row scoring
      e.board.fillRange(0, 61, -1);
      // Along r = 0: q = -4..4
      final cM4 = yinshIndex(-4, 0);
      final cM3 = yinshIndex(-3, 0);
      final cM2 = yinshIndex(-2, 0);
      final cM1 = yinshIndex(-1, 0);
      final c0 = yinshIndex(0, 0);
      final c1 = yinshIndex(1, 0);
      final c2 = yinshIndex(2, 0);

      // Seat 0 ring at (-4, 0), and another Seat 0 ring at (0, 2)
      e.board[cM4] = 2;
      e.board[yinshIndex(0, 2)] = 2;
      // Contiguous markers at (-3, 0)=1 (Black), (-2, 0)=1 (Black), (-1, 0)=0 (White), (0, 0)=0 (White)
      // Wait: if Seat 0 jumps from (-4, 0) over (-3,0), (-2,0) onto (-1,0):
      // Let's put Black markers at (-3, 0) and (-2, 0), empty at (-1, 0), and White markers at (-4,1), (-4,2)...
      // Even simpler: let (-3, 0)=1, (-2, 0)=1, (-1, 0)=1, (0, 0)=1 (four Black markers in a row!)
      // When Seat 0's ring at (-4, 0) jumps over (-3,0)..(0,0) to land on empty (1, 0):
      // 1) A White marker (0) is placed at (-4, 0)
      // 2) The 4 Black markers at (-3,0), (-2,0), (-1,0), (0,0) flip to White (0)!
      // 3) Now (-4,0), (-3,0), (-2,0), (-1,0), (0,0) are 5 contiguous White markers!
      // 4) Those 5 markers are removed and Seat 0 scores +1 Trophy Ring -> wins (target=1)!
      e.board[cM3] = 1;
      e.board[cM2] = 1;
      e.board[cM1] = 1;
      e.board[c0] = 1;
      e.board[yinshIndex(0, 3)] = 3; // Seat 1 ring

      // Cannot jump past the first empty cell c1 to c2 after jumping over markers!
      expect(e.legalTargets(cM4), contains(c1));
      expect(e.legalTargets(cM4), isNot(contains(c2)));

      e.turn = 0;
      e.handle(0, {'type': 'move_ring', 'from': cM4, 'to': c1});
      expect(e.scores[0], 1);
      expect(e.board[cM4], -1); // 5-in-a-row markers removed!
      expect(e.board[cM3], -1);
      expect(e.board[c0], -1);
      expect(e.isOver, isTrue);
      expect(e.winner, 0);
      expect(e.placings, [1, 2]);
    });
  });

  group('quixo', () {
    test('outer border restriction, cube shifting, and official opponent-first 5-in-a-row rule', () {
      final e = Quixo(_setup(2))..start();
      // Center cube (2,2) = 12 cannot be picked
      expect(e.canPick(0, 12), isFalse);
      expect(() => e.handle(0, {'type': 'push', 'from': 12, 'to': 14}), throwsA(isA<GameError>()));

      // Corner (0,0)=0 has 2 targets: (0,4)=4 and (4,0)=20
      expect(e.legalTargets(0).toSet(), {4, 20});
      // Edge non-corner (0,2)=2 has 3 targets: (0,0)=0, (0,4)=4, (4,2)=22
      expect(e.legalTargets(2).toSet(), {0, 4, 22});

      // Test shifting along row 0: pick 0, push to 4
      e.board[1] = 2; // O at (0,1)
      e.handle(0, {'type': 'push', 'from': 0, 'to': 4});
      expect(e.board[0], 2); // shifted left from index 1 to index 0!
      expect(e.board[4], 1); // X inserted at index 4!

      // Seat 1 cannot pick cube at 4 (which now has Seat 0's symbol 1)
      expect(e.canPick(1, 4), isFalse);
      expect(() => e.handle(1, {'type': 'push', 'from': 4, 'to': 0}), throwsA(isA<GameError>()));

      // Official Quixo Rule: if active player's push creates 5-in-a-row for BOTH opponent and self, OPPONENT wins!
      final e2 = Quixo(_setup(2))..start();
      // Suppose Seat 0 pushes from (0, 0)=0 to (4, 0)=20 (shifting column 0 upward by 1 row):
      // Before push, row 0 has O (2) at cols 1,2,3,4 and row 1 has O (2) at col 0 (index 5).
      // Wait: when (0,0) is pushed to (4,0), index 5 shifts up to index 0, completing row 0 of O's (0,1,2,3,4)!
      // Even if row 4 also becomes all X's (1) at (20,21,22,23,24), Seat 1 (opponent) wins immediately!
      e2.board[0] = 0;
      e2.board[1] = 2;
      e2.board[2] = 2;
      e2.board[3] = 2;
      e2.board[4] = 2;
      e2.board[5] = 2; // shifts to 0 when 0->20 is pushed!
      e2.board[21] = 1;
      e2.board[22] = 1;
      e2.board[23] = 1;
      e2.board[24] = 1;
      e2.turn = 0;

      e2.handle(0, {'type': 'push', 'from': 0, 'to': 20});
      expect(e2.isOver, isTrue);
      expect(e2.winner, 1); // Opponent wins!
      expect(e2.placings, [2, 1]);
    });
  });

  group('breakthrough', () {
    test('8x8 and 6x6 setup, straight vs diagonal capture rules, and back-row breakthrough win', () {
      final e8 = Breakthrough(_setup(2, {'size': 8}))..start();
      expect(e8.size, 8);
      expect(e8.countPieces(0), 16);
      expect(e8.countPieces(1), 16);

      final e6 = Breakthrough(_setup(2, {'size': 6}))..start();
      expect(e6.size, 6);
      expect(e6.countPieces(0), 12);
      expect(e6.countPieces(1), 12);

      // Test straight move blocked by opponent vs diagonal capture allowed
      e6.board.fillRange(0, 36, -1);
      // Seat 0 piece at (2, 2) = 14 (moves UP toward row 0, dr = -1):
      // Opponent piece directly ahead at (1, 2) = 8, and another opponent piece diagonally at (1, 3) = 9
      e6.board[14] = 0;
      e6.board[8] = 1; // directly ahead -> CANNOT move or capture straight!
      e6.board[9] = 1; // diagonally ahead -> CAN capture!
      e6.turn = 0;

      expect(e6.legalTargets(14), isNot(contains(8)));
      expect(e6.legalTargets(14), contains(9)); // diagonal capture
      expect(e6.legalTargets(14), contains(7)); // diagonal empty (1, 1)

      // Capture diagonally 14 -> 9
      e6.handle(0, {'type': 'move', 'from': 14, 'to': 9});
      expect(e6.board[9], 0);
      expect(e6.isOver, isFalse);

      // Seat 1 moves 8 -> 14 (straight forward into empty square)
      e6.handle(1, {'type': 'move', 'from': 8, 'to': 14});
      expect(e6.board[14], 1);

      // Seat 0 moves 9 -> 3 (row 0, back rank!) -> wins immediately!
      e6.handle(0, {'type': 'move', 'from': 9, 'to': 3});
      expect(e6.isOver, isTrue);
      expect(e6.winner, 0);
      expect(e6.placings, [1, 2]);
    });
  });
}
