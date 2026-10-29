import 'dart:math';

import 'package:aurora_shared/games/abstract16/catchup.dart';
import 'package:aurora_shared/games/abstract16/cephalopod.dart';
import 'package:aurora_shared/games/abstract16/defs.dart';
import 'package:aurora_shared/games/abstract16/tumbleweed.dart';
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
  test('abstract16: bots finish every variant (count: 30)', () {
    expect(runSims(abstract16Games, n: 30), 0);
  }, timeout: const Timeout(Duration(minutes: 15)));

  group('tumbleweed', () {
    test('initial setup, line-of-sight blocking, and stack settlement height rule', () {
      final g = TumbleweedGame(_setup(2, {'mode': 'quick'}))..start();
      expect(g.totalHexes, 37);
      // Center (0, 0) is Neutral (-1) height 2
      expect(g.getOwner(0, 0), -1);
      expect(g.getHeight(0, 0), 2);
      // (-1, 0) is Player 0 height 1
      expect(g.getOwner(-1, 0), 0);
      expect(g.getHeight(-1, 0), 1);
      // (1, 0) is Player 1 height 1
      expect(g.getOwner(1, 0), 1);
      expect(g.getHeight(1, 0), 1);

      // Player 0 cannot settle at (0, 0) initially because losCount(0, 0, 0) == 1 <= height(0, 0) == 2
      expect(g.losCount(0, 0, 0), 1);
      expect(
        () => g.handle(0, {'type': 'settle', 'q': 0, 'r': 0}),
        throwsA(isA<GameError>()),
      );

      // Also Player 0 cannot settle at (2, 0) because the ray toward (-1, 0) is blocked by (1, 0) and (0, 0)!
      expect(g.losCount(0, 2, 0), 0);
      expect(
        () => g.handle(0, {'type': 'settle', 'q': 2, 'r': 0}),
        throwsA(isA<GameError>()),
      );

      // Player 0 settles at (-1, 1) which sees (-1, 0) along direction (0, -1) -> losCount == 1
      expect(g.losCount(0, -1, 1), 1);
      g.handle(0, {'type': 'settle', 'q': -1, 'r': 1});
      expect(g.getOwner(-1, 1), 0);
      expect(g.getHeight(-1, 1), 1);

      // Player 1 settles at (1, -1) which sees (1, 0) along direction (0, 1) -> losCount == 1
      g.handle(1, {'type': 'settle', 'q': 1, 'r': -1});
      expect(g.getOwner(1, -1), 1);
      expect(g.getHeight(1, -1), 1);

      // Now from (0, 1), Player 0 sees BOTH (-1, 1) along (-1, 0) AND (-1, 0) along (-1, -1)?
      // Wait: hex directions are (1,0), (-1,0), (0,1), (0,-1), (1,-1), (-1,1).
      // From (-2, 1), rays go:
      //  + (1, 0) -> (-1, 1) (P0!)
      //  + (1, -1) -> (-1, 0) (P0!)
      // So (-2, 1) sees TWO Player 0 stacks!
      expect(g.losCount(0, -2, 1), 2);
      g.handle(0, {'type': 'settle', 'q': -2, 'r': 1});
      expect(g.getOwner(-2, 1), 0);
      expect(g.getHeight(-2, 1), 2);
    });

    test('overwriting neutral stack and consecutive pass territory scoring', () {
      final g = TumbleweedGame(_setup(2, {'mode': 'quick'}))..start();
      // Give Player 0 three stacks surrounding (0, 0): (-1, 0), (0, -1), (-1, 1)
      g.setStack(-1, 0, 0, 1);
      g.setStack(0, -1, 0, 1);
      g.setStack(-1, 1, 0, 1);

      // Now (0, 0) has height 2 (Neutral), and Player 0 has losCount(0, 0, 0) == 3 > 2!
      expect(g.losCount(0, 0, 0), 3);
      g.handle(0, {'type': 'settle', 'q': 0, 'r': 0});
      expect(g.getOwner(0, 0), 0);
      expect(g.getHeight(0, 0), 3);

      // Both players pass consecutively -> game ends and scores territory
      g.handle(1, {'type': 'pass'});
      expect(g.isOver, isFalse);
      g.handle(0, {'type': 'pass'});
      expect(g.isOver, isTrue);
      expect(g.winner, 0);
      expect(g.placings, [1, 2]);
    });
  });

  group('catchup', () {
    test('turn 1 single stone, subsequent 2-stone default, and 3-stone catchup trigger', () {
      final c = CatchupGame(_setup(2, {'mode': 'quick'}))..start();
      expect(c.quota, 1);
      expect(c.turn, 0);

      // Turn 1: Player 0 places 1 stone at (0, 0) -> turn automatically ends
      c.handle(0, {'type': 'place', 'q': 0, 'r': 0});
      expect(c.turn, 1);
      expect(c.quota, 2); // Turn 2 defaults to 2 stones

      // Turn 2: Player 1 places 2 connected stones at (2, 0) and (2, -1)
      // At start of Turn 2: P1 startMax == 0, P0 oppMax == 1.
      // At end of Turn 2: P1 endMax == 2 >= oppMax (1) and endMax > startMax (0) -> triggers quota = 3 for P0!
      c.handle(1, {'type': 'place', 'q': 2, 'r': 0});
      expect(c.turn, 1);
      expect(c.placedThisTurn, 1);
      c.handle(1, {'type': 'place', 'q': 2, 'r': -1});
      expect(c.turn, 0);
      expect(c.catchupTriggered, isTrue);
      expect(c.quota, 3);

      // Turn 3: Player 0 has quota == 3, places 2 stones in a separate group that stays size 1 (< P1's max 2),
      // so P0's maxGroupSize remains 1 (not > startMax 1). Let's place 3 isolated stones:
      c.handle(0, {'type': 'place', 'q': -2, 'r': 0});
      c.handle(0, {'type': 'place', 'q': 0, 'r': 2});
      c.handle(0, {'type': 'place', 'q': 0, 'r': -2});
      // P0 startMax was 1, endMax is still 1 -> does NOT trigger catchup for P1!
      expect(c.turn, 1);
      expect(c.catchupTriggered, isFalse);
      expect(c.quota, 2);
    });

    test('endgame lexicographical group size comparison', () {
      final c = CatchupGame(_setup(2, {'mode': 'quick'}))..start();
      // Fill all but 1 hex: give P0 and P1 tied largest group (size 18 vs 18), and P0 gets an extra group of size 1
      final hexes = List.of(c.allHexes);
      for (var i = 0; i < hexes.length - 1; i++) {
        final (q, r) = hexes[i];
        c.setStone(q, r, i.isEven ? 0 : 1);
      }
      final last = hexes.last;
      c.handle(0, {'type': 'place', 'q': last.$1, 'r': last.$2});
      expect(c.isOver, isTrue);
      expect(c.winner, isNotNull);
      expect(c.placings, isNotNull);
    });
  });

  group('cephalopod', () {
    test('non-capture places 1-pip and mandatory capture sums orthogonal neighbors <= 6', () {
      final g = CephalopodGame(_setup(2, {'mode': 'quick'}))..start();
      expect(g.boardSize, 3);

      // P0 places at (0, 1) -> no neighbors, places 1-pip
      g.handle(0, {'type': 'place', 'r': 0, 'c': 1, 'capture': []});
      expect(g.owner[0][1], 0);
      expect(g.pips[0][1], 1);

      // P1 places at (1, 0) -> no orthogonal neighbors to (1, 0), places 1-pip
      g.handle(1, {'type': 'place', 'r': 1, 'c': 0, 'capture': []});
      expect(g.owner[1][0], 1);
      expect(g.pips[1][0], 1);

      // Now cell (0, 0) is orthogonally adjacent to BOTH (0, 1) [1 pip] and (1, 0) [1 pip].
      // Since 1 + 1 = 2 <= 6, placing at (0, 0) MUST capture them!
      expect(
        () => g.handle(0, {'type': 'place', 'r': 0, 'c': 0, 'capture': []}),
        throwsA(isA<GameError>()),
      );

      // Capturing both (0, 1) and (1, 0) removes them and places a 2-pip die for P0 at (0, 0)!
      g.handle(0, {
        'type': 'place',
        'r': 0,
        'c': 0,
        'capture': [
          [0, 1],
          [1, 0],
        ],
      });
      expect(g.pips[0][1], 0);
      expect(g.pips[1][0], 0);
      expect(g.owner[0][0], 0);
      expect(g.pips[0][0], 2);
    });

    test('6-pip dice cannot be captured when neighbor sums exceed 6, and majority 6-pips wins', () {
      final g = CephalopodGame(_setup(2, {'mode': 'quick'}))..start();
      // Place two 6-pip dice at (0, 1) and (1, 0): sum is 12 > 6, so (0, 0) cannot capture them
      g.setDie(0, 1, 0, 6);
      g.setDie(1, 0, 1, 6);
      expect(g.validCaptureSubsets(0, 0), isEmpty);

      // Cannot pass capture when sum > 6
      expect(
        () => g.handle(0, {
          'type': 'place',
          'r': 0,
          'c': 0,
          'capture': [
            [0, 1],
            [1, 0],
          ],
        }),
        throwsA(isA<GameError>()),
      );

      // Non-capture placement at (0, 0) places a 1-pip die
      g.handle(0, {'type': 'place', 'r': 0, 'c': 0, 'capture': []});
      expect(g.pips[0][0], 1);

      // Give Player 1 four 6-pip dice on 3x3 board, and set up a capture into a 5th 6-pip die
      g.setDie(1, 0, 1, 6);
      g.setDie(2, 0, 1, 6);
      g.setDie(2, 1, 1, 6);
      g.setDie(2, 2, 1, 6);
      // Put 3-pip at (0, 2) and 3-pip at (1, 1) so P1 can capture them at (1, 2) for a 6-pip die!
      g.setDie(0, 2, 0, 3);
      g.setDie(1, 1, 0, 3);

      g.handle(1, {
        'type': 'place',
        'r': 1,
        'c': 2,
        'capture': [
          [0, 2],
          [1, 1],
        ],
      });
      expect(g.pips[1][2], 6);
      expect(g.sixPipCount(1), 5);
      expect(g.isOver, isTrue);
      expect(g.winner, 1);
      expect(g.placings, [2, 1]);
    });
  });
}
