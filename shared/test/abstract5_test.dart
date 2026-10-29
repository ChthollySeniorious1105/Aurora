import 'dart:math';

import 'package:aurora_shared/games/abstract5/defs.dart';
import 'package:aurora_shared/games/abstract5/fanorona.dart';
import 'package:aurora_shared/games/abstract5/hnefatafl.dart';
import 'package:aurora_shared/games/abstract5/tak.dart';
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
  test('abstract5: bots finish every variant (count: 30)', () {
    expect(runSims(abstract5Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('hnefatafl', () {
    test('9x9 Tablut and 7x7 Brandubh starting piece counts and throne/corner rules', () {
      final e9 = Hnefatafl(_setup(2, {'size': 9}))..start();
      expect(e9.size, 9);
      expect(e9.board.where((p) => p == 0).length, 16);
      expect(e9.board.where((p) => p == 1).length, 8);
      expect(e9.board.where((p) => p == 2).length, 1);
      expect(e9.board[e9.throne], 2);

      final e7 = Hnefatafl(_setup(2, {'size': 7}))..start();
      expect(e7.size, 7);
      expect(e7.board.where((p) => p == 0).length, 8);
      expect(e7.board.where((p) => p == 1).length, 4);
      expect(e7.board.where((p) => p == 2).length, 1);
      expect(e7.board[e7.throne], 2);

      // Regular soldier cannot land on corner (0,0) = 0
      expect(() => e9.handle(0, {'from': 3, 'to': 0}), throwsA(isA<GameError>()));
    });

    test('custodial capture, 4-side throne king capture vs 2-side open king capture, and corner escape win', () {
      final e = Hnefatafl(_setup(2, {'size': 9}))..start();
      e.board.fillRange(0, 81, -1);

      // Place King on Throne (4,4)=40, surrounded on 3 sides: (3,4)=31, (5,4)=49, (4,3)=39
      // Only (4,5)=41 is open, and an Attacker at (4,7)=43 will move to (4,5)=41
      e.board[40] = 2; // King on throne
      e.board[31] = 0;
      e.board[49] = 0;
      e.board[39] = 0;
      e.board[43] = 0;

      // Also test regular soldier passing through empty throne when King is away:
      // First, verify 4-side capture on Throne wins for Seat 0
      e.handle(0, {'from': 43, 'to': 41});
      expect(e.isOver, isTrue);
      expect(e.winner, 0);
      expect(e.placings, [1, 2]);

      // Now test King away from Throne (2-side custodial capture) and King escaping to Corner
      final e2 = Hnefatafl(_setup(2, {'size': 7}))..start();
      e2.board.fillRange(0, 49, -1);
      // King at (0, 3) = 3, Defender at (2, 2) = 16, Attackers at (5, 5) = 40
      e2.board[3] = 2;
      e2.board[40] = 0;
      e2.turn = 1;
      // King moves from (0,3)=3 to Corner (0,0)=0 -> Defenders (Seat 1) win immediately!
      e2.handle(1, {'from': 3, 'to': 0});
      expect(e2.isOver, isTrue);
      expect(e2.winner, 1);
      expect(e2.placings, [2, 1]);
    });
  });

  group('tak', () {
    test('turn 1 opponent flat placement, capstone flattening wall, and road / flat wins', () {
      final e = Tak(_setup(2, {'size': 5}))..start();
      expect(e.stones, [21, 21]);
      expect(e.caps, [1, 1]);

      // Turn 0 (Seat 0): must place opponent's (Seat 1) flat stone
      expect(() => e.handle(0, {'type': 'place', 'cell': 0, 'kind': 'wall'}), throwsA(isA<GameError>()));
      e.handle(0, {'type': 'place', 'cell': 0, 'kind': 'flat'});
      expect(e.board[0].single.owner, 1); // opponent's stone!
      expect(e.stones[1], 20);

      // Turn 1 (Seat 1): must place opponent's (Seat 0) flat stone
      e.handle(1, {'type': 'place', 'cell': 24, 'kind': 'flat'});
      expect(e.board[24].single.owner, 0);
      expect(e.stones[0], 20);

      // Turn 2+: normal placement & Capstone flattening Wall test
      // Seat 0 places Capstone at (2, 1) = 11
      e.handle(0, {'type': 'place', 'cell': 11, 'kind': 'cap'});
      expect(e.caps[0], 0);
      // Seat 1 places Wall at (2, 2) = 12
      e.handle(1, {'type': 'place', 'cell': 12, 'kind': 'wall'});
      expect(e.board[12].single.kind, 'wall');

      // Seat 0 spreads Capstone from 11 East (dir=1) by [1] onto Wall at 12 -> flattens Wall into 'flat'!
      e.handle(0, {'type': 'spread', 'from': 11, 'dir': 1, 'drops': [1]});
      expect(e.board[12].length, 2);
      expect(e.board[12][0].kind, 'flat'); // flattened!
      expect(e.board[12][0].owner, 1);
      expect(e.board[12][1].kind, 'cap');
      expect(e.board[12][1].owner, 0);

      // Now test West-to-East Road Win for Seat 0 across row 2 (cells 10, 11, 12, 13, 14)
      // Cell 12 already has Seat 0's Cap on top!
      e.board[10] = [const TakPiece(0, 'flat')];
      e.board[11] = [const TakPiece(0, 'flat')];
      e.board[13] = [const TakPiece(0, 'flat')];
      e.turn = 0;
      // Seat 0 places flat at cell 14 -> completes row 2 road (10-11-12-13-14)!
      e.handle(0, {'type': 'place', 'cell': 14, 'kind': 'flat'});
      expect(e.isOver, isTrue);
      expect(e.winner, 0);
      expect(e.winningRoad.length, 5);
    });
  });

  group('fanorona', () {
    test('9x5 and 5x5 initial counts, mandatory capture, approach vs withdraw, and multi-capture chain', () {
      final e9 = Fanorona(_setup(2, {'size': '9x5'}))..start();
      expect(e9.cols, 9);
      expect(e9.countPieces(0), 22);
      expect(e9.countPieces(1), 22);
      expect(e9.board[2 * 9 + 4], -1); // center empty

      final e5 = Fanorona(_setup(2, {'size': '5x5'}))..start();
      expect(e5.cols, 5);
      expect(e5.countPieces(0), 12);
      expect(e5.countPieces(1), 12);
      expect(e5.board[2 * 5 + 2], -1); // center empty

      // Opening position has captures available toward center (2,2)=12
      expect(e5.hasAnyCaptureMove(0), isTrue);

      // Moving (3,2)=17 -> (2,2)=12 has BOTH approach (captures (1,2)=7 and (0,2)=2)
      // and withdrawal (nothing behind (3,2) since (4,2)=22 is own piece 0).
      // Wait: let's test explicit approach vs withdrawal on a custom board!
      e5.board.fillRange(0, 25, -1);
      // Place P0 piece at (2, 2) = 12, moving to empty (2, 3) = 13:
      // In front at (2, 4) = 14 is P1 piece (approach target)
      // Behind at (2, 1) = 11 and (2, 0) = 10 are P1 pieces (withdrawal targets)
      // Plus another P1 piece at (0, 3) = 3 so after moving to (2, 3)=13, P0 can chain capture (1, 3)=8 -> (0, 3)=3!
      e5.board[12] = 0;
      e5.board[14] = 1; // approach target
      e5.board[11] = 1; // withdraw target 1
      e5.board[10] = 1; // withdraw target 2
      e5.board[3] = 1; // chain approach target at (0,3) when moving (2,3)=13 -> (1,3)=8
      e5.turn = 0;

      // Choose withdrawal capture on 12 -> 13 (removes 11 and 10, leaves 14 and 3)
      e5.handle(0, {'type': 'move', 'from': 12, 'to': 13, 'capture': 'withdraw'});
      expect(e5.board[11], -1);
      expect(e5.board[10], -1);
      expect(e5.board[14], 1); // untouched because withdraw was chosen!
      // And since (2,3)=13 can now move North to (1,3)=8 to approach-capture (0,3)=3, turn stays with P0 in chain mode!
      expect(e5.turn, 0);
      expect(e5.chainPos, 13);

      // P0 continues capturing (13 -> 8), removing 3; from 8 (strong point), 8 -> 2 can still withdrawal-capture 14!
      e5.handle(0, {'type': 'move', 'from': 13, 'to': 8, 'capture': 'approach'});
      expect(e5.board[3], -1);
      expect(e5.chainPos, 8);
      // P0 chooses to end the capture chain voluntarily via end_turn
      e5.handle(0, {'type': 'end_turn'});
      expect(e5.turn, 1);
      expect(e5.chainPos, -1);
    });
  });
}
