import 'dart:math';

import 'package:aurora_shared/games/abstract7/ataxx.dart';
import 'package:aurora_shared/games/abstract7/defs.dart';
import 'package:aurora_shared/games/abstract7/dvonn.dart';
import 'package:aurora_shared/games/abstract7/tzaar.dart';
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
  test('abstract7: bots finish every variant (count: 30)', () {
    expect(runSims(abstract7Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 10)));

  group('dvonn', () {
    test('49-cell & 37-cell layouts, manual & random setup, 6-side encirclement, height movement, and DVONN lifeline collapse', () {
      final eStd = Dvonn(_setup(2, {'layout': 'standard', 'setup': 'random'}))..start();
      expect(eStd.coords.length, 49);
      expect(eStd.phase, 'stack');
      expect(eStd.hasDvonn.where((x) => x).length, 3);
      expect(eStd.scoreFor(0), 23);
      expect(eStd.scoreFor(1), 23);

      final eManual = Dvonn(_setup(2, {'layout': 'compact', 'setup': 'manual'}))..start();
      expect(eManual.coords.length, 37);
      expect(eManual.phase, 'place');
      for (var i = 0; i < 37; i++) {
        eManual.handle(i % 2, {'type': 'place', 'cell': i});
      }
      expect(eManual.phase, 'stack');
      expect(eManual.scoreFor(0), 17);
      expect(eManual.scoreFor(1), 17);

      // Test encirclement rule at start of full board:
      // Interior piece (0, 0) is surrounded on all 6 hex sides -> NOT mobile!
      final centerIdx = eStd.indexOf(0, 0);
      expect(eStd.occupiedNeighborCount(centerIdx), 6);
      eStd.top[centerIdx] = 0;
      expect(eStd.isMobile(0, centerIdx), isFalse);
      expect(eStd.legalTargets(centerIdx), isEmpty);

      // Perimeter piece (-3, -2) has < 6 neighbors -> mobile!
      final edgeIdx = eStd.indexOf(-3, -2);
      eStd.top[edgeIdx] = 0;
      expect(eStd.isMobile(0, edgeIdx), isTrue);

      // Test exact stack.height movement and DVONN lifeline disconnection collapse:
      eStd.top.fillRange(0, 49, -1);
      eStd.height.fillRange(0, 49, 0);
      eStd.hasDvonn.fillRange(0, 49, false);

      // Suppose a Red DVONN piece is at (-3, 0):
      // Bridge piece (Seat 0, height 2) at (-1, 0), connected to (-3, 0) via (-2, 0),
      // and an isolated island of Seat 1 stack (height 4) at (0, 0) that ONLY connects to the DVONN piece via (-1, 0)!
      final cDvonn = eStd.indexOf(-3, 0);
      final cLink = eStd.indexOf(-2, 0);
      final cBridge = eStd.indexOf(-1, 0);
      final cIsland = eStd.indexOf(0, 0);

      eStd.top[cDvonn] = 2;
      eStd.height[cDvonn] = 1;
      eStd.hasDvonn[cDvonn] = true;

      eStd.top[cLink] = 0;
      eStd.height[cLink] = 1;

      eStd.top[cBridge] = 0;
      eStd.height[cBridge] = 2; // Height 2 -> must move exactly 2 steps!

      eStd.top[cIsland] = 1;
      eStd.height[cIsland] = 4; // Connected to DVONN ONLY through cBridge!

      // Because cBridge has height 2, moving 2 steps left (-1, 0) -> (-3, 0) lands on cDvonn!
      // It CANNOT move 1 step to cLink or cIsland!
      expect(eStd.legalTargets(cBridge), contains(cDvonn));
      expect(eStd.legalTargets(cBridge), isNot(contains(cLink)));
      expect(eStd.legalTargets(cBridge), isNot(contains(cIsland)));

      eStd.turn = 0;
      eStd.handle(0, {'type': 'move', 'from': cBridge, 'to': cDvonn});

      // Now cBridge (-1, 0) is empty -> cIsland (0, 0) is disconnected from all DVONN pieces and collapses!
      expect(eStd.height[cDvonn], 3);
      expect(eStd.top[cDvonn], 0);
      expect(eStd.hasDvonn[cDvonn], isTrue);
      expect(eStd.height[cIsland], 0); // Collapsed!
      expect((eStd.lastAction!['collapsed'] as List), contains(cIsland));
    });
  });

  group('tzaar', () {
    test('60-cell setup, center pit blocking, opening 1-step capture, 2-step capture/strengthen/pass, and 3-type survival win', () {
      final e = Tzaar(_setup(2, {'setup': 'standard'}))..start();
      expect(tzaarCoords.length, 60);
      expect(tzaarIndex(0, 0), -1); // Center pit is not a playable cell
      expect(e.typeCounts(0), [6, 9, 15]);
      expect(e.typeCounts(1), [6, 9, 15]);
      expect(e.isOpeningTurn, isTrue);
      expect(e.turn, 0);
      expect(e.step, 1);

      // Opening turn: Seat 0 makes 1 mandatory capture, then turn immediately passes to Seat 1!
      final firstMove = e.bot(0)!;
      e.handle(0, firstMove);
      expect(e.isOpeningTurn, isFalse);
      expect(e.turn, 1);
      expect(e.step, 1);

      // Seat 1 cannot pass on Step 1 (mandatory capture)
      expect(() => e.handle(1, {'type': 'pass'}), throwsA(isA<GameError>()));

      // Test center pit blocking, Step 1 capture -> Step 2 strengthen -> Pass, and 3-type elimination win:
      e.owner.fillRange(0, 60, -1);
      e.pieceType.fillRange(0, 60, -1);
      e.height.fillRange(0, 60, 0);

      // Verify a piece at (-1, 0) cannot jump across center pit (0, 0) to (1, 0):
      final cLeft = tzaarIndex(-1, 0);
      final cRight = tzaarIndex(1, 0);
      e.owner[cLeft] = 1;
      e.pieceType[cLeft] = 0;
      e.height[cLeft] = 1;
      e.owner[cRight] = 0;
      e.pieceType[cRight] = 0;
      e.height[cRight] = 1;
      expect(e.visibleOccupiedTargets(cLeft), isNot(contains(cRight)));

      // Set up all 3 types for both players so we can test Step 1 capture + Step 2 strengthen:
      final c1A = tzaarIndex(-2, 0);
      final c1B = tzaarIndex(-3, 0);
      final c1C = tzaarIndex(-4, 0);
      final c0Target = tzaarIndex(-2, 1); // Adjacent to c1A (-2, 0)
      final c0Tzaar = tzaarIndex(2, 0); // Only Tzaar (type 0) of Seat 0!
      final c0Tzarra = tzaarIndex(2, 1);
      final c0Tott = tzaarIndex(2, 2);

      // Seat 1 has Tzaar at cLeft (-1,0), Tzarra at c1A (-2,0), Tott at c1B (-3,0), and extra Tott at c1C (-4,0)
      e.owner[c1A] = 1;
      e.pieceType[c1A] = 1;
      e.height[c1A] = 1;
      e.owner[c1B] = 1;
      e.pieceType[c1B] = 2;
      e.height[c1B] = 1;
      e.owner[c1C] = 1;
      e.pieceType[c1C] = 2;
      e.height[c1C] = 1;

      // Remove cRight so c0Tzaar is Seat 0's ONLY Tzaar
      e.owner[cRight] = -1;
      e.pieceType[cRight] = -1;
      e.height[cRight] = 0;

      // Seat 0 has extra Tott at c0Target (-2, 1), plus 1 of each type at (2,0), (2,1), (2,2)
      e.owner[c0Target] = 0;
      e.pieceType[c0Target] = 2;
      e.height[c0Target] = 1;
      e.owner[c0Tzaar] = 0;
      e.pieceType[c0Tzaar] = 0;
      e.height[c0Tzaar] = 1;
      e.owner[c0Tzarra] = 0;
      e.pieceType[c0Tzarra] = 1;
      e.height[c0Tzarra] = 1;
      e.owner[c0Tott] = 0;
      e.pieceType[c0Tott] = 2;
      e.height[c0Tott] = 1;

      // Seat 1 Step 1 (mandatory capture): c1A (-2, 0) captures c0Target (-2, 1)
      e.turn = 1;
      e.step = 1;
      e.handle(1, {'type': 'move', 'from': c1A, 'to': c0Target});
      expect(e.isOver, isFalse);
      expect(e.turn, 1);
      expect(e.step, 2); // Now in Step 2!

      // Seat 1 Step 2 (strengthen): c1B (-3, 0) stacks onto c1C (-4, 0) -> height becomes 2!
      e.handle(1, {'type': 'move', 'from': c1B, 'to': c1C});
      expect(e.height[c1C], 2);
      expect(e.owner[c1C], 1);
      expect(e.turn, 0);
      expect(e.step, 1);

      // Now put a Seat 1 stack adjacent to Seat 0's ONLY Tzaar (c0Tzaar at (2, 0)),
      // let Seat 0 capture a dummy Seat 1 piece and pass Step 2, then Seat 1 captures c0Tzaar to win!
      final c1Dummy = tzaarIndex(1, 2); // Adjacent to c0Tott (2, 2)
      final c1Hunter = tzaarIndex(3, 0); // Adjacent to c0Tzaar (2, 0)
      e.owner[c1Dummy] = 1;
      e.pieceType[c1Dummy] = 2;
      e.height[c1Dummy] = 1;
      e.owner[c1Hunter] = 1;
      e.pieceType[c1Hunter] = 2;
      e.height[c1Hunter] = 2;

      e.handle(0, {'type': 'move', 'from': c0Tott, 'to': c1Dummy});
      expect(e.step, 2);
      e.handle(0, {'type': 'pass'});
      expect(e.turn, 1);
      expect(e.step, 1);

      // Seat 1 captures Seat 0's last Tzaar at c0Tzaar -> Seat 1 wins immediately!
      e.handle(1, {'type': 'move', 'from': c1Hunter, 'to': c0Tzaar});
      expect(e.isOver, isTrue);
      expect(e.winner, 1);
      expect(e.placings, [2, 1]);
    });
  });

  group('ataxx', () {
    test('distance-1 clone, distance-2 jump, 8-neighbor infection, and wipeout win', () {
      final e = Ataxx(_setup(2, {'map': 'cross'}))..start();
      expect(e.board[24], -2); // Center obstacle in cross map
      expect(e.countPieces(0), 2);
      expect(e.countPieces(1), 2);

      // Distance-1 Clone from (0, 0)=0 to (0, 1)=1: keeps 0 AND adds 1!
      e.handle(0, {'type': 'move', 'from': 0, 'to': 1});
      expect(e.board[0], 0);
      expect(e.board[1], 0);
      expect(e.countPieces(0), 3);

      // Distance-2 Jump from (0, 6)=6 to (0, 4)=4: empties 6 AND lands on 4!
      e.handle(1, {'type': 'move', 'from': 6, 'to': 4});
      expect(e.board[6], -1);
      expect(e.board[4], 1);
      expect(e.countPieces(1), 2);

      // Test 8-neighbor infection & wipeout win:
      // Seat 1 has pieces at (0, 4)=4 and (2, 4)=18; remove Seat 1's (6, 0)=42 and put it at (2, 4)=18
      e.board[42] = -1;
      e.board[18] = 1;
      // Seat 0 jumps from (0, 1)=1 to (1, 3)=10, which is adjacent to BOTH (0, 4)=4 and (2, 4)=18!
      e.handle(0, {'type': 'move', 'from': 1, 'to': 10});
      expect(e.board[4], 0); // Infected!
      expect(e.board[18], 0); // Infected!
      expect(e.countPieces(1), 0);
      expect(e.isOver, isTrue);
      expect(e.winner, 0);
      expect(e.placings, [1, 2]);
    });
  });
}
